import Foundation
import Observation

/// Как идёт сборка своих моделей — по растениям. Пишет мастерская, читают
/// экраны: пока модель по снимку собирается, карточка показывает проценты.
/// AR их не ждёт: без своей модели он ставит готовую модель вида.
@MainActor
@Observable
final class Bench {
    static let shared = Bench()

    /// Модель по чертежу с отпечатком `stamp` готова на `share`, 0…1.
    struct Mark: Equatable, Sendable {
        var stamp: String
        var share: Double
    }

    /// Доли — меняются на каждый процент. Их читают только маленькие вью:
    /// значок, пункт меню, отметка на кнопке.
    private(set) var marks: [Plant.ID: Mark] = [:]

    /// Отпечаток чертежа считается кодированием — помним готовые: экраны
    /// спрашивают каждую секунду.
    @ObservationIgnored private var stamps: [Blueprint: String] = [:]

    init() {}

    /// Доля готовности своей модели, 0…1. Нет — своей модели нет, её
    /// чертёж сменился или мастерская до неё ещё не дошла.
    func share(_ plant: Plant) -> Double? {
        guard let plan = plant.plan, let mark = marks[plant.id],
              mark.stamp == stamp(plan)
        else { return nil }
        return mark.share
    }

    /// Своя модель собрана — AR покажет её, а не модель вида.
    func built(_ plant: Plant) -> Bool { share(plant) == 1 }

    /// Отчёт мастерской. По тому же чертежу доля не убывает: отчёты идут с
    /// другой очереди, и старый мог прийти позже нового.
    func note(_ id: Plant.ID, stamp: String, share: Double) {
        let share = min(max(share, 0), 1)
        if let old = marks[id], old.stamp == stamp, old.share >= share {
            return
        }
        marks[id] = Mark(stamp: stamp, share: share)
    }

    /// Модель заказали с экрана — карточка сразу показывает ноль, не
    /// дожидаясь очереди мастерской. Собранную по тому же чертежу не
    /// трогает.
    func queue(_ plant: Plant) {
        guard let plan = plant.plan else { return }
        note(plant.id, stamp: stamp(plan), share: 0)
    }

    /// «42%» — долей по-местному: у кого знак впереди, у кого через пробел.
    nonisolated static func percent(_ share: Double) -> String {
        Lang.format("%lld%%", Int((min(max(share, 0), 1) * 100).rounded(.down)))
    }

    /// «Модель готовится: 42%»; пока мастерская не дошла — без процентов.
    nonisolated static func preparing(_ share: Double?) -> String {
        guard let share else { return Lang.text("Модель готовится") }
        return Lang.format("Модель готовится: %@", percent(share))
    }

    private func stamp(_ blueprint: Blueprint) -> String {
        if let known = stamps[blueprint] { return known }
        let made = blueprint.fingerprint
        stamps[blueprint] = made
        return made
    }
}
