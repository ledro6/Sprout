import Foundation

/// «Точная орбита»: поливать надо, когда земля просит, — не раньше и не
/// позже. Оценка — по доле воды в миг полива (`Watering.left`), той самой,
/// что и в «Альманахе»: 20–40 % — «в яблочко», меньше 20 % — «впритык»,
/// 40 % и больше — «рано».
///
/// Награда одна и только за точность: «в яблочко» — искра у ворот и доля
/// в счёте сезона. «Впритык» — без звезды и без штрафа: запоздал, но не
/// переборщил. «Рано» — планета спотыкается, звезды нет, а доля
/// падает: чем чаще поливать лишнее, тем хуже счёт. Лишний полив
/// (`Watering.extra`) — всегда «рано», сколько бы воды ни осталось в
/// записи. Накрутить счёт поливом нельзя: «в яблочко» бывает раз за круг
/// орбиты, потому что полив возвращает землю к полной.
enum Precision {
    enum Hit: String, Codable, Sendable {
        case bullseye, tight, early
    }

    /// Оценка полива; пусто — записи прежних сборок без доли воды: гадать
    /// о них нечем.
    static func hit(_ entry: Watering) -> Hit? {
        guard entry.counts else { return .early }
        guard let left = entry.left else { return nil }
        switch Almanac.Aim.zone(min(max(left, 0), 1)) {
        case .onTime: return .bullseye
        case .lastMoment, .dry: return .tight
        case .early: return .early
        }
    }

    /// Счёт одного сезона.
    struct Tally: Hashable, Sendable {
        var bullseye = 0
        var tight = 0
        var early = 0

        /// Сколько поливов считаются в долю: «впритык» в неё не входит —
        /// ни награды, ни штрафа.
        var judged: Int { bullseye + early }

        /// Меньше стольких оценённых поливов доля не показывается: две
        /// удачи из двух — ещё не точность.
        static let minimum = 3

        var share: Double? {
            judged >= Self.minimum ? Double(bullseye) / Double(judged) : nil
        }

        mutating func add(_ hit: Hit) {
            switch hit {
            case .bullseye: bullseye += 1
            case .tight: tight += 1
            case .early: early += 1
            }
        }
    }

    /// Рекорд точности: лучшая доля за сезон, в котором было достаточно
    /// поливов. Копится на диске: сброс сада его не трогает.
    struct Record: Codable, Hashable, Sendable {
        var share: Double
        var season: String
        var judged: Int
    }

    /// Рекорд — с этого числа оценённых поливов за сезон.
    static let recordMinimum = 5

    /// Счёт по сезонам (`Season.stamp`): ключ — «2027-winter».
    static func seasons(_ log: [Watering], side: Season.Side,
                        calendar: Calendar = .current) -> [String: Tally] {
        var out: [String: Tally] = [:]
        for entry in log {
            guard let hit = hit(entry) else { continue }
            let key = Season.stamp(entry.when, side: side, calendar: calendar)
            out[key, default: Tally()].add(hit)
        }
        return out
    }

    /// Итог для шапки и журнала.
    struct Standing: Hashable, Sendable {
        var season: String
        var tally: Tally
        var record: Record?

        var share: Double? { tally.share }

        /// Сезон сейчас на рекорде: доля равна рекордной.
        var isRecord: Bool {
            guard let share, let record, tally.judged >= recordMinimum
            else { return false }
            return record.season == season && share >= record.share
        }
    }

    /// `kept` — рекорд с диска: он может быть из сезона, поливов которого
    /// в журнале уже нет.
    static func standing(_ log: [Watering], now: Date = Date(),
                         side: Season.Side, calendar: Calendar = .current,
                         kept: Record? = nil) -> Standing {
        let all = seasons(log, side: side, calendar: calendar)
        let season = Season.stamp(now, side: side, calendar: calendar)
        var best = kept
        for (key, tally) in all.sorted(by: { $0.key < $1.key }) {
            guard tally.judged >= recordMinimum, let share = tally.share
            else { continue }
            if share > best?.share ?? -1 {
                best = Record(share: share, season: key, judged: tally.judged)
            }
        }
        return Standing(season: season, tally: all[season] ?? Tally(),
                        record: best)
    }

    /// Целые проценты.
    static func percent(_ share: Double) -> Int {
        Int((min(max(share, 0), 1) * 100).rounded())
    }

    // MARK: - Живое небо

    /// Планета высохла досуха: тускнеет, пока её не польют.
    static func dried(_ moisture: Double) -> Bool {
        moisture < Almanac.Aim.dryBelow
    }

    /// Свежий полив для показа в планетарии: искра или спотыкание.
    struct Reaction: Hashable, Sendable {
        var plant: Plant.ID
        var hit: Hit
        var when: Date
    }

    /// Поливы новее `since` и не старше `within` секунд. «Впритык» без
    /// реакции: ни награды, ни наказания.
    static func fresh(_ log: [Watering], since: Date?, now: Date,
                      within: TimeInterval = 3_600) -> [Reaction] {
        log.compactMap { entry -> Reaction? in
            guard entry.when > (since ?? .distantPast),
                  now.timeIntervalSince(entry.when) < within,
                  let hit = hit(entry), hit != .tight else { return nil }
            return Reaction(plant: entry.plant, hit: hit, when: entry.when)
        }
        .sorted { $0.when < $1.when }
    }
}
