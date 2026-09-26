import Foundation

/// Время суток — для приветствия на главной и неба над узором.
enum Daypart: String, CaseIterable, Sendable {
    case morning, day, evening, night

    /// Утро с пяти, день с полудня, вечер с пяти, ночь с одиннадцати.
    static func of(hour: Int) -> Daypart {
        switch hour {
        case 5 ..< 12: .morning
        case 12 ..< 17: .day
        case 17 ..< 23: .evening
        default: .night
        }
    }

    static func of(_ date: Date, calendar: Calendar = .current) -> Daypart {
        of(hour: calendar.component(.hour, from: date))
    }

    var hello: String {
        switch self {
        case .morning: Lang.text("Доброе утро")
        case .day: Lang.text("Добрый день")
        case .evening: Lang.text("Добрый вечер")
        case .night: Lang.text("Доброй ночи")
        }
    }

    /// «Доброе утро, Лера» — или просто «Доброе утро», пока хозяин не
    /// назвался.
    func greeting(_ name: String) -> String {
        let name = name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? hello : Lang.format("%1$@, %2$@", hello, name)
    }

    var icon: String {
        switch self {
        case .morning: "sunrise.fill"
        case .day: "sun.max.fill"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}

/// Небо над узором главной: солнце идёт дугой с шести утра до девяти
/// вечера, после — луна и звёзды. Только положение и цвет; рисует `DaySky`.
enum Sky {
    static let sunrise = 6.0
    static let sunset = 21.0

    /// Час дробью: 14:30 — 14.5.
    static func hour(_ date: Date, calendar: Calendar = .current) -> Double {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
    }

    /// Где солнце: 0 — восход у левого края, 1 — закат у правого; ночью
    /// солнца нет.
    static func sun(at hour: Double) -> Double? {
        guard hour >= sunrise, hour <= sunset else { return nil }
        return (hour - sunrise) / (sunset - sunrise)
    }

    /// Высота дуги: у краёв — у горизонта, в полдень — выше всего.
    static func height(_ along: Double) -> Double {
        sin(.pi * min(max(along, 0), 1))
    }

    /// Цвет света: утром и вечером тёплый, днём светлый, ночью синий.
    static func glow(at hour: Double) -> Channels {
        guard let along = sun(at: hour) else { return Channels(120, 150, 255) }
        let warm = Channels(255, 176, 110)
        let noon = Channels(255, 236, 170)
        return Channels.mix(warm, noon, height(along))
    }
}

extension Cabinet {
    /// Ближайшая ступень — у которой набрано больше всего от цели, из
    /// равных — где осталось меньше. Верхние ступени и уже набранные, но
    /// ещё не сверенные, не в счёт.
    func next(_ trophies: Trophies) -> (rank: Rank, left: Int)? {
        let near = Award.allCases.compactMap { award -> (Rank, Int, Double)? in
            let level = level(award)
            guard level < award.levels else { return nil }
            let rank = Rank(award, level + 1)
            let count = count(award, in: trophies)
            let left = rank.goal - count
            guard left > 0 else { return nil }
            return (rank, left, Double(count) / Double(rank.goal))
        }
        guard let best = near.max(by: { one, other in
            one.2 != other.2 ? one.2 < other.2 : one.1 > other.1
        }) else { return nil }
        return (best.0, best.1)
    }
}
