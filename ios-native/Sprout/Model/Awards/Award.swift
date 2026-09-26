import Foundation
import Observation

/// Награды — как в «Фитнесе»: за поливы, череду, заботу, сад и особые дни.
/// У каждой — лестница уровней: сто поливов — третья ступень «Поливов».
/// Уровень — это металл медали, звёзды над растением и венок с третьего,
/// см. `Emboss`. Условия считаются из журнала и сада; полученный уровень
/// не отбирается, даже если растение потом убрали, — см. `Cabinet`.
enum Award: String, CaseIterable, Identifiable, Sendable {
    case drops, bullseye
    case streak, noDrought
    case feeder, traveler
    case jungle, botanist
    case earlyBird, nightOwl, newYear
    case spring, summer, autumn, winter

    var id: String { rawValue }

    enum Group: Int, CaseIterable, Identifiable, Sendable {
        case waterings, streaks, care, garden, moments, seasons

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .waterings: Lang.text("Поливы")
            case .streaks: Lang.text("Череда")
            case .care: Lang.text("Забота")
            case .garden: Lang.text("Сад")
            case .moments: Lang.text("Особые дни")
            case .seasons: Lang.text("Сезоны")
            }
        }

        var awards: [Award] { Award.allCases.filter { $0.group == self } }
    }

    var group: Group {
        switch self {
        case .drops, .bullseye: .waterings
        case .streak, .noDrought: .streaks
        case .feeder, .traveler: .care
        case .jungle, .botanist: .garden
        case .earlyBird, .nightOwl, .newYear: .moments
        case .spring, .summer, .autumn, .winter: .seasons
        }
    }

    /// Сколько нужно набрать на каждый уровень, по возрастанию.
    var steps: [Int] {
        switch self {
        case .drops: [1, 10, 100, 500, 1000]
        case .bullseye: [10, 25, 50, 100]
        case .streak: [3, 7, 30, 100, 365]
        case .noDrought: [30, 90, 180, 365]
        case .feeder: [1, 5, 20]
        case .traveler: [1, 3, 10]
        case .jungle: [5, 10, 25, 50]
        case .botanist: [5, 10, 20, 30]
        case .earlyBird, .nightOwl: [1, 10, 50]
        case .newYear: [1, 3, 5]
        case .spring, .summer, .autumn, .winter: [1, 2, 3]
        }
    }

    var levels: Int { steps.count }

    /// Цель уровня; уровни — с единицы.
    func goal(_ level: Int) -> Int {
        steps[min(max(level, 1), levels) - 1]
    }

    /// Название ступени: «Сто поливов», «Снайпер».
    func title(_ level: Int) -> String {
        let names: [String] = switch self {
        case .drops: [Lang.text("Первая капля"), Lang.text("Десять поливов"),
                      Lang.text("Сто поливов"), Lang.text("Пятьсот поливов"),
                      Lang.text("Тысяча поливов")]
        case .bullseye: [Lang.text("В яблочко"), Lang.text("Меткий полив"),
                         Lang.text("Снайпер"), Lang.text("Мастер полива")]
        case .streak: [Lang.text("Три дня подряд"), Lang.text("Неделя подряд"),
                       Lang.text("Месяц подряд"), Lang.text("Сто дней подряд"),
                       Lang.text("Год подряд")]
        case .noDrought: [Lang.text("Месяц без засухи"),
                          Lang.text("Три месяца без засухи"),
                          Lang.text("Полгода без засухи"),
                          Lang.text("Год без засухи")]
        case .feeder: [Lang.text("Первая подкормка"),
                       Lang.text("Пять подкормок"),
                       Lang.text("Двадцать подкормок")]
        case .traveler: [Lang.text("В дорогу"), Lang.text("Бывалый путник"),
                         Lang.text("Кругосветка")]
        case .jungle: [Lang.text("Садик"), Lang.text("Джунгли"),
                       Lang.text("Оранжерея"), Lang.text("Ботанический сад")]
        case .botanist: [Lang.text("Ботаник"), Lang.text("Знаток"),
                         Lang.text("Профессор"), Lang.text("Академик")]
        case .earlyBird: [Lang.text("Жаворонок"), Lang.text("Ранняя пташка"),
                          Lang.text("Встречает рассветы")]
        case .nightOwl: [Lang.text("Сова"), Lang.text("Полуночник"),
                         Lang.text("Хранитель ночи")]
        case .newYear: [Lang.text("С Новым годом"),
                        Lang.text("Три Новых года"),
                        Lang.text("Пять Новых лет")]
        case .spring: [Lang.text("Весенний садовник"), Lang.text("Две весны"),
                       Lang.text("Три весны")]
        case .summer: [Lang.text("Летний садовник"), Lang.text("Два лета"),
                       Lang.text("Три лета")]
        case .autumn: [Lang.text("Осенний садовник"), Lang.text("Две осени"),
                       Lang.text("Три осени")]
        case .winter: [Lang.text("Зимний садовник"), Lang.text("Две зимы"),
                       Lang.text("Три зимы")]
        }
        return names[min(max(level, 1), levels) - 1]
    }

    /// За что — строкой под медалью.
    func detail(_ level: Int) -> String {
        let lines: [String] = switch self {
        case .drops: [
            Lang.text("Полить растение в первый раз."),
            Lang.text("Полить растения десять раз."),
            Lang.text("Полить растения сто раз."),
            Lang.text("Полить растения пятьсот раз."),
            Lang.text("Полить растения тысячу раз."),
        ]
        case .bullseye: [
            Lang.text("Десять поливов подряд вовремя — когда в земле 20–40% воды."),
            Lang.text("Двадцать пять поливов подряд вовремя."),
            Lang.text("Пятьдесят поливов подряд вовремя."),
            Lang.text("Сто поливов подряд вовремя."),
        ]
        case .streak: [
            Lang.text("Поливать хоть одно растение три дня подряд."),
            Lang.text("Поливать хоть одно растение семь дней подряд."),
            Lang.text("Поливать хоть одно растение тридцать дней подряд."),
            Lang.text("Поливать хоть одно растение сто дней подряд."),
            Lang.text("Поливать хоть одно растение каждый день целый год."),
        ]
        case .noDrought: [
            Lang.text("Тридцать дней ни одно растение не пересохло."),
            Lang.text("Девяносто дней ни одно растение не пересохло."),
            Lang.text("Полгода ни одно растение не пересохло."),
            Lang.text("Целый год ни одно растение не пересохло."),
        ]
        case .feeder: [
            Lang.text("Подкормить растение."),
            Lang.text("Подкормить растения пять раз."),
            Lang.text("Подкормить растения двадцать раз."),
        ]
        case .traveler: [
            Lang.text("Подготовить сад к отъезду в «Уезжаю»."),
            Lang.text("Подготовить сад к отъезду трижды."),
            Lang.text("Подготовить сад к отъезду десять раз."),
        ]
        case .jungle: [
            Lang.text("Собрать сад из пяти растений."),
            Lang.text("Собрать сад из десяти растений."),
            Lang.text("Собрать сад из двадцати пяти растений."),
            Lang.text("Собрать сад из пятидесяти растений."),
        ]
        case .botanist: [
            Lang.text("Вырастить пять разных видов."),
            Lang.text("Вырастить десять разных видов."),
            Lang.text("Вырастить двадцать разных видов."),
            Lang.text("Вырастить тридцать разных видов."),
        ]
        case .earlyBird: [
            Lang.text("Полить растение до семи утра."),
            Lang.text("Поливать до семи утра десять разных дней."),
            Lang.text("Поливать до семи утра пятьдесят разных дней."),
        ]
        case .nightOwl: [
            Lang.text("Полить растение после полуночи."),
            Lang.text("Поливать после полуночи десять разных ночей."),
            Lang.text("Поливать после полуночи пятьдесят разных ночей."),
        ]
        case .newYear: [
            Lang.text("Полить растение 31 декабря или 1 января."),
            Lang.text("Поливать под Новый год три года."),
            Lang.text("Поливать под Новый год пять лет."),
        ]
        case .spring: [
            Lang.text("Выполнить все задания четырёх недель за одну весну."),
            Lang.text("Выполнить все задания четырёх недель за две весны."),
            Lang.text("Выполнить все задания четырёх недель за три весны."),
        ]
        case .summer: [
            Lang.text("Выполнить все задания четырёх недель за одно лето."),
            Lang.text("Выполнить все задания четырёх недель за два лета."),
            Lang.text("Выполнить все задания четырёх недель за три лета."),
        ]
        case .autumn: [
            Lang.text("Выполнить все задания четырёх недель за одну осень."),
            Lang.text("Выполнить все задания четырёх недель за две осени."),
            Lang.text("Выполнить все задания четырёх недель за три осени."),
        ]
        case .winter: [
            Lang.text("Выполнить все задания четырёх недель за одну зиму."),
            Lang.text("Выполнить все задания четырёх недель за две зимы."),
            Lang.text("Выполнить все задания четырёх недель за три зимы."),
        ]
        }
        return lines[min(max(level, 1), levels) - 1]
    }

    /// Растение на медали — барельефом, см. `Emboss`. Одно на все уровни:
    /// медаль узнаётся по растению, уровень — по металлу и звёздам.
    var preset: Preset {
        switch self {
        case .drops: .monstera
        case .bullseye: .anthurium
        case .streak: .calathea
        case .noDrought: .cactus
        case .feeder: .citrus
        case .traveler: .zamioculcas
        case .jungle: .alocasia
        case .botanist: .ficus
        case .earlyBird: .tulip
        case .nightOwl: .dracaena
        case .newYear: .jade
        case .spring: .violet
        case .summer: .rose
        case .autumn: .chrysanthemum
        case .winter: .orchid
        }
    }

    /// Разовые дела, а не журнал: подкормку и отъезд журнал не помнит —
    /// их считает сама полка; времена года считает книга заданий.
    var deed: Bool {
        switch self {
        case .feeder, .traveler, .spring, .summer, .autumn, .winter: true
        default: false
        }
    }

    /// Медаль времени года — до следующей ступени не дни, а год: в
    /// «ближайшую» не годится.
    var seasonal: Bool { group == .seasons }

    static func of(_ quarter: Season.Quarter) -> Award {
        switch quarter {
        case .spring: .spring
        case .summer: .summer
        case .autumn: .autumn
        case .winter: .winter
        }
    }

    /// Уровни всех наград вместе — «получено 7 из 38».
    static var total: Int { allCases.map(\.levels).reduce(0, +) }
}

