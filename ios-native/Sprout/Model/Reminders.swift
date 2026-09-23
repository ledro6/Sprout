import Foundation

/// Напоминание о поливе: кого и когда будить. Одна арифметика, без
/// `UserNotifications`, — чтобы проверять её где угодно.
enum Reminder {
    struct Due {
        var plant: Plant
        var others: Int
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
        let days = (plant.moisture - threshold) * plant.dryingDays
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
                   after: max(soonest.delay, Self.soonest))
    }

    static let title = "Пора поливать"

    static func text(for due: Due) -> String {
        guard due.others > 0 else { return "«\(due.plant.name)» просит воды" }
        let word = Plant.plural(due.others, "растение", "растения", "растений")
        return "«\(due.plant.name)» и ещё \(due.others) \(word) просят воды"
    }
}
