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

    init() {}

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        record = try box.decodeIfPresent(Precision.Record.self, forKey: .record)
        seen = try box.decodeIfPresent(Date.self, forKey: .seen)
    }

    enum CodingKeys: String, CodingKey {
        case record, seen
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
}
