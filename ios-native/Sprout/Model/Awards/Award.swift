import Foundation
import Observation

/// Награды — как в «Фитнесе»: за поливы, череду, заботу, сад и особые дни.
/// Медаль — металлический кружок с барельефом растения, см. `Emboss`.
/// Условия считаются из журнала и сада; полученная награда не отбирается,
/// даже если растение потом убрали, — см. `Cabinet`.
enum Award: String, CaseIterable, Identifiable, Sendable {
    case firstDrop, tenDrops, hundred, thousand
    case week, month
    case noDrought, bullseye, feeder, traveler
    case jungle, botanist
    case earlyBird, nightOwl, newYear

    var id: String { rawValue }

    enum Group: Int, CaseIterable, Identifiable, Sendable {
        case waterings, streaks, care, garden, moments

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .waterings: Lang.text("Поливы")
            case .streaks: Lang.text("Череда")
            case .care: Lang.text("Забота")
            case .garden: Lang.text("Сад")
            case .moments: Lang.text("Особые дни")
            }
        }

        var awards: [Award] { Award.allCases.filter { $0.group == self } }
    }

    var group: Group {
        switch self {
        case .firstDrop, .tenDrops, .hundred, .thousand: .waterings
        case .week, .month: .streaks
        case .noDrought, .bullseye, .feeder, .traveler: .care
        case .jungle, .botanist: .garden
        case .earlyBird, .nightOwl, .newYear: .moments
        }
    }

    var title: String {
        switch self {
        case .firstDrop: Lang.text("Первая капля")
        case .tenDrops: Lang.text("Десять поливов")
        case .hundred: Lang.text("Сто поливов")
        case .thousand: Lang.text("Тысяча поливов")
        case .week: Lang.text("Неделя подряд")
        case .month: Lang.text("Месяц подряд")
        case .noDrought: Lang.text("Месяц без засухи")
        case .bullseye: Lang.text("В яблочко")
        case .feeder: Lang.text("Первая подкормка")
        case .traveler: Lang.text("В дорогу")
        case .jungle: Lang.text("Джунгли")
        case .botanist: Lang.text("Ботаник")
        case .earlyBird: Lang.text("Жаворонок")
        case .nightOwl: Lang.text("Сова")
        case .newYear: Lang.text("С Новым годом")
        }
    }

    /// За что — строкой под медалью.
    var detail: String {
        switch self {
        case .firstDrop: Lang.text("Полить растение в первый раз.")
        case .tenDrops: Lang.text("Полить растения десять раз.")
        case .hundred: Lang.text("Полить растения сто раз.")
        case .thousand: Lang.text("Полить растения тысячу раз.")
        case .week:
            Lang.text("Поливать хоть одно растение семь дней подряд.")
        case .month:
            Lang.text("Поливать хоть одно растение тридцать дней подряд.")
        case .noDrought:
            Lang.text("Тридцать дней ни одно растение не пересохло.")
        case .bullseye:
            Lang.text("Десять поливов подряд вовремя — когда в земле 20–40% воды.")
        case .feeder: Lang.text("Подкормить растение.")
        case .traveler: Lang.text("Подготовить сад к отъезду в «Уезжаю».")
        case .jungle: Lang.text("Собрать сад из десяти растений.")
        case .botanist: Lang.text("Вырастить пять разных видов.")
        case .earlyBird: Lang.text("Полить растение до семи утра.")
        case .nightOwl: Lang.text("Полить растение после полуночи.")
        case .newYear: Lang.text("Полить растение 31 декабря или 1 января.")
        }
    }

    /// Сколько нужно набрать; у разовых — одно.
    var goal: Int {
        switch self {
        case .tenDrops, .bullseye, .jungle: 10
        case .hundred: 100
        case .thousand: 1000
        case .week: 7
        case .month, .noDrought: 30
        case .botanist: 5
        default: 1
        }
    }

    /// Растение на медали — барельефом, см. `Emboss`.
    var preset: Preset {
        switch self {
        case .firstDrop: .aloe
        case .tenDrops: .begonia
        case .hundred: .monstera
        case .thousand: .palm
        case .week: .calathea
        case .month: .spathiphyllum
        case .noDrought: .cactus
        case .bullseye: .anthurium
        case .feeder: .citrus
        case .traveler: .zamioculcas
        case .jungle: .alocasia
        case .botanist: .ficus
        case .earlyBird: .tulip
        case .nightOwl: .dracaena
        case .newYear: .jade
        }
    }

    var alloy: Alloy {
        switch self {
        case .firstDrop, .feeder: .bronze
        case .tenDrops, .week, .traveler, .botanist, .nightOwl: .silver
        case .hundred, .month, .noDrought, .newYear: .gold
        case .bullseye, .earlyBird: .rose
        case .thousand, .jungle: .jade
        }
    }

    /// Разовые — по событию, а не по журналу: подкормку и отъезд журнал не
    /// помнит.
    var deed: Bool { self == .feeder || self == .traveler }
}

