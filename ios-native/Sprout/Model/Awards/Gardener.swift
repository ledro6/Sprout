import Foundation

/// Уровень садовника: опыт за поливы, задания недели и медали — и титул
/// на профиле. Опыт не копится отдельно, а считается заново: поливы — из
/// журнала, задания и медали — с полок, которые их не отнимают.
struct Gardener: Equatable, Sendable {
    let experience: Int

    /// За полив.
    static let pour = 10
    /// Сверху — за полив вовремя.
    static let aim = 5
    /// За задание недели.
    static let quest = 50
    /// За ступень медали.
    static let medal = 40

    static func of(log: [Watering], quests: Int, medals: Int) -> Gardener {
        let pours = log.reduce(0) { sum, entry in
            let onTime = entry.left.map { Almanac.Aim.zone($0) == .onTime }
                ?? false
            return sum + pour + (onTime ? aim : 0)
        }
        return Gardener(experience: pours + max(quests, 0) * quest
                            + max(medals, 0) * medal)
    }

    var level: Int { Self.level(for: experience) }
    var title: String { Self.title(level) }

    /// Опыт с начала уровня и сколько его во всём уровне.
    var into: Int { experience - Self.threshold(level) }
    var span: Int { Self.threshold(level + 1) - Self.threshold(level) }
    var left: Int { span - into }
    var progress: Double { Double(into) / Double(max(span, 1)) }

    /// С какого опыта начинается уровень: 0, 100, 300, 600, 1000… Каждый
    /// следующий на сотню длиннее прежнего.
    static func threshold(_ level: Int) -> Int {
        let level = max(level, 1)
        return 50 * (level - 1) * level
    }

    static func level(for experience: Int) -> Int {
        var level = 1
        while threshold(level + 1) <= experience { level += 1 }
        return level
    }

    /// Титулы по уровням; дальше двенадцатого — «Легенда сада».
    static func title(_ level: Int) -> String {
        let titles = [
            Lang.text("Росток"), Lang.text("Сеянец"),
            Lang.text("Юный садовод"), Lang.text("Садовод"),
            Lang.text("Хранитель подоконника"), Lang.text("Мастер лейки"),
            Lang.text("Друг папоротников"), Lang.text("Знаток земли"),
            Lang.text("Главный садовник"), Lang.text("Хозяин оранжереи"),
            Lang.text("Мудрец джунглей"), Lang.text("Легенда сада"),
        ]
        return titles[min(max(level, 1), titles.count) - 1]
    }

    static let titles = 12

    /// Оранжерея на главной по уровню: каждый уровень до восьмого — ещё
    /// горшок, дальше растения тянутся, с четвёртого цветут, с седьмого
    /// прилетают бабочки, с десятого под крышей горит гирлянда.
    struct Glasshouse: Equatable, Sendable {
        var pots: Int
        /// 0…1 — как вытянулись растения.
        var growth: Double
        var blooms: Bool
        var butterflies: Int
        /// Гирлянда под крышей — с десятого.
        var lights: Bool
    }

    var glasshouse: Glasshouse {
        let level = level
        return Glasshouse(pots: min(level, 8),
                          growth: min(0.35 + Double(level - 1) * 0.06
                                      + progress * 0.05, 1),
                          blooms: level >= 4,
                          butterflies: level >= 7 ? min((level - 5) / 2, 3) : 0,
                          lights: level >= 10)
    }
}
