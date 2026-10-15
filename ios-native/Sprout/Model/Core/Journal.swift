import Foundation
import Observation

/// Журнал событий для самопроверки: что и как часто нажимают. Только на
/// телефоне, в `UserDefaults`; никуда не уходит — ни аналитики, ни сети.
/// Выключен, пока хозяин не включил в «О приложении». Без фото, кличек и
/// мест: событие — это вид, необязательная короткая пометка из латиницы и
/// цифр (откуда нажали, сколько полито) и время. Хранит последние `limit`
/// событий: старые вытесняются, файл не растёт.
@Observable
final class Journal {
    static let shared = Journal()

    /// Вид события; сырое значение — имя, как в списке и в плане.
    enum Kind: String, Codable, CaseIterable, Sendable {
        case waterTap = "water_tap"
        case waterGuardShown = "water_guard_shown"
        case waterGuardConfirmed = "water_guard_confirmed"
        case waterAll = "water_all"
        case addPlantStarted = "add_plant_started"
        case addPlantCompleted = "add_plant_completed"
        case notificationAction = "notification_action"
        case permissionResult = "permission_result"
        case streakBroken = "streak_broken"
    }

    /// Откуда полили. Названия экранов, не растений.
    enum Source: String, Sendable {
        case card, plant, menu, orrery, ar, tag, widget, watch, live, siri
        case notification
    }

    struct Event: Codable, Equatable, Sendable {
        var kind: Kind
        /// Короткая пометка, см. `Journal.clean`; пусто — без неё.
        var detail: String?
        var at: Date
    }

    /// Сколько последних событий хранится.
    static let limit = 200

    /// Длиннее пометки не бывает: имя растения в неё не влезет.
    static let detailLimit = 24

    private(set) var events: [Event] = []

    /// Выключен по умолчанию. Выключили — записи прекращаются, прежние
    /// остаются, пока не нажмут «Очистить».
    var enabled: Bool {
        didSet { store.set(enabled, forKey: Self.onKey) }
    }

    @ObservationIgnored private let store: UserDefaults
    private static let key = "eventJournal"
    private static let onKey = "eventJournalOn"
    private static let streakKey = "eventJournalStreak"

    init(store: UserDefaults = .standard) {
        self.store = store
        enabled = store.bool(forKey: Self.onKey)
        if let data = store.data(forKey: Self.key),
           let kept = try? JSONDecoder().decode([Event].self, from: data) {
            events = Array(kept.suffix(Self.limit))
        }
    }

    /// Записать событие. Выключено — ничего не делает.
    func note(_ kind: Kind, _ detail: String? = nil, at moment: Date = Date()) {
        guard enabled else { return }
        events.append(Event(kind: kind, detail: Self.clean(detail), at: moment))
        if events.count > Self.limit {
            events.removeFirst(events.count - Self.limit)
        }
        save()
    }

    func waterTap(_ source: Source) { note(.waterTap, source.rawValue) }

    /// Серию пересчитали: была и пропала — `streak_broken`. Пока журнал
    /// выключен, прежнее значение не помним: включили посреди разрыва —
    /// разрыв прошлый.
    func observe(streak now: Int, at moment: Date = Date()) {
        guard enabled else { return }
        let before = store.integer(forKey: Self.streakKey)
        store.set(now, forKey: Self.streakKey)
        if before > 0, now == 0 { note(.streakBroken, "\(before)", at: moment) }
    }

    func clear() {
        events = []
        store.removeObject(forKey: Self.key)
    }

    /// Пометка — только `a–z`, `0–9`, `_`, `:`, `.`, `-` и не длиннее
    /// `detailLimit`: клички, места и русский текст сюда не попадают.
    static func clean(_ detail: String?) -> String? {
        guard let detail else { return nil }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_:.-")
        let kept = String(detail.lowercased().filter { allowed.contains($0) }
            .prefix(detailLimit))
        return kept.isEmpty ? nil : kept
    }

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            store.set(data, forKey: Self.key)
        }
    }
}