/// Металл медали: свет и тень — между ними ложится отблеск.
enum Alloy: Sendable {
    case bronze, silver, gold, rose, jade

    var light: Channels {
        switch self {
        case .bronze: Channels(246, 186, 128)
        case .silver: Channels(246, 248, 252)
        case .gold: Channels(255, 228, 134)
        case .rose: Channels(255, 208, 194)
        case .jade: Channels(176, 242, 206)
        }
    }

    var dark: Channels {
        switch self {
        case .bronze: Channels(112, 56, 20)
        case .silver: Channels(96, 104, 118)
        case .gold: Channels(140, 90, 8)
        case .rose: Channels(142, 74, 64)
        case .jade: Channels(14, 92, 64)
        }
    }

    /// Ровный цвет металла — для объёмной медали, где отблеск даёт свет
    /// сцены.
    var body: Channels { Channels.mix(dark, light, 0.62) }

    /// Неполученная медаль — сталь без блеска, как серые медали в «Фитнесе».
    static let steelLight = Channels(214, 216, 220)
    static let steelDark = Channels(92, 94, 100)

    static var steel: Channels { Channels.mix(steelDark, steelLight, 0.62) }
}

/// Что набрано к наградам — по журналу и саду. Календарь и «сейчас» —
/// снаружи: прогон модели не должен зависеть от часового пояса.
struct Trophies: Sendable {
    /// Сколько набрано, не больше цели.
    var counts: [Award: Int] = [:]
    /// Когда условие выполнилось впервые. То, что по журналу не видно
    /// (сколько растений в саду сейчас), — «сейчас».
    var reached: [Award: Date] = [:]

    func count(_ award: Award) -> Int { counts[award] ?? 0 }

    static func of(_ log: [Watering], rooms: [Room], since: Date,
                   now: Date = Date(),
                   calendar: Calendar = .current) -> Trophies {
        var out = Trophies()
        let sorted = log.sorted { $0.when < $1.when }
        for award in [Award.firstDrop, .tenDrops, .hundred, .thousand] {
            out.set(award, count: sorted.count,
                    at: sorted.count >= award.goal
                        ? sorted[award.goal - 1].when : nil)
        }
        let runs = dayRuns(sorted, calendar: calendar)
        for award in [Award.week, .month] {
            out.set(award, count: runs.best,
                    at: runs.reached(award.goal))
        }
        let clean = drought(sorted, rooms: rooms, since: since, now: now)
        out.set(.noDrought, count: clean.days, at: clean.reached)
        let aim = bullseye(sorted)
        out.set(.bullseye, count: aim.best, at: aim.reached)
        let plants = rooms.flatMap(\.plants)
        out.set(.jungle, count: plants.count,
                at: plants.count >= Award.jungle.goal ? now : nil)
        let kinds = Set(plants.compactMap { Preset.known($0.species) })
        out.set(.botanist, count: kinds.count,
                at: kinds.count >= Award.botanist.goal ? now : nil)
        func first(_ test: (DateComponents) -> Bool) -> Date? {
            sorted.first {
                test(calendar.dateComponents([.month, .day, .hour], from: $0.when))
            }?.when
        }
        let dawn = first { (4 ..< 7).contains($0.hour ?? 12) }
        out.set(.earlyBird, count: dawn == nil ? 0 : 1, at: dawn)
        let night = first { (0 ..< 4).contains($0.hour ?? 12) }
        out.set(.nightOwl, count: night == nil ? 0 : 1, at: night)
        let holiday = first {
            ($0.month == 12 && $0.day == 31) || ($0.month == 1 && $0.day == 1)
        }
        out.set(.newYear, count: holiday == nil ? 0 : 1, at: holiday)
        return out
    }

    private mutating func set(_ award: Award, count: Int, at moment: Date?) {
        counts[award] = min(max(count, 0), award.goal)
        if let moment { reached[award] = moment }
    }

    /// Дни с поливом подряд: самая длинная череда и когда каждая длина
    /// набралась впервые.
    struct Runs {
        var best = 0
        var firsts: [Int: Date] = [:]

        func reached(_ length: Int) -> Date? { firsts[length] }
    }

