import UIKit

/// Быстрые действия иконки на экране «Домой»: «Полить всех (n)», «Добавить
/// растение», «Уезжаю». Список динамический и обновляется, когда приложение
/// уходит в фон, — число в «Полить всех» берётся из сада на этот миг.
/// Нажатие приходит сцене (`FamilyScene`) и идёт тем же путём, что просьбы
/// Siri и Spotlight, — через `Summon`, который слушает `RootView`.
@MainActor
enum QuickActions {
    static let waterAll = "sprout.waterAll"
    static let add = "sprout.add"
    static let trip = "sprout.trip"

    /// Нажали при запуске с нуля или под замком: корень ещё не слушает —
    /// исполнит `run`, когда сможет.
    nonisolated(unsafe) static var pending: String?

    /// Зовётся при уходе в фон. «Полить всех» — только когда есть кому
    /// (`Garden.waterNeeded` поливает тех же).
    static func refresh(_ rooms: [Room]) {
        let thirsty = MoistureStatus.bulk(rooms.flatMap(\.plants)).count
        var items: [UIApplicationShortcutItem] = []
        if thirsty > 0 {
            items.append(item(waterAll,
                              Lang.format("Полить всех (%lld)", thirsty),
                              "drop.fill"))
        }
        items.append(item(add, Lang.text("Добавить растение"), "plus"))
        items.append(item(trip, Lang.text("Уезжаю"), "suitcase"))
        UIApplication.shared.shortcutItems = items
    }

    private static func item(_ type: String, _ title: String,
                             _ symbol: String) -> UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: type, localizedTitle: title, localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: symbol),
            userInfo: nil)
    }

    /// Исполняет ожидающее действие. Под замком ждёт: сад запертый не
    /// поливают.
    static func run() {
        guard let type = pending else { return }
        if Lock.shared.on && !Lock.shared.open { return }
        pending = nil
        switch type {
        case waterAll:
            let garden = Garden.shared
            // Пока спали, сад могли полить виджет или уведомление.
            garden.reload()
            garden.advance()
            if !garden.waterNeeded().isEmpty { Feel.water() }
            Summon.shared.home = true
        case add:
            Summon.shared.add = true
        case trip:
            Summon.shared.trip = true
        default:
            break
        }
    }
}
