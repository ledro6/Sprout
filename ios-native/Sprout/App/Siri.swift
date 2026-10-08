import AppIntents
import SwiftUI
import UIKit

// Команды Siri: полить растение и узнать, кого полить сегодня.
//
// Живут в самом приложении, без расширения: закрытое приложение система
// поднимает в фоне, и команда говорит с тем же `Garden.shared`, что и
// экраны. В каждой фразе обязательно имя приложения.

/// Растение для Siri и визуального интеллекта: кличка, комната, влажность
/// и картинка.
struct PlantEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Растение"
    static let defaultQuery = PlantQuery()

    let id: String
    let name: String
    let room: String
    /// Подпись: комната, влажность и «Пора поливать», если пора.
    let status: String
    /// Миниатюра из общей папки — та же, что у виджета.
    let thumb: URL?

    var displayRepresentation: DisplayRepresentation {
        // Комната — первой в подписи: двух Баксиков Siri различит только
        // по ней.
        DisplayRepresentation(title: "\(name)", subtitle: "\(status)",
                              image: picture)
    }

    /// Без общей папки миниатюр нет — тогда листок.
    private var picture: DisplayRepresentation.Image {
        if let thumb, FileManager.default.fileExists(atPath: thumb.path) {
            return .init(url: thumb)
        }
        return .init(systemName: "leaf.fill")
    }

    init(_ plant: Plant, room: String) {
        id = plant.id
        name = plant.name
        self.room = room
        let percent = plant.moistureLabel
        let line = Lang.format("%1$@ · %2$@", room, percent)
        status = plant.needsWaterToday
            ? Lang.format("%1$@ · %2$@", line, Lang.text("Пора поливать"))
            : line
        thumb = Store.thumb(for: plant)
    }
}

/// Сад читается на главной очереди, наружу уходят слепки.
struct PlantQuery: EntityStringQuery {
    func entities(for identifiers: [PlantEntity.ID]) async throws
        -> [PlantEntity] {
        await MainActor.run {
            let garden = Garden.shared
            return identifiers.compactMap { id in
                guard let plant = garden.plant(id: id) else { return nil }
                return PlantEntity(plant, room: garden.roomName(of: id) ?? "")
            }
        }
    }

    /// С поправкой на падеж — см. `Seed.spoken`.
    func entities(matching string: String) async throws -> [PlantEntity] {
        await MainActor.run {
            let garden = Garden.shared
            return Seed.spoken(string, in: garden.rooms).map {
                PlantEntity($0, room: garden.roomName(of: $0.id) ?? "")
            }
        }
    }

    func suggestedEntities() async throws -> [PlantEntity] {
        await MainActor.run {
            Garden.shared.rooms.flatMap { room in
                room.plants.map { PlantEntity($0, room: room.name) }
            }
        }
    }
}

struct WaterPlant: AppIntent {
    static let title: LocalizedStringResource = "Полить растение"
    // Одной строкой: собранную сложением строку система за ресурс не примет.
    static let description: IntentDescription? = IntentDescription(
        "Отмечает полив: влажность встаёт на сто процентов, а полив попадает в журнал.")

    @Parameter(title: "Растение",
               requestValueDialog: "Какое растение полить?")
    var plant: PlantEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let garden = Garden.shared
        // Приложение могло стоять в фоне — сперва чужие правки (виджет),
        // потом прошедшее время.
        garden.reload()
        garden.advance()
        guard garden.plant(id: plant.id) != nil else {
            return .result(dialog: "\(Lang.format("Растения «%@» в саду больше нет.", plant.name))")
        }
        // Влажную землю голосом не поливаем: подтвердить нечем, а лишний
        // полив вреден. Пусть хозяин посмотрит сам.
        if let wet = garden.wetCheck(plant.id) {
            let level = MoistureStatus.percent(
                wet, estimated: garden.plant(id: plant.id)?.estimated ?? true)
            return .result(dialog: "\(Lang.format("Земля у «%1$@» ещё влажная (%2$@) — полив не записан. Лишний полив вреден корням.", plant.name, level))")
        }
        withAnimation(Motion.appear) { _ = garden.water(plant.id) }
        if UIApplication.shared.applicationState == .active {
            let spot = Cards.shared.rect(plant.id)
            Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
        }
        return .result(dialog: "\(Lang.format("Полито: %@. Влажность — сто процентов.", plant.name))")
    }
}

struct WhoNeedsWater: AppIntent {
    static let title: LocalizedStringResource = "Кого полить сегодня"
    static let description: IntentDescription? = IntentDescription(
        "Называет растения, у которых срок полива — сегодня, от самого сухого.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let garden = Garden.shared
        garden.reload()
        garden.advance()
        let line = Seed.dueLine(MoistureStatus.needsWater(in: garden.rooms))
        return .result(dialog: "\(line)")
    }
}

/// Сад в AR одним нажатием — для кнопки действия на корпусе iPhone 15 Pro и
/// новее, «Пункта управления» и Siri. Приложение открывается, главная
/// разворачивает сад текущей комнаты.
struct OpenGardenAR: AppIntent {
    static let title: LocalizedStringResource = "Сад в AR"
    static let description: IntentDescription? = IntentDescription(
        "Открывает растения комнаты в дополненной реальности.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Summon.shared.garden = true
        return .result()
    }
}

/// Просьбы извне, которые исполняет экран: команда не держит окон.
@MainActor
@Observable
final class Summon {
    static let shared = Summon()

    var garden = false
    /// Открыть растение — из визуального интеллекта или Spotlight.
    var plant: Plant.ID?
    /// На вкладку «Добавить» — из пустого сада и быстрого действия иконки.
    var add = false
    /// «Уезжаю» — из быстрого действия иконки.
    var trip = false
    /// На главную — после «Полить всех» из быстрого действия.
    var home = false
}

/// После слова «растение» кличка остаётся в именительном — «Полей растение
/// Баксик». Без него она в винительном, и её ищет `PlantQuery`. Без клички
/// Siri переспросит.
struct SproutShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WaterPlant(),
            phrases: [
                "Полей растение \(\.$plant) в \(.applicationName)",
                "Полить растение \(\.$plant) в \(.applicationName)",
                "Полей \(\.$plant) в \(.applicationName)",
                "Полить \(\.$plant) в \(.applicationName)",
                "Полить растение в \(.applicationName)",
            ],
            shortTitle: "Полить",
            systemImageName: "drop.fill")
        AppShortcut(
            intent: WhoNeedsWater(),
            phrases: [
                "Кого полить в \(.applicationName)",
                "Кого полить сегодня в \(.applicationName)",
                "Кому нужна вода в \(.applicationName)",
                "Кто хочет пить в \(.applicationName)",
            ],
            shortTitle: "Кого полить",
            systemImageName: "leaf")
        AppShortcut(
            intent: OpenGardenAR(),
            phrases: [
                "Сад в AR в \(.applicationName)",
                "Покажи сад в \(.applicationName)",
                "Открой сад в \(.applicationName)",
            ],
            shortTitle: "Сад в AR",
            systemImageName: "arkit")
    }
}