/// Ступень награды: «Поливы», третий уровень — «Сто поливов», золото.
struct Rank: Hashable, Identifiable, Sendable {
    let award: Award
    let level: Int

    init(_ award: Award, _ level: Int) {
        self.award = award
        self.level = min(max(level, 1), award.levels)
    }

    var id: String { "\(award.rawValue).\(level)" }
    var title: String { award.title(level) }
    var detail: String { award.detail(level) }
    var goal: Int { award.goal(level) }
    var alloy: Alloy { Alloy.of(level) }

    /// Верхняя ступень — дальше расти некуда.
    var top: Bool { level == award.levels }
}

/// Металл медали: свет и тень — между ними ложится отблеск. Идёт по
/// уровням: бронза, серебро, золото, платина, нефрит.
enum Alloy: Int, CaseIterable, Sendable {
    case bronze, silver, gold, platinum, jade

    static func of(_ level: Int) -> Alloy {
        Alloy(rawValue: min(max(level, 1), allCases.count) - 1) ?? .bronze
    }

    var light: Channels {
        switch self {
        case .bronze: Channels(246, 186, 128)
        case .silver: Channels(246, 248, 252)
        case .gold: Channels(255, 228, 134)
        case .platinum: Channels(236, 242, 255)
        case .jade: Channels(176, 242, 206)
        }
    }

