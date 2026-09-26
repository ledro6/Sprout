import Foundation
import Observation

/// Задание недели. Всё считается по журналу поливов: отменили полив —
/// задание снова не выполнено, пока неделя не кончилась.
enum Quest: String, CaseIterable, Identifiable, Sendable {
    /// Полить вовремя — когда в земле 20–40% воды.
    case onTime
    /// Поливать в разные дни.
    case days
    /// Поливы — и ни одного досуха.
    case noDrought
    /// Утренние поливы — с пяти до десяти.
    case morning
    /// Поливы — и ни одного по мокрой земле.
    case noFlood

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .onTime: "target"
        case .days: "calendar"
        case .noDrought: "sun.max"
        case .morning: "sunrise"
        case .noFlood: "drop.triangle"
        }
    }

    /// «Полейте вовремя 8 раз».
    func title(_ goal: Int) -> String {
        switch self {
        case .onTime: Lang.format("Полейте вовремя %lld раз", goal)
        case .days: Lang.format("Поливайте %lld дней за неделю", goal)
        case .noDrought: Lang.format("%lld поливов — и ни одного досуха", goal)
        case .morning: Lang.format("Полейте до десяти утра %lld раз", goal)
        case .noFlood:
            Lang.format("%lld поливов — и ни одного по мокрой земле", goal)
        }
    }

    /// Что считается — под заданием.
    var detail: String {
        switch self {
        case .onTime:
            Lang.text("Вовремя — когда в земле осталось 20–40% воды.")
        case .days:
            Lang.text("Хотя бы один полив в день, дни — не обязательно подряд.")
        case .noDrought:
            Lang.text("Пересохнет хоть один горшок — задание сорвётся до следующей недели.")
        case .morning:
            Lang.text("С пяти до десяти утра: за день вода уйдёт в корни, а не простоит в земле всю ночь.")
        case .noFlood:
            Lang.text("Мокрая земля — больше 60% воды. Корням нужен воздух.")
        }
    }
}

/// Задание этой недели: цель по размеру сада и сколько набрано.
struct Challenge: Identifiable, Hashable, Sendable {
    let quest: Quest
    let goal: Int
    var count = 0
    /// Сорвано — до конца недели уже не выполнить.
    var failed = false

    var id: Quest.ID { quest.id }
    var done: Bool { !failed && count >= goal }
    var title: String { quest.title(goal) }

    var progress: Double {
        failed ? 0 : min(Double(count) / Double(max(goal, 1)), 1)
    }
}

/// Неделя заданий — по календарю телефона: с понедельника или с
/// воскресенья, как принято в его регионе.
struct Week: Hashable, Sendable {
    let start: Date
    let end: Date
    /// «2026-W39» — ключ недели в книге заданий.
    let key: String
    let challenges: [Challenge]

    /// Заданий на неделю.
    static let size = 3
    /// Мокрая земля — больше стольких процентов воды.
    static let flood = 0.6

    var done: Int { challenges.count { $0.done } }
    var complete: Bool { !challenges.isEmpty && done == challenges.count }

    /// Сколько поливов саду нужно за неделю: у каждого растения — неделя,
    /// делённая на его срок в настоящих днях. Время сада идёт быстрее, см.
    /// `Garden.speed`.
    static func need(_ rooms: [Room]) -> Double {
        rooms.flatMap(\.plants).reduce(0) { sum, plant in
            plant.period > 0 ? sum + 7 * Garden.speed / plant.period : sum
        }
    }

    /// Три задания из пяти, по номеру недели: шаг два по кругу из пяти не
    /// повторяется, а соседние недели не совпадают целиком.
    static func quests(for index: Int) -> [Quest] {
        let pool = Quest.allCases
        let start = ((index % pool.count) + pool.count) % pool.count
        return (0 ..< size).map { pool[(start + $0 * 2) % pool.count] }
    }

    /// Цель — доля того, что саду и так нужно за неделю: задание зовёт
    /// поливать как следует, а не лишний раз.
    static func goal(_ quest: Quest, need: Double) -> Int {
        func share(_ part: Double, _ high: Int) -> Int {
            min(max(Int((need * part).rounded()), 1), high)
        }
        switch quest {
        case .onTime: return share(0.4, 12)
        case .days: return share(0.6, 5)
        case .noDrought: return share(0.5, 15)
        case .morning: return share(0.2, 5)
        case .noFlood: return share(0.5, 15)
        }
    }

