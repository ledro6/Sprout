import Foundation

/// Напоминание о поливе: кого и когда будить. Одна арифметика, без
/// `UserNotifications`, — чтобы проверять её где угодно.
enum Reminder {
    struct Due {
        var plant: Plant
        var others: Int
        var after: TimeInterval
        /// Кого польёт кнопка «Полил» в уведомлении: всех, кому к этому
        /// мигу станет сухо.
        var ids: [Plant.ID] = []
    }

    /// Подкормка или пересадка — отдельным уведомлением: у полива своя
    /// кнопка, а у ухода её нет.
    struct Chore {
        var plant: Plant
        var repot: Bool
        var after: TimeInterval
    }

    /// Раньше уведомление бессмысленно: сухие растения набираются за минуты,
    /// и оно прилетало бы, пока экран ещё не погас.
    static let soonest: TimeInterval = 15

    /// Через сколько настоящих секунд растение опустится до порога; пусто —
    /// никогда.
    ///
    /// Через `Garden.speed`, а не настоящие сутки: иначе на карточке растение
    /// сухое, а напоминание — через неделю.
    static func delay(for plant: Plant, threshold: Double) -> TimeInterval? {
        guard plant.dryingDays > 0 else { return nil }
        guard plant.moisture > threshold else { return 0 }
        let days = (plant.moisture - threshold) * plant.period
        return days * 86_400 / Garden.speed
    }

    /// Одно на всю квартиру, а не по штуке на растение, — но с числом
    /// соседей, которым станет сухо к тому же мигу.
    static func next(in rooms: [Room], threshold: Double) -> Due? {
        let plants = rooms.flatMap(\.plants)
        var soonest: (plant: Plant, delay: TimeInterval)?
        for plant in plants {
            guard let delay = delay(for: plant, threshold: threshold) else {
                continue
            }
            if soonest == nil || delay < soonest!.delay {
                soonest = (plant, delay)
            }
        }
        guard let soonest else { return nil }
        let together = plants.filter {
            guard let delay = delay(for: $0, threshold: threshold) else {
                return false
            }
            return delay <= soonest.delay
        }
        return Due(plant: soonest.plant, others: together.count - 1,
                   after: max(soonest.delay, Self.soonest),
                   ids: together.map(\.id))
    }

    static var title: String { Lang.text("Пора поливать") }

    static func text(for due: Due) -> String {
        guard due.others > 0 else {
            return Lang.format("«%@» просит воды", due.plant.name)
        }
        return Lang.format("«%1$@» и ещё %2$@ просят воды", due.plant.name,
                           Lang.format("%lld растений", due.others))
    }

    /// Ближайший уход по всей квартире. Подкормка — только в пору роста:
    /// зимой её счёт стоит.
    static func chore(in rooms: [Room]) -> Chore? {
        var best: (plant: Plant, repot: Bool, days: Double)?
        for plant in rooms.flatMap(\.plants) {
            let tending = plant.tending
            var options: [(Bool, Double)] = []
            if Season.growing, let left = tending.feedIn {
                options.append((false, left))
            }
            if let left = tending.repotIn { options.append((true, left)) }
            for (repot, days) in options where best == nil || days < best!.days {
                best = (plant, repot, days)
            }
        }
        guard let best else { return nil }
        return Chore(plant: best.plant, repot: best.repot,
                     after: max(best.days * 86_400 / Garden.speed, soonest))
    }

    static func title(for chore: Chore) -> String {
        chore.repot ? Lang.text("Пора пересадить") : Lang.text("Пора подкормить")
    }

    static func text(for chore: Chore) -> String {
        chore.repot
            ? Lang.format("«%@» просится в горшок побольше", chore.plant.name)
            : Lang.format("«%@» ждёт подкормки", chore.plant.name)
    }
}
