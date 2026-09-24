import AppIntents
import SwiftUI
import UIKit

// Команды Siri: полить растение и узнать, кого полить сегодня.
//
// Живут в самом приложении, без расширения: закрытое приложение система
// поднимает в фоне, и команда говорит с тем же `Garden.shared`, что и
// экраны. В каждой фразе обязательно имя приложения.

/// Растение для Siri: кличка и комната.
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
            return .result(dialog: "Растения «\(plant.name)» в саду больше нет.")
        }
        withAnimation(Motion.appear) { _ = garden.water(plant.id) }
        if UIApplication.shared.applicationState == .active {
            let spot = Cards.shared.rect(plant.id)
            Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
        }
        return .result(dialog: "Полито: \(plant.name). Влажность — сто процентов.")
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
        let line = Seed.dueLine(Seed.due(in: garden.rooms))
        return .result(dialog: "\(line)")
    }
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
    }
}
