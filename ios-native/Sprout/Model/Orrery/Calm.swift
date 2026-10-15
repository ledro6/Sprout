import Foundation

/// «Тихая ночь»: в саду никто не «скоро пить» и не «сухо» — все растения
/// в норме или во влажной земле. Небо успокаивается: звёзды мерцают
/// медленнее, внизу тихая строка и, если звуки включены, короткий мягкий
/// аккорд. Сколько всего прошло в таком состоянии за месяц — «время
/// покоя» в журнале.
///
/// Покой нельзя накачать поливом. День, в который кто-то полил рано или
/// лишний раз (`Precision.Hit.early`), в счёт времени покоя не идёт
/// целиком — сколько бы часов сад ни простоял влажным. Вовремя политый
/// сад спокоен честно: земля досыхает до порога без лишней воды.
enum Calm {
    /// Тишина: растения есть, и ни одно не просит воды.
    static func isCalm(_ plants: [Plant]) -> Bool {
        !plants.isEmpty
            && plants.allSatisfy { $0.moisture >= MoistureStatus.soonBelow }
    }

    /// Через сколько настоящих секунд первое растение дойдёт до порога
    /// «скоро пить», если его не поливать; пусто — тишины нет.
    static func margin(_ plants: [Plant], speed: Double = 1) -> TimeInterval? {
        guard isCalm(plants) else { return nil }
        let days = plants.compactMap { plant -> Double? in
            guard plant.period > 0 else { return nil }
            return (plant.moisture - MoistureStatus.soonBelow) * plant.period
        }
        guard let soonest = days.min() else { return nil }
        return max(soonest, 0) * 86_400 / max(speed, 0.000_1)
    }

    /// Накопленное: секунды покоя по дням («2026-07-14»), последний
    /// взгляд и до какого мига тишина продержится сама. Приложение
    /// закрыто — часы идут: при следующем взгляде досчитывается до
    /// `until`, но не дальше: дальше влажность могли пересчитать.
    struct Book: Codable, Hashable, Sendable {
        var days: [String: Double] = [:]
        var last: Date?
        var until: Date?

        init() {}

        init(from decoder: Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            days = try box.decodeIfPresent([String: Double].self,
                                           forKey: .days) ?? [:]
            last = try box.decodeIfPresent(Date.self, forKey: .last)
            until = try box.decodeIfPresent(Date.self, forKey: .until)
        }

        enum CodingKeys: String, CodingKey {
            case days, last, until
        }
    }

    /// Хранить столько дней.
    static let keep = 70

    /// Взгляд на сад: докладывает покой с прошлого взгляда и запоминает,
    /// сколько тишина ещё продержится.
    static func observe(_ book: inout Book, plants: [Plant], now: Date,
                        speed: Double = 1, calendar: Calendar = .current) {
        if let last = book.last, let until = book.until, now > last {
            let end = min(now, until)
            if end > last { add(&book, from: last, to: end, calendar) }
        }
        book.last = now
        book.until = margin(plants, speed: speed).map {
            now.addingTimeInterval($0)
        }
        if book.days.count > keep {
            for key in book.days.keys.sorted().dropLast(keep) {
                book.days[key] = nil
            }
        }
    }

    /// Секунды промежутка по календарным дням.
    private static func add(_ book: inout Book, from start: Date, to end: Date,
                            _ calendar: Calendar) {
        var cursor = start
        var guardCount = 0
        while cursor < end, guardCount < 400 {
            guardCount += 1
            let midnight = calendar.date(
                byAdding: .day, value: 1,
                to: calendar.startOfDay(for: cursor)) ?? end
            let stop = min(end, midnight)
            let key = Observatory.dayKey(cursor, calendar: calendar)
            book.days[key, default: 0] += stop.timeIntervalSince(cursor)
            cursor = stop
        }
    }

    /// Дни с ранним или лишним поливом — они покой не копят.
    static func spoiled(_ log: [Watering], calendar: Calendar = .current)
        -> Set<String> {
        Set(log.filter { Precision.hit($0) == .early }
            .map { Observatory.dayKey($0.when, calendar: calendar) })
    }

    /// Покой за месяц `date`, секунд.
    static func total(_ book: Book, month date: Date, log: [Watering],
                      calendar: Calendar = .current) -> TimeInterval {
        let prefix = String(Observatory.dayKey(date, calendar: calendar)
            .prefix(7))
        let bad = spoiled(log, calendar: calendar)
        return book.days
            .filter { $0.key.hasPrefix(prefix) && !bad.contains($0.key) }
            .values.reduce(0, +)
    }

    /// Целые сутки и часы.
    static func split(_ seconds: TimeInterval) -> (days: Int, hours: Int) {
        let hours = Int(max(seconds, 0) / 3_600)
        return (hours / 24, hours % 24)
    }
}
