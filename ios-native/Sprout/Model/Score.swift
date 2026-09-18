import Foundation

/// Одна запись журнала: кого полили и когда.
///
/// Время настоящее, а не садовое. Час сада проходит здесь за секунду — по
/// садовым часам «сегодня» кончалось бы каждые двадцать четыре секунды, и
/// «сколько полил за неделю» не значило бы ничего. Хозяин спрашивает про
/// свои дни, значит и считать надо в своих.
struct Watering: Codable, Hashable, Sendable {
    var plant: Plant.ID
    var when: Date
}

/// Итог по одной строке — комнате, растению, дню.
struct Tally: Identifiable, Hashable, Sendable {
    var name: String
    var count: Int

    var id: String { name }
}

/// Сколько полили в этот день.
struct Chore: Identifiable, Hashable, Sendable {
    var day: Date
    var count: Int

    var id: Date { day }
}

/// Всё, что сад может рассказать о поливах.
///
/// Считается из журнала, а не копится счётчиками. Счётчики пришлось бы
/// держать согласованными с журналом, и рано или поздно они разошлись бы —
/// та же причина, по которой срок полива считается из влажности, а не
/// хранится рядом с ней.
struct Score: Sendable {
    /// Сколько поливов всего, сегодня и за последние семь дней.
    var total = 0
    var today = 0
    var week = 0

    /// Дней подряд с поливом и самая длинная такая череда за всё время.
    var streak = 0
    var best = 0

    /// По комнатам и по растениям — от большего к меньшему.
    var rooms: [Tally] = []
    var plants: [Tally] = []

    /// Последние две недели по дням, от старого к новому. Дни без полива
    /// в ряду тоже есть: без них график врал бы о промежутках.
    var days: [Chore] = []

    /// Сколько дней ряд для графика.
    static let span = 14

    /// Посчитать всё разом.
    ///
    /// Календарь и «сейчас» приходят снаружи: иначе прогон модели зависел
    /// бы от того, в каком часовом поясе и в какой день его запустили.
    static func of(_ log: [Watering], rooms: [Room],
                   now: Date = Date(),
                   calendar: Calendar = .current) -> Score {
        var score = Score()
        score.total = log.count

        let midnight = calendar.startOfDay(for: now)
        score.today = log.count { calendar.isDate($0.when, inSameDayAs: now) }
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: midnight)
            ?? midnight
        score.week = log.count { $0.when >= weekAgo }

        // Дни, в которые хоть раз полили.
        var byDay: [Date: Int] = [:]
        for note in log {
            let day = calendar.startOfDay(for: note.when)
            byDay[day, default: 0] += 1
        }
        score.streak = Self.streak(from: midnight, days: Set(byDay.keys),
                                   calendar: calendar)
        score.best = Self.best(days: Set(byDay.keys), calendar: calendar)

        // Ряд для графика: две недели подряд, включая пустые дни.
        score.days = (0 ..< Self.span).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back,
                                          to: midnight) else { return nil }
            return Chore(day: day, count: byDay[day] ?? 0)
        }

        // По комнатам и растениям.
        var byPlant: [Plant.ID: Int] = [:]
        for note in log { byPlant[note.plant, default: 0] += 1 }
        score.rooms = rooms.map { room in
            Tally(name: room.name,
                  count: room.plants.reduce(0) { $0 + (byPlant[$1.id] ?? 0) })
        }
        .filter { $0.count > 0 }
        .sorted { ($0.count, $1.name) > ($1.count, $0.name) }

        score.plants = rooms.flatMap(\.plants)
            .map { Tally(name: $0.name, count: byPlant[$0.id] ?? 0) }
            .filter { $0.count > 0 }
            .sorted { ($0.count, $1.name) > ($1.count, $0.name) }

        return score
    }

    /// Дней подряд с поливом, считая назад от сегодня.
    ///
    /// Сегодняшний пропуск череду ещё не рвёт: день не кончился, полить
    /// можно. Рвёт пропущенный вчерашний — вот он уже прошёл целиком.
    private static func streak(from midnight: Date, days: Set<Date>,
                               calendar: Calendar) -> Int {
        var day = midnight
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1,
                                                to: day),
                  days.contains(yesterday)
            else { return 0 }
            day = yesterday
        }
        var run = 0
        while days.contains(day) {
            run += 1
            guard let before = calendar.date(byAdding: .day, value: -1,
                                             to: day) else { break }
            day = before
        }
        return run
    }

    /// Самая длинная череда за всё время.
    private static func best(days: Set<Date>, calendar: Calendar) -> Int {
        var longest = 0
        for day in days {
            // Считаем только от начала череды — иначе каждый день внутри
            // неё пересчитывал бы её заново.
            let before = calendar.date(byAdding: .day, value: -1, to: day)
            if let before, days.contains(before) { continue }
            var run = 0
            var walk = day
            while days.contains(walk) {
                run += 1
                guard let next = calendar.date(byAdding: .day, value: 1,
                                               to: walk) else { break }
                walk = next
            }
            longest = max(longest, run)
        }
        return longest
    }
}
