import Foundation

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

    /// Суккуленты едят раз в месяц и живут в одном горшке по два года,
    /// цветущие просят еды каждые две недели, остальные — раз в три.
    static func usual(for preset: Preset) -> Care {
        switch preset {
        case .cactus, .aloe, .echeveria, .jade, .sansevieria, .zamioculcas:
            Care(feedEvery: 30, repotEvery: 730)
        case .orchid:
            Care(feedEvery: 21, repotEvery: 730)
        case .violet, .begonia, .pelargonium, .tulip, .herbs:
            Care(feedEvery: 14, repotEvery: 365)
        default:
            Care(feedEvery: 21, repotEvery: 365)
        }
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
