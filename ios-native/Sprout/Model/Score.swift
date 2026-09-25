import Foundation

/// Запись журнала: кого полили и когда. Время настоящее, а не садовое: по
/// садовым часам «сегодня» кончалось бы втрое чаще настоящего.
struct Watering: Codable, Hashable, Sendable {
    var plant: Plant.ID
    var when: Date
    /// Сколько воды оставалось в земле в миг полива — по этому видно, что
    /// поливают раньше срока, см. `Rhythm`. В журналах прежних сборок пусто.
    var left: Double? = nil

    /// Та же запись — по растению и мигу: доля воды в сравнении не участвует.
    func same(_ other: Watering) -> Bool {
        plant == other.plant && when == other.when
    }
}

struct Tally: Identifiable, Hashable, Sendable {
    var name: String
    var count: Int

    var id: String { name }
}

struct Chore: Identifiable, Hashable, Sendable {
    var day: Date
    var count: Int

    var id: Date { day }
}

/// Всё, что сад может рассказать о поливах. Считается из журнала, а не
/// копится счётчиками, которые рано или поздно разошлись бы с ним.
struct Score: Sendable {
    var total = 0
    var today = 0
    var week = 0

    var streak = 0
    var best = 0

    var rooms: [Tally] = []
    var plants: [Tally] = []

    /// Две недели от старого к новому, пустые дни тоже: без них график врал
    /// бы о промежутках.
    var days: [Chore] = []

    static let span = 14

    /// Календарь и «сейчас» — снаружи, чтобы прогон модели не зависел от
    /// часового пояса и дня запуска.
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

        var byDay: [Date: Int] = [:]
        for note in log {
            let day = calendar.startOfDay(for: note.when)
            byDay[day, default: 0] += 1
        }
        score.streak = Self.streak(from: midnight, days: Set(byDay.keys),
                                   calendar: calendar)
        score.best = Self.best(days: Set(byDay.keys), calendar: calendar)

        score.days = (0 ..< Self.span).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back,
                                          to: midnight) else { return nil }
            return Chore(day: day, count: byDay[day] ?? 0)
        }

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

    /// Сегодняшний пропуск череду не рвёт — день не кончился; рвёт
    /// пропущенный вчерашний.
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

    private static func best(days: Set<Date>, calendar: Calendar) -> Int {
        var longest = 0
        for day in days {
            // Считаем только от начала череды, иначе каждый её день
            // пересчитывал бы её заново.
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