    static func dayRuns(_ sorted: [Watering], calendar: Calendar) -> Runs {
        var runs = Runs()
        var length = 0
        var previous: Date?
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.when)
            if day == previous { continue }
            if let previous,
               calendar.date(byAdding: .day, value: 1, to: previous) == day {
                length += 1
            } else {
                length = 1
            }
            previous = day
            runs.best = max(runs.best, length)
            if runs.firsts[length] == nil { runs.firsts[length] = entry.when }
        }
        return runs
    }

    /// Засуха — полив досуха (в земле меньше процента) или растение, сухое
    /// сейчас. Сухое сейчас высохло не сейчас, а через срок после
    /// последнего полива: иначе месяц без полива сошёл бы за месяц без
    /// засухи. Отсчёт — от начала сада или от последней засухи.
    static func drought(_ sorted: [Watering], rooms: [Room], since: Date,
                        now: Date) -> (days: Int, reached: Date?) {
        var dry = sorted.filter { ($0.left ?? 1) < Almanac.Aim.dryBelow }
            .map(\.when)
        for plant in rooms.flatMap(\.plants)
            where plant.moisture < Almanac.Aim.dryBelow && plant.period > 0 {
            let last = sorted.last { $0.plant == plant.id }?.when ?? since
            dry.append(min(last.addingTimeInterval(Agenda.real(plant.period)),
                           now))
        }
        dry.sort()
        let month = TimeInterval(Award.noDrought.goal) * 86_400
        var start = since
        var reached: Date?
        for moment in dry + [now] {
            if reached == nil, moment.timeIntervalSince(start) >= month {
                reached = start.addingTimeInterval(month)
            }
            if moment < now { start = max(start, moment) }
        }
        let days = Int(max(now.timeIntervalSince(start), 0) / 86_400)
        return (days, reached)
    }

    /// Поливы вовремя подряд: самая длинная серия и когда серия впервые
    /// дошла до цели. Поливы прежних сборок без остатка воды пропускаются —
    /// о них судить нечем.
    static func bullseye(_ sorted: [Watering]) -> (best: Int, reached: Date?) {
        var best = 0
        var run = 0
        var reached: Date?
        for entry in sorted {
            guard let left = entry.left else { continue }
            run = Almanac.Aim.zone(left) == .onTime ? run + 1 : 0
            best = max(best, run)
            if reached == nil, run >= Award.bullseye.goal {
                reached = entry.when
            }
        }
        return (best, reached)
    }
}

/// Полка наград: какие получены и когда. В `UserDefaults`: это полтора
/// десятка дат, и сброс сада их не трогает — медали остаются, как в
/// «Фитнесе».
@Observable
final class Cabinet {
    static let shared = Cabinet()

    private(set) var earned: [Award: Date]

    /// Полученные, но ещё не показанные: их по одной показывает праздник.
    private(set) var fresh: [Award] = []

    @ObservationIgnored private let store: UserDefaults

    private enum Key {
        static let earned = "awards"
        static let reviewed = "awardsReviewed"
    }

    init(store: UserDefaults = .standard) {
        self.store = store
        let saved = store.dictionary(forKey: Key.earned) as? [String: Double]
            ?? [:]
        var earned: [Award: Date] = [:]
        for (key, seconds) in saved {
            if let award = Award(rawValue: key) {
                earned[award] = Date(timeIntervalSince1970: seconds)
            }
        }
        self.earned = earned
    }

    func has(_ award: Award) -> Bool { earned[award] != nil }

    /// Сверка с журналом и садом. В первый раз — молча: у сада с историей
    /// набралась бы дюжина праздников подряд.
    func review(_ trophies: Trophies) {
        let quiet = !store.bool(forKey: Key.reviewed)
        var found: [Award] = []
        for award in Award.allCases where !award.deed && earned[award] == nil {
            guard let moment = trophies.reached[award] else { continue }
            earned[award] = moment
            found.append(award)
        }
        store.set(true, forKey: Key.reviewed)
        guard !found.isEmpty else { return }
        save()
        if !quiet { fresh += found.filter { !fresh.contains($0) } }
    }

    /// Разовая награда — подкормили, собрались в отъезд.
    func deed(_ award: Award, at moment: Date = Date()) {
        guard award.deed, earned[award] == nil else { return }
        earned[award] = moment
        save()
        fresh.append(award)
    }

    /// Праздник показан.
    func shown(_ award: Award) {
        fresh.removeAll { $0 == award }
    }

    private func save() {
        var out: [String: Double] = [:]
        for (award, moment) in earned {
            out[award.rawValue] = moment.timeIntervalSince1970
        }
        store.set(out, forKey: Key.earned)
    }
}
