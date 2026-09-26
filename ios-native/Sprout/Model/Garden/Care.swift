import Foundation

/// Мелкий уход сверх полива и подкормки: опрыскать, повернуть к свету,
/// протереть листья. Сроки — в днях сада, как у подкормки; по виду:
/// влаголюбивым тропикам — опрыскивание, всем, кто тянется к окну, —
/// поворот, крупным гладким листьям — протирка. Опушённые листья фиалки и
/// бегонии не опрыскивают — от воды на них гниль.
enum Duty: String, CaseIterable, Codable, CodingKeyRepresentable,
           Identifiable, Sendable {
    case mist, turn, wipe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mist: Lang.text("Опрыскивание")
        case .turn: Lang.text("Поворот к свету")
        case .wipe: Lang.text("Протирка листьев")
        }
    }

    /// Подпись кнопки «сделал».
    var done: String {
        switch self {
        case .mist: Lang.text("Опрыскал")
        case .turn: Lang.text("Повернул")
        case .wipe: Lang.text("Протёр")
        }
    }

    var icon: String {
        switch self {
        case .mist: "humidity.fill"
        case .turn: "arrow.trianglehead.2.clockwise.rotate.90"
        case .wipe: "hand.wave.fill"
        }
    }

    /// Сроки на выбор в настройках растения, дней.
    var choices: [Int] {
        switch self {
        case .mist: [2, 3, 5, 7, 10]
        case .turn: [7, 10, 14, 21, 30]
        case .wipe: [14, 21, 30, 45, 60]
        }
    }

    /// «Пора опрыскать».
    var now: String {
        switch self {
        case .mist: Lang.text("Пора опрыскать")
        case .turn: Lang.text("Пора повернуть к свету")
        case .wipe: Lang.text("Пора протереть листья")
        }
    }

    /// «Опрыскать через 3 дня».
    func later(_ days: Int) -> String {
        switch self {
        case .mist: Lang.format("Опрыскать через %lld дней", days)
        case .turn: Lang.format("Повернуть через %lld дней", days)
        case .wipe: Lang.format("Протереть листья через %lld дней", days)
        }
    }

    /// Строка уведомления.
    func nudge(_ name: String) -> String {
        switch self {
        case .mist: Lang.format("«%@» просит свежей росы", name)
        case .turn: Lang.format("«%@» клонится к окну — поверните другим боком", name)
        case .wipe: Lang.format("«%@» запылился — листьям нечем дышать", name)
        }
    }

    /// Срок по виду, дней сада; пусто — этому виду не нужно.
    func usual(for preset: Preset) -> Double? {
        switch self {
        case .mist:
            switch preset {
            case .calathea, .fern: 3
            case .spathiphyllum, .alocasia, .anthurium, .palm, .citrus: 4
            case .monstera, .ficus, .ivy, .dracaena, .hoya, .chlorophytum,
                 .pilea: 7
            default: nil
            }
        case .turn:
            switch preset {
            case .orchid: nil
            case .cactus, .opuntia, .haworthia, .echeveria, .aloe, .jade: 21
            default: 14
            }
        case .wipe:
            switch preset {
            case .monstera, .ficus, .alocasia, .zamioculcas, .sansevieria,
                 .dracaena, .anthurium, .spathiphyllum, .palm, .yucca,
                 .citrus, .calathea, .hoya: 30
            default: nil
            }
        }
    }
}

/// Подкормка и пересадка: сколько дней сада прошло с последней и раз в
/// сколько их делать. Счёт — в днях сада, как и влажность: сад живёт в
/// ускоренных часах, и настоящие даты разошлись бы с процентами. Подкормка
/// считается только в пору роста — зимой удобрение жжёт корни.
struct Care: Codable, Hashable, Sendable {
    /// Раз в сколько дней подкармливать; пусто — не напоминать.
    var feedEvery: Double?
    var sinceFed: Double = 0

    /// Раз в сколько дней пересаживать; пусто — не напоминать.
    var repotEvery: Double?
    var sinceRepot: Double = 0

    /// Сроки мелкого ухода, дней сада; ноль — не напоминать. Пусто — сроки
    /// вида: в садах прежних сборок мелкого ухода не было, см.
    /// `Plant.tending`.
    var duties: [Duty: Double]?
    var dutiesSince: [Duty: Double]?

