import Foundation
import Observation

/// Книга неба: то, что планетарий помнит между запусками, — рекорд
/// точности, прочитанные поливы и всё, что добавят игры неба. Одним JSON в
/// `UserDefaults`, как полка наград: сброс сада её не трогает. Чего нет в
/// записи прежней сборки — берётся по умолчанию.
struct SkyState: Codable, Equatable, Sendable {
    /// Рекорд точности.
    var record: Precision.Record?
    /// Последний полив, чья реакция (искра, спотыкание) уже показана.
    var seen: Date?
    /// Вопросы «Обсерватории» последних дней.
    var guesses: [Observatory.Entry] = []
    /// Звёзды наблюдателя — верные ответы за всё время.
    var stars = 0
    /// Самая длинная серия верных дней.
    var bestStreak = 0

    init() {}

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        record = try box.decodeIfPresent(Precision.Record.self, forKey: .record)
        seen = try box.decodeIfPresent(Date.self, forKey: .seen)
        guesses = try box.decodeIfPresent([Observatory.Entry].self,
                                          forKey: .guesses) ?? []
        stars = try box.decodeIfPresent(Int.self, forKey: .stars) ?? 0
        bestStreak = try box.decodeIfPresent(Int.self,
                                             forKey: .bestStreak) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case record, seen, guesses, stars, bestStreak
    }
}

@Observable
final class SkyBook {
    static let shared = SkyBook()

    private(set) var state: SkyState

    @ObservationIgnored private let store: UserDefaults

    private static let key = "skyBook"

    init(store: UserDefaults = .standard) {
        self.store = store
        if let data = store.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(SkyState.self, from: data) {
            state = saved
        } else {
            state = SkyState()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        store.set(data, forKey: Self.key)
    }

    // MARK: - Точная орбита

    /// Итог сезона по журналу; рекорд, который поднялся, запоминается.
    @discardableResult
    func standing(_ log: [Watering], now: Date = Date(),
                  side: Season.Side, calendar: Calendar = .current)
        -> Precision.Standing {
        let standing = Precision.standing(log, now: now, side: side,
                                          calendar: calendar,
                                          kept: state.record)
        if standing.record != state.record {
            state.record = standing.record
            save()
        }
        return standing
    }

    /// Свежие поливы, которых планетарий ещё не показывал. Показанными они
    /// становятся сразу: второй раз искра не вспыхнет.
    func take(_ log: [Watering], now: Date = Date()) -> [Precision.Reaction] {
        let fresh = Precision.fresh(log, since: state.seen, now: now)
        if let last = fresh.last?.when {
            state.seen = last
            save()
        }
        return fresh
    }

    // MARK: - Обсерватория

    /// Вопрос дня: кандидатки, если сегодня ещё не отвечали.
    func question(_ orbits: [Orrery.Orbit], now: Date = Date(),
                  calendar: Calendar = .current) -> [Observatory.Candidate] {
        guard Observatory.open(state.guesses, now: now, calendar: calendar)
        else { return [] }
        return Observatory.candidates(orbits)
    }

    /// Сегодняшний ответ, если он есть.
    func today(now: Date = Date(), calendar: Calendar = .current)
        -> Observatory.Entry? {
        let key = Observatory.dayKey(now, calendar: calendar)
        return state.guesses.first { $0.day == key }
    }

    func pick(_ id: Plant.ID, from candidates: [Observatory.Candidate],
              now: Date = Date(), speed: Double = Garden.speed,
              calendar: Calendar = .current) {
        guard Observatory.open(state.guesses, now: now, calendar: calendar),
              let entry = Observatory.pick(id, from: candidates, now: now,
                                           speed: speed, calendar: calendar)
        else { return }
        state.guesses.append(entry)
        state.guesses = Array(state.guesses.suffix(Observatory.keep))
        save()
        settle(now: now, calendar: calendar)
    }

    /// Открывает ответы, чей срок пришёл: звезда за верный, серия.
    func settle(now: Date = Date(), calendar: Calendar = .current) {
        var changed = false
        for index in state.guesses.indices {
            let before = state.guesses[index]
            let after = Observatory.settle(before, now: now)
            guard after != before else { continue }
            state.guesses[index] = after
            if after.outcome == .hit { state.stars += 1 }
            changed = true
        }
        let streak = Observatory.streak(state.guesses, today: now,
                                        calendar: calendar)
        if streak > state.bestStreak {
            state.bestStreak = streak
            changed = true
        }
        if changed { save() }
    }

    func streak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        Observatory.streak(state.guesses, today: now, calendar: calendar)
    }
}
