import Foundation

/// Напоминание о поливе: кого и когда пора будить.
///
/// Расчёт отделён от самих уведомлений нарочно. Здесь одна арифметика —
/// у растения известна влажность и скорость сушки, значит известен и миг,
/// когда оно опустится до порога, — а `UserNotifications` есть только на
/// телефоне. Так срок можно проверить где угодно, где есть Swift, тем же
/// прогоном, что и остальную модель.
enum Reminder {
    /// Кого будить, сколько их и через сколько.
    struct Due {
        /// Первое растение, которому станет сухо.
        var plant: Plant
        /// Сколько ещё будет сухих к тому же мигу.
        var others: Int
        /// Через сколько настоящих секунд от «сейчас».
        var after: TimeInterval
    }

    /// Не раньше чем через столько уведомление не имеет смысла: телефон
    /// ещё в руке, а приложение только что закрыли.
    ///
    /// Пятнадцать секунд — не круглое число ради круглого. Час сада здесь
    /// проходит за секунду, и сухие растения набираются за минуты; будь
    /// задержка меньше, уведомление успевало бы прилететь раньше, чем
    /// погаснет экран.
    static let soonest: TimeInterval = 15

    /// Через сколько настоящих секунд растение опустится до порога.
    ///
    /// Ноль — уже опустилось. Пусто — не опустится никогда: у растения не
    /// задана сушка, и влажность у него стоит на месте.
    ///
    /// Пересчёт через `Garden.speed`, а не по настоящим суткам, и это
    /// главное здесь решение. В приложении час сада проходит за секунду —
    /// на этом держатся и подсыхающие проценты, и желтеющая тень. Считай
    /// уведомление по настоящим суткам, оно разошлось бы с тем, что
    /// написано на карточке: на экране растение сухое, а напоминание — на
    /// следующей неделе. Время у сада одно, и уведомление живёт по нему.
    static func delay(for plant: Plant, threshold: Double) -> TimeInterval? {
        guard plant.dryingDays > 0 else { return nil }
        guard plant.moisture > threshold else { return 0 }
        let days = (plant.moisture - threshold) * plant.dryingDays
        return days * 86_400 / Garden.speed
    }

    /// Ближайшее напоминание по всей квартире.
    ///
    /// Одно, а не по штуке на растение. Сухими они становятся друг за
    /// другом, и два десятка уведомлений подряд — это не забота, а
    /// назойливость. Разбудить должно первое; открыв приложение, хозяин
    /// увидит весь сад разом, а расписание составится заново.
    ///
    /// Соседи считаются: если к тому же мигу сухих будет несколько, об
    /// этом стоит сказать в одной строке, а не молчать про остальных.
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
        // Сухие к тому же мигу — те, чей срок не позже найденного.
        let together = plants.filter {
            guard let delay = delay(for: $0, threshold: threshold) else {
                return false
            }
            return delay <= soonest.delay
        }
        return Due(plant: soonest.plant, others: together.count - 1,
                   after: max(soonest.delay, Self.soonest))
    }

    /// Заголовок уведомления.
    static let title = "Пора поливать"

    /// Строка уведомления: кто просит воды и сколько их ещё.
    static func text(for due: Due) -> String {
        guard due.others > 0 else { return "«\(due.plant.name)» просит воды" }
        let word = Plant.plural(due.others, "растение", "растения", "растений")
        return "«\(due.plant.name)» и ещё \(due.others) \(word) просят воды"
    }
}