    /// Раз в сколько дней; пусто — не напоминать.
    func every(_ duty: Duty) -> Double? {
        guard let days = duties?[duty], days > 0 else { return nil }
        return days
    }

    func since(_ duty: Duty) -> Double { dutiesSince?[duty] ?? 0 }

    /// Дней до дела; пусто — не напоминать.
    func left(_ duty: Duty) -> Double? {
        every(duty).map { max(0, $0 - since(duty)) }
    }

    func due(_ duty: Duty) -> Bool { left(duty).map { $0 < 0.5 } ?? false }

    /// «Пора опрыскать», «Опрыскать через 3 дня»; пусто — не напоминать.
    func label(_ duty: Duty) -> String? {
        guard let left = left(duty) else { return nil }
        return due(duty) ? duty.now : duty.later(Int(left.rounded()))
    }

    /// Сделали — счёт заново.
    mutating func did(_ duty: Duty) {
        var since = dutiesSince ?? [:]
        since[duty] = 0
        dutiesSince = since
    }

    /// Срок из настроек; пусто — не напоминать.
    mutating func set(_ duty: Duty, every days: Double?) {
        var all = duties ?? [:]
        all[duty] = max(days ?? 0, 0)
        duties = all
    }

    /// Мелкий уход, которого ждут, — от самого близкого.
    var errands: [Duty] {
        Duty.allCases.filter { every($0) != nil }
            .sorted { (left($0) ?? 0) < (left($1) ?? 0) }
    }

    /// Сроки мелкого ухода по виду; ноль — этому виду не нужно.
    static func duties(for preset: Preset) -> [Duty: Double] {
        Dictionary(uniqueKeysWithValues: Duty.allCases.map {
            ($0, $0.usual(for: preset) ?? 0)
        })
    }

    /// Суккуленты едят раз в месяц и живут в одном горшке по два года,
    /// цветущие просят еды каждые две недели, остальные — раз в три.
    static func usual(for preset: Preset) -> Care {
        var care: Care = switch preset {
        case .cactus, .aloe, .echeveria, .jade, .sansevieria, .zamioculcas,
             .haworthia, .opuntia, .kalanchoe, .yucca:
            Care(feedEvery: 30, repotEvery: 730)
        case .orchid, .anthurium, .hoya:
            Care(feedEvery: 21, repotEvery: 730)
        case .citrus:
            Care(feedEvery: 14, repotEvery: 730)
        case .violet, .begonia, .pelargonium, .tulip, .herbs, .rose, .mint,
             .rosemary, .lily, .sunflower, .lavender, .chrysanthemum:
            Care(feedEvery: 14, repotEvery: 365)
        default:
            Care(feedEvery: 21, repotEvery: 365)
        }
        care.duties = duties(for: preset)
        return care
    }

    /// Дней до подкормки; пусто — не подкармливают.
    var feedIn: Double? { feedEvery.map { max(0, $0 - sinceFed) } }

    var repotIn: Double? { repotEvery.map { max(0, $0 - sinceRepot) } }

    var feedDue: Bool { feedIn.map { $0 < 0.5 } ?? false }

    var repotDue: Bool { repotIn.map { $0 < 0.5 } ?? false }

    mutating func pass(days: Double, growing: Bool) {
        guard days > 0 else { return }
        if growing { sinceFed += days }
        sinceRepot += days
        var since = dutiesSince ?? [:]
        for duty in Duty.allCases where every(duty) != nil {
            since[duty, default: 0] += days
        }
        dutiesSince = since
    }

    /// Сроки пересадки на выбор — в месяцах.
    static let repotMonths = [6, 12, 18, 24]

    static func days(months: Int) -> Double { Double(months) * 365 / 12 }

    static func months(days: Double) -> Int {
        Int((days * 12 / 365).rounded())
    }

    /// «Подкормка через 5 дней», «Пора подкормить».
    var feedLabel: String? {
        guard let left = feedIn else { return nil }
        if feedDue { return Lang.text("Пора подкормить") }
        return Lang.format("Подкормка через %lld дней", Int(left.rounded()))
    }

    var repotLabel: String? {
        guard let left = repotIn else { return nil }
        if repotDue { return Lang.text("Пора пересадить") }
        let months = Care.months(days: left)
        guard months >= 1 else {
            return Lang.format("Пересадка через %lld дней",
                               Int(left.rounded()))
        }
        return Lang.format("Пересадка через %lld месяцев", months)
    }
}