    static func of(_ moment: Date, log: [Watering], rooms: [Room],
                   now: Date = Date(),
                   calendar: Calendar = .current) -> Week {
        let span = calendar.dateInterval(of: .weekOfYear, for: moment)
            ?? DateInterval(start: moment, duration: 7 * 86_400)
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                            from: span.start)
        let year = parts.yearForWeekOfYear ?? 0
        let number = parts.weekOfYear ?? 0
        let need = need(rooms)
        guard need > 0 else {
            return Week(start: span.start, end: span.end,
                        key: "\(year)-W\(number)", challenges: [])
        }
        let entries = log.filter { $0.when >= span.start && $0.when < span.end }
        // Сухое сейчас — засуха этой недели, даже если его ещё не полили.
        let parched = span.start <= now && now < span.end
            && rooms.flatMap(\.plants).contains {
                $0.moisture < Almanac.Aim.dryBelow
            }
        let challenges = quests(for: year * 53 + number).map {
            challenge($0, need: need, entries: entries, parched: parched,
                      calendar: calendar)
        }
        return Week(start: span.start, end: span.end, key: "\(year)-W\(number)",
                    challenges: challenges)
    }

    /// Одно задание по поливам недели. `parched` — в саду сейчас есть
    /// сухое растение.
    static func challenge(_ quest: Quest, need: Double, entries: [Watering],
                          parched: Bool = false,
                          calendar: Calendar = .current) -> Challenge {
        var challenge = Challenge(quest: quest, goal: goal(quest, need: need))
        switch quest {
        case .onTime:
            challenge.count = entries.count {
                $0.left.map { Almanac.Aim.zone($0) == .onTime } ?? false
            }
        case .days:
            challenge.count = Set(entries.map {
                calendar.startOfDay(for: $0.when)
            }).count
        case .noDrought:
            challenge.count = entries.count
            challenge.failed = parched || entries.contains {
                ($0.left ?? 1) < Almanac.Aim.dryBelow
            }
        case .morning:
            challenge.count = entries.count {
                (5 ..< 10).contains(calendar.component(.hour, from: $0.when))
            }
        case .noFlood:
            challenge.count = entries.count
            challenge.failed = entries.contains { ($0.left ?? 0) > flood }
        }
        return challenge
    }
}

/// Книга заданий: сколько сделано за каждую неделю — в `UserDefaults`,
/// как медали на полке, и сброс сада её не трогает. За неделю помнится
/// наибольшее: отменили полив — сделанное остаётся. Четыре полные недели
/// за одно время года — медаль сезона.
@Observable
final class QuestBook {
    static let shared = QuestBook()

    /// «2026-W39» — сколько заданий недели сделано.
    private(set) var weeks: [String: Int]
    /// «2027-winter» — сколько полных недель за это время года.
    private(set) var seasons: [String: Int]
    /// Уровень садовника, который уже праздновали.
    private(set) var celebrated: Int
    /// Новый уровень — ждёт праздника.
    private(set) var fresh: Int?

    @ObservationIgnored private let store: UserDefaults

    /// Столько полных недель за время года — медаль сезона.
    static let seasonWeeks = 4

    private enum Key {
        static let weeks = "questWeeks"
        static let seasons = "questSeasons"
        static let level = "gardenerLevel"
    }

    init(store: UserDefaults = .standard) {
        self.store = store
        weeks = store.dictionary(forKey: Key.weeks) as? [String: Int] ?? [:]
        seasons = store.dictionary(forKey: Key.seasons) as? [String: Int] ?? [:]
        celebrated = store.integer(forKey: Key.level)
    }

    /// Все сделанные задания — для опыта садовника.
    var done: Int { weeks.values.reduce(0, +) }

    /// Полных недель за всё время.
    var full: Int { weeks.values.count { $0 >= Week.size } }

    /// Сверка недели. Стала полной впервые — счёт её времени года; набралось
    /// четыре — медаль сезона на полку. `season` — «2027-winter», см.
    /// `Season.stamp`.
    func review(_ week: Week, season: String, quarter: Season.Quarter,
                cabinet: Cabinet = .shared) {
        let before = weeks[week.key] ?? 0
        guard week.done > before else { return }
        weeks[week.key] = week.done
        if week.complete, before < Week.size {
            let count = (seasons[season] ?? 0) + 1
            seasons[season] = count
            if count == Self.seasonWeeks { cabinet.deed(Award.of(quarter)) }
        }
        save()
    }

    /// Сверка уровня. В первый раз — молча: у сада с историей был бы
    /// праздник на пустом месте.
    func review(level: Int) {
        guard level > celebrated else { return }
        if celebrated > 0 { fresh = level }
        celebrated = level
        store.set(level, forKey: Key.level)
    }

    /// Праздник показан.
    func shown() { fresh = nil }

    private func save() {
        store.set(weeks, forKey: Key.weeks)
        store.set(seasons, forKey: Key.seasons)
    }
}