    var dark: Channels {
        switch self {
        case .bronze: Channels(112, 56, 20)
        case .silver: Channels(96, 104, 118)
        case .gold: Channels(140, 90, 8)
        case .platinum: Channels(62, 76, 104)
        case .jade: Channels(14, 92, 64)
        }
    }

    var title: String {
        switch self {
        case .bronze: Lang.text("Бронза")
        case .silver: Lang.text("Серебро")
        case .gold: Lang.text("Золото")
        case .platinum: Lang.text("Платина")
        case .jade: Lang.text("Нефрит")
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
    /// Сколько набрано, не больше верхней цели.
    var counts: [Award: Int] = [:]
    /// Когда набрался каждый уровень — по порядку уровней. То, что по
    /// журналу не видно (сколько растений в саду сейчас), — «сейчас».
    var reached: [Award: [Date]] = [:]

    func count(_ award: Award) -> Int { counts[award] ?? 0 }

    func level(_ award: Award) -> Int { reached[award]?.count ?? 0 }

    static func of(_ log: [Watering], rooms: [Room], since: Date,
                   now: Date = Date(),
                   calendar: Calendar = .current) -> Trophies {
        var out = Trophies()
        let sorted = log.sorted { $0.when < $1.when }
        out.set(.drops, count: sorted.count,
                at: Award.drops.steps.filter { $0 <= sorted.count }
                    .map { sorted[$0 - 1].when })
        let runs = dayRuns(sorted, calendar: calendar)
        out.set(.streak, count: runs.best,
                at: Award.streak.steps.compactMap(runs.reached))
        let clean = drought(sorted, rooms: rooms, since: since, now: now)
        out.set(.noDrought, count: clean.days, at: clean.reached)
        let aim = bullseye(sorted)
        out.set(.bullseye, count: aim.best, at: aim.reached)
        let plants = rooms.flatMap(\.plants)
        out.set(.jungle, count: plants.count,
                at: Award.jungle.steps.filter { $0 <= plants.count }
                    .map { _ in now })
        let kinds = Set(plants.compactMap { Preset.known($0.species) })
        out.set(.botanist, count: kinds.count,
                at: Award.botanist.steps.filter { $0 <= kinds.count }
                    .map { _ in now })
        let hours = sorted.map {
            ($0.when, calendar.dateComponents([.year, .month, .day, .hour],
                                              from: $0.when))
        }
        /// Разные дни с таким поливом — по первому поливу каждого.
        func days(_ test: (DateComponents) -> Bool,
                  key: (DateComponents) -> Int) -> [Date] {
            var seen: Set<Int> = []
            return hours.compactMap { moment, parts in
                guard test(parts), seen.insert(key(parts)).inserted else {
                    return nil
                }
                return moment
            }
        }
        let day = { (parts: DateComponents) in
            (parts.year ?? 0) * 400 + (parts.month ?? 0) * 32 + (parts.day ?? 0)
        }
        out.tally(.earlyBird, days({ (4 ..< 7).contains($0.hour ?? 12) },
                                   key: day))
        out.tally(.nightOwl, days({ (0 ..< 4).contains($0.hour ?? 12) },
                                  key: day))
        // Новый год — праздник на двоих: 31 декабря и 1 января — один.
        out.tally(.newYear, days({
            ($0.month == 12 && $0.day == 31) || ($0.month == 1 && $0.day == 1)
        }, key: { ($0.year ?? 0) + ($0.month == 12 ? 1 : 0) }))
        return out
    }

    private mutating func set(_ award: Award, count: Int, at moments: [Date]) {
        counts[award] = min(max(count, 0), award.steps.last ?? 1)
        reached[award] = Array(moments.prefix(award.levels))
    }

    /// Счёт по разным дням: уровень — когда набрался нужный по счёту день.
    private mutating func tally(_ award: Award, _ days: [Date]) {
        set(award, count: days.count,
            at: award.steps.filter { $0 <= days.count }.map { days[$0 - 1] })
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
    /// засухи. Отсчёт — от начала сада или от последней засухи; каждый
    /// уровень — первый промежуток без засухи нужной длины.
    static func drought(_ sorted: [Watering], rooms: [Room], since: Date,
                        now: Date) -> (days: Int, reached: [Date]) {
        var dry = sorted.filter { ($0.left ?? 1) < Almanac.Aim.dryBelow }
            .map(\.when)
        for plant in rooms.flatMap(\.plants)
            where plant.moisture < Almanac.Aim.dryBelow && plant.period > 0 {
            let last = sorted.last { $0.plant == plant.id }?.when ?? since
            dry.append(min(last.addingTimeInterval(Agenda.real(plant.period)),
                           now))
        }
        dry.sort()
        let spans = Award.noDrought.steps.map { TimeInterval($0) * 86_400 }
        var firsts = [Date?](repeating: nil, count: spans.count)
        var start = since
        for moment in dry + [now] {
            let gap = moment.timeIntervalSince(start)
            for (index, span) in spans.enumerated()
                where firsts[index] == nil && gap >= span {
                firsts[index] = start.addingTimeInterval(span)
            }
            if moment < now { start = max(start, moment) }
        }
        let days = Int(max(now.timeIntervalSince(start), 0) / 86_400)
        // Длинный промежуток покрывает и короткие — уровни идут подряд.
        let reached = Array(firsts.prefix { $0 != nil }.compactMap { $0 })
        return (days, reached)
    }

    /// Поливы вовремя подряд: самая длинная серия и когда серия впервые
    /// дошла до каждой цели. Поливы прежних сборок без остатка воды
    /// пропускаются — о них судить нечем.
    static func bullseye(_ sorted: [Watering]) -> (best: Int, reached: [Date]) {
        let goals = Award.bullseye.steps
        var best = 0
        var run = 0
        var reached: [Date] = []
        for entry in sorted {
            guard let left = entry.left else { continue }
            run = Almanac.Aim.zone(left) == .onTime ? run + 1 : 0
            best = max(best, run)
            if reached.count < goals.count, run >= goals[reached.count] {
                reached.append(entry.when)
            }
        }
        return (best, reached)
    }
}

/// Полка наград: какие уровни получены и когда. В `UserDefaults`: это
/// несколько десятков дат, и сброс сада их не трогает — медали остаются,
/// как в «Фитнесе».
@Observable
final class Cabinet {
    static let shared = Cabinet()

    /// Даты уровней по порядку: вторая — когда получен второй уровень.
    private(set) var earned: [Award: [Date]]

    /// Разовые дела — сколько раз подкармливали и собирались в отъезд.
    private(set) var deeds: [Award: Int]

    /// Полученные, но ещё не показанные: их по одной показывает праздник.
    private(set) var fresh: [Rank] = []

    @ObservationIgnored private let store: UserDefaults

    private enum Key {
        static let levels = "awardLevels"
        static let deeds = "awardDeeds"
        static let reviewed = "awardsReviewed"
        /// Полка прежних сборок: награда — одна дата, без уровней.
        static let legacy = "awards"
    }

    init(store: UserDefaults = .standard) {
        self.store = store
        var earned: [Award: [Date]] = [:]
        var deeds: [Award: Int] = [:]
        var migrated = false
        if let saved = store.dictionary(forKey: Key.levels)
            as? [String: [Double]] {
            for (key, seconds) in saved {
                guard let award = Award(rawValue: key) else { continue }
                earned[award] = seconds.map(Date.init(timeIntervalSince1970:))
            }
            for (key, count) in store.dictionary(forKey: Key.deeds)
                as? [String: Int] ?? [:] {
                if let award = Award(rawValue: key) { deeds[award] = count }
            }
        } else {
            (earned, deeds) = Self.migrate(
                store.dictionary(forKey: Key.legacy) as? [String: Double] ?? [:])
            migrated = !earned.isEmpty
        }
        self.earned = earned
        self.deeds = deeds
        if migrated { save() }
    }

    /// Прежняя награда — ступень новой: «Сто поливов» — третий уровень
    /// «Поливов». Нижние уровни получены не позже верхнего — их дата та же,
    /// если своей нет.
    static func migrate(_ old: [String: Double])
        -> (earned: [Award: [Date]], deeds: [Award: Int]) {
        let steps: [String: (Award, Int)] = [
            "firstDrop": (.drops, 1), "tenDrops": (.drops, 10),
            "hundred": (.drops, 100), "thousand": (.drops, 1000),
            "week": (.streak, 7), "month": (.streak, 30),
            "noDrought": (.noDrought, 30), "bullseye": (.bullseye, 10),
            "feeder": (.feeder, 1), "traveler": (.traveler, 1),
            "jungle": (.jungle, 10), "botanist": (.botanist, 5),
            "earlyBird": (.earlyBird, 1), "nightOwl": (.nightOwl, 1),
            "newYear": (.newYear, 1),
        ]
        var known: [Award: [Int: Date]] = [:]
        for (key, seconds) in old {
            guard let step = steps[key],
                  let index = step.0.steps.firstIndex(of: step.1) else {
                continue
            }
            known[step.0, default: [:]][index + 1] =
                Date(timeIntervalSince1970: seconds)
        }
        var earned: [Award: [Date]] = [:]
        var deeds: [Award: Int] = [:]
        for (award, dates) in known {
            let top = dates.keys.max() ?? 0
            earned[award] = (1 ... max(top, 1)).compactMap { level in
                dates.filter { $0.key >= level }.values.min()
            }
            if award.deed { deeds[award] = award.goal(top) }
        }
        return (earned, deeds)
    }

    func level(_ award: Award) -> Int { earned[award]?.count ?? 0 }

    func has(_ award: Award) -> Bool { level(award) > 0 }

    func date(_ rank: Rank) -> Date? {
        guard let dates = earned[rank.award], dates.count >= rank.level else {
            return nil
        }
        return dates[rank.level - 1]
    }

    /// Все полученные ступени с датами — для итогов года.
    var dated: [Rank: Date] {
        var out: [Rank: Date] = [:]
        for (award, dates) in earned {
            for (index, moment) in dates.enumerated() {
                out[Rank(award, index + 1)] = moment
            }
        }
        return out
    }

    /// Сколько ступеней получено — из `Award.total`.
    var total: Int { earned.values.map(\.count).reduce(0, +) }

    /// Награды с текущей ступенью, от свежей к старой.
    var latest: [Rank] {
        earned.compactMap { award, dates -> (Rank, Date)? in
            guard let last = dates.last else { return nil }
            return (Rank(award, dates.count), last)
        }
        .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }
        .map(\.0)
    }

    /// Набрано к награде: журнал знает всё, кроме разовых дел.
    func count(_ award: Award, in trophies: Trophies) -> Int {
        award.deed ? deeds[award] ?? 0 : trophies.count(award)
    }

    /// Сверка с журналом и садом. В первый раз — молча: у сада с историей
    /// набралась бы дюжина праздников подряд. Перепрыгнули несколько
    /// ступеней разом — празднуется верхняя.
    func review(_ trophies: Trophies) {
        let quiet = !store.bool(forKey: Key.reviewed)
        var found: [Rank] = []
        for award in Award.allCases where !award.deed {
            let have = earned[award] ?? []
            let got = trophies.reached[award] ?? []
            guard got.count > have.count else { continue }
            earned[award] = have + got[have.count...]
            found.append(Rank(award, got.count))
        }
        store.set(true, forKey: Key.reviewed)
        guard !found.isEmpty else { return }
        save()
        if !quiet { celebrate(found) }
    }

    /// Разовое дело — подкормили, собрались в отъезд. Дошли до ступени —
    /// праздник.
    func deed(_ award: Award, at moment: Date = Date()) {
        guard award.deed else { return }
        let count = (deeds[award] ?? 0) + 1
        deeds[award] = min(count, award.steps.last ?? count)
        let have = earned[award] ?? []
        let due = award.steps.filter { $0 <= count }.count
        if due > have.count {
            earned[award] = have + Array(repeating: moment,
                                         count: due - have.count)
            celebrate([Rank(award, due)])
        }
        save()
    }

    /// Праздник показан.
    func shown(_ rank: Rank) {
        fresh.removeAll { $0 == rank }
    }

    /// Та же награда ступенью выше заменяет ждущую праздника.
    private func celebrate(_ ranks: [Rank]) {
        for rank in ranks {
            fresh.removeAll { $0.award == rank.award && $0.level < rank.level }
            if !fresh.contains(rank) { fresh.append(rank) }
        }
    }

    private func save() {
        var levels: [String: [Double]] = [:]
        for (award, dates) in earned {
            levels[award.rawValue] = dates.map(\.timeIntervalSince1970)
        }
        store.set(levels, forKey: Key.levels)
        var counts: [String: Int] = [:]
        for (award, count) in deeds { counts[award.rawValue] = count }
        store.set(counts, forKey: Key.deeds)
    }
}
