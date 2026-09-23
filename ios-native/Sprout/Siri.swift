import AppIntents
import SwiftUI
import UIKit

/// Команды Siri и «Команд»: полить растение и узнать, кого полить сегодня.
///
/// Живут в самом приложении, а не в отдельном расширении: им нужен сад, а
/// сад лежит здесь. Приложение закрыто — система поднимает его в фоне, без
/// окна, и команда говорит с тем же общим садом (`Garden.shared`), что и
/// экраны. Открыто — полив из Siri виден на карточке сразу.
///
/// Фразы русские: язык разработки приложения — русский, и Siri на русском
/// ищет команды по ним. В каждой есть имя приложения — без него система
/// фразу не примет: так Siri отличает команду Sprout от чужой.

/// Растение — таким, каким его знает Siri: кличка и комната.
struct PlantEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Растение"
    static let defaultQuery = PlantQuery()

    let id: String
    let name: String
    let room: String

    var displayRepresentation: DisplayRepresentation {
        // Комната подписью: двух Баксиков Siri различит только по ней.
        DisplayRepresentation(title: "\(name)", subtitle: "\(room)")
    }

    init(_ plant: Plant, room: String) {
        id = plant.id
        name = plant.name
        self.room = room
    }
}

/// Где Siri ищет растения.
///
/// Каждый ответ читает сад на главной очереди: сад — наблюдаемый класс
/// интерфейса, и трогать его из чужой очереди нельзя. Наружу уходят
/// готовые слепки — клички и комнаты, — а не сами растения.
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

    /// По сказанному — с поправкой на падеж: «Полей Баксика». См.
    /// `Seed.spoken`.
    func entities(matching string: String) async throws -> [PlantEntity] {
        await MainActor.run {
            let garden = Garden.shared
            return Seed.spoken(string, in: garden.rooms).map {
                PlantEntity($0, room: garden.roomName(of: $0.id) ?? "")
            }
        }
    }

    /// Все растения сада — из них Siri и берёт клички для фраз.
    func suggestedEntities() async throws -> [PlantEntity] {
        await MainActor.run {
            Garden.shared.rooms.flatMap { room in
                room.plants.map { PlantEntity($0, room: room.name) }
            }
        }
    }
}

/// «Полей Баксика».
struct WaterPlant: AppIntent {
    static let title: LocalizedStringResource = "Полить растение"
    // Одной строкой, а не сложением: описание — ресурс для перевода, и
    // собранную из кусков строку система за ресурс не примет.
    static let description: IntentDescription? = IntentDescription(
        "Отмечает полив: влажность встаёт на сто процентов, а полив попадает в журнал.")

    @Parameter(title: "Растение",
               requestValueDialog: "Какое растение полить?")
    var plant: PlantEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let garden = Garden.shared
        // Сперва отдаём саду прошедшее время: приложение могло стоять в
        // фоне, и без этого полив лёг бы на устаревшую влажность.
        garden.advance()
        guard garden.plant(id: plant.id) != nil else {
            return .result(dialog: "Растения «\(plant.name)» в саду больше нет.")
        }
        withAnimation(Motion.appear) { garden.water(plant.id) }
        // Приложение на экране — полив виден и там: по узору от карточки
        // идёт та же волна, что и от нажатия.
        if UIApplication.shared.applicationState == .active {
            let spot = Cards.shared.rect(plant.id)
            Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
        }
        return .result(dialog: "Полито: \(plant.name). Влажность — сто процентов.")
    }
}

/// «Кого полить сегодня?»
struct WhoNeedsWater: AppIntent {
    static let title: LocalizedStringResource = "Кого полить сегодня"
    static let description: IntentDescription? = IntentDescription(
        "Называет растения, у которых срок полива — сегодня, от самого сухого.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let garden = Garden.shared
        garden.advance()
        let line = Seed.dueLine(Seed.due(in: garden.rooms))
        return .result(dialog: "\(line)")
    }
}

/// Фразы, по которым Siri узнаёт команды без всякой настройки.
///
/// Кличка после слова «растение» остаётся в именительном падеже —
/// «Полей растение Баксик», — и её Siri узнаёт наверняка. Без него кличку
/// говорят в винительном — «Полей Баксика», — и тогда её ищет
/// `PlantQuery` с поправкой на окончание. А сказанное совсем без клички —
/// «Полить растение в Sprout» — Siri переспросит: «Какое растение
/// полить?».
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
    }
}
