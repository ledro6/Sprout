import EventKit
import Foundation

/// Сроки сада в Календаре телефона — свой календарь «Sprout», по событию на
/// день и дело, см. `Agenda`. Календарь целиком наш: при каждой сверке
/// события с сегодняшнего дня стираются и пишутся заново — проще и надёжнее,
/// чем искать, что сдвинулось. Прошедшие дни остаются как были.
@MainActor
final class CalendarSync {
    static let shared = CalendarSync()

    private let store = EKEventStore()

    /// Номер своего календаря — в `UserDefaults`: имя «Sprout» могут дать и
    /// своему календарю, а чужие события стирать нельзя.
    private let key = "sproutCalendar"

    private init() {}

    /// Полный доступ, а не «только запись»: без него свой календарь не
    /// завести и вчерашний план не стереть.
    var allowed: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func ask() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func sync(_ rooms: [Room], now: Date = Date()) {
        guard allowed, let own = calendar() else { return }
        let days = Calendar.current
        let today = days.startOfDay(for: now)
        let end = days.date(byAdding: .day, value: Agenda.horizon + 1,
                            to: today) ?? today
        let old = store.predicateForEvents(withStart: today, end: end,
                                           calendars: [own])
        for event in store.events(matching: old) {
            try? store.remove(event, span: .thisEvent, commit: false)
        }
        for entry in Agenda.plan(rooms, now: now) {
            let event = EKEvent(eventStore: store)
            event.calendar = own
            event.title = entry.title
            event.notes = entry.notes
            event.isAllDay = true
            event.startDate = entry.day
            event.endDate = entry.day
            try? store.save(event, span: .thisEvent, commit: false)
        }
        try? store.commit()
    }

    /// Выключили — календарь уходит целиком, вместе с событиями.
    func remove() {
        defer { UserDefaults.standard.removeObject(forKey: key) }
        guard allowed,
              let id = UserDefaults.standard.string(forKey: key),
              let own = store.calendar(withIdentifier: id) else { return }
        try? store.removeCalendar(own, commit: true)
    }

    /// Свой календарь: найденный по номеру или новый. Новый — там же, где
    /// календарь по умолчанию (обычно iCloud: план виден и на Mac), а не
    /// вышло — на телефоне.
    private func calendar() -> EKCalendar? {
        if let id = UserDefaults.standard.string(forKey: key),
           let found = store.calendar(withIdentifier: id) {
            return found
        }
        let sources = [store.defaultCalendarForNewEvents?.source,
                       store.sources.first { $0.sourceType == .local }]
        for source in sources.compactMap({ $0 }) {
            let own = EKCalendar(for: .event, eventStore: store)
            own.title = "Sprout"
            own.cgColor = CGColor(red: 10 / 255, green: 199 / 255,
                                  blue: 51 / 255, alpha: 1)
            own.source = source
            guard (try? store.saveCalendar(own, commit: true)) != nil else {
                continue
            }
            UserDefaults.standard.set(own.calendarIdentifier, forKey: key)
            return own
        }
        return nil
    }
}
