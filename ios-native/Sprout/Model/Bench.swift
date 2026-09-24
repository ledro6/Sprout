import Foundation
import Observation

/// Готовность моделей для дополненной реальности — по растениям. Пишет
/// мастерская, читают экраны: карточка показывает проценты, а входы в AR
/// ждут готовой модели.
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

    /// Готовые модели: растение → отпечаток чертежа. Меняется, только когда
    /// модель собралась или её заказали заново, — большие экраны смотрят
    /// сюда и не перерисовываются на каждый процент.
    private(set) var finished: [Plant.ID: String] = [:]

    /// Отпечаток чертежа считается кодированием — помним готовые: экраны
    /// спрашивают каждую секунду.
    @ObservationIgnored private var stamps: [Blueprint: String] = [:]

    init() {}

    /// Доля готовности модели, 0…1. Нет — мастерская ещё не смотрела это
    /// растение или его чертёж сменился, а новую модель ещё не заказали.
    func share(_ plant: Plant) -> Double? {
        guard let mark = marks[plant.id], mark.stamp == stamp(plant.blueprint)
        else { return nil }
        return mark.share
    }

    func ready(_ plant: Plant) -> Bool {
        finished[plant.id] == stamp(plant.blueprint)
    }

    /// Сад — когда готовы все его модели.
    func ready(_ plants: [Plant]) -> Bool {
        !plants.isEmpty && plants.allSatisfy { ready($0) }
    }

    /// Готовность сада — средняя по растениям; о ком не знаем — нулём.
    func share(_ plants: [Plant]) -> Double {
        guard !plants.isEmpty else { return 0 }
        return plants.reduce(0) { $0 + (share($1) ?? 0) } / Double(plants.count)
    }

    /// Отчёт мастерской. По тому же чертежу доля не убывает: отчёты идут с
    /// другой очереди, и старый мог прийти позже нового.
    func note(_ id: Plant.ID, stamp: String, share: Double) {
        let share = min(max(share, 0), 1)
        if let old = marks[id], old.stamp == stamp, old.share >= share {
            return
        }
        marks[id] = Mark(stamp: stamp, share: share)
        // Готовые — только при смене: запись без смены всё равно будит
        // всех, кто на них смотрит.
        let done = share == 1 ? stamp : nil
        if finished[id] != done { finished[id] = done }
    }

    /// Модель заказали с экрана — карточка сразу показывает ноль, не
    /// дожидаясь очереди мастерской. Готовую по тому же чертежу не трогает.
    func queue(_ plant: Plant) {
        note(plant.id, stamp: stamp(plant.blueprint), share: 0)
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
