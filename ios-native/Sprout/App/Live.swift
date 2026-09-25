import ActivityKit
import Foundation
import Observation

/// Живые действия со стороны приложения: запустить, обновить, закончить.
/// Обход и отсчёт — по одному за раз. Что в них показать, всякий раз
/// считается из сада: так они верны, откуда бы ни полили — из обхода, с
/// экрана растения, из виджета или уведомления.
@MainActor
@Observable
final class Live {
    static let shared = Live()

    /// Идёт обход — в меню его можно закончить.
    private(set) var rounding = false
    /// Идёт отсчёт до отъезда.
    private(set) var counting = false

    /// Итог обхода висит ещё немного и уходит сам.
    static let linger: TimeInterval = 10 * 60

    private init() { look() }

    /// Живые действия выключены в Настройках — кнопок для них нет.
    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    // MARK: - Обход

    func startRound() async {
        let garden = Garden.shared
        let stops = Round.stops(in: garden.rooms) {
            Store.thumb(for: $0)?.lastPathComponent
        }
        guard enabled, !stops.isEmpty else { return }
        await end(RoundAttributes.self)
        _ = try? Activity<RoundAttributes>.request(
            attributes: RoundAttributes(started: Date()),
            content: ActivityContent(state: .init(stops: stops), staleDate: nil))
        look()
    }

    func endRound() async {
        await end(RoundAttributes.self)
        look()
    }

    // MARK: - Отъезд

    /// Поездка, до которой идёт отсчёт, — «Уезжаю» открывается на ней.
    var plan: (leave: Date, back: Date)? {
        Activity<TripAttributes>.activities
            .first { Self.running($0.activityState) }
            .map { ($0.attributes.leave, $0.attributes.back) }
    }

    /// Живое действие живёт восемь часов: до отъезда дальше — система сама
    /// включит отсчёт за восемь часов до него и скажет об этом. Устаревает
    /// оно в миг отъезда: тогда отсчёт сменяется пожеланием.
    func startTrip(leave: Date, back: Date) async {
        guard enabled, let begin = Trip.countdownStart(to: leave) else { return }
        if let plan, plan.leave == leave, plan.back == back { return }
        await end(TripAttributes.self)
        let trip = TripAttributes(started: begin, leave: leave, back: back)
        let content = ActivityContent(state: status(trip), staleDate: leave)
        if begin.timeIntervalSinceNow > 60 {
            _ = try? Activity<TripAttributes>.request(
                attributes: trip, content: content, style: .standard,
                alertConfiguration: AlertConfiguration(
                    title: "Скоро отъезд",
                    body: "Отсчёт — на экране блокировки. Полейте сад перед дорогой.",
                    sound: .default),
                start: begin)
        } else {
            _ = try? Activity<TripAttributes>.request(attributes: trip,
                                                      content: content)
        }
        look()
    }

    func endTrip() async {
        await end(TripAttributes.self)
        look()
    }

    // MARK: - Кнопки в живых действиях

    func handle(_ act: LiveAct) async {
        let garden = Garden.shared
        // Команда могла разбудить приложение из фона: сад — с диска.
        garden.reload()
        garden.advance()
        switch act {
        case .water(let id):
            _ = garden.water(id)
        case .skip(let id):
            for activity in Activity<RoundAttributes>.activities
                where Self.running(activity.activityState) {
                var state = activity.content.state
                state.stops = Round.skip(id, in: state.stops)
                await put(state, into: activity)
            }
        case .waterAll:
            for plant in garden.rooms.flatMap(\.plants) {
                _ = garden.water(plant.id)
            }
            Cabinet.shared.deed(.traveler)
        }
        await sync()
    }

    /// По саду: кто в обходе полит, кто ушёл, все ли готовы к отъезду.
    func sync() async {
        let garden = Garden.shared
        let alive = Set(garden.rooms.flatMap(\.plants).map(\.id))
        for activity in Activity<RoundAttributes>.activities
            where Self.running(activity.activityState) {
            var state = activity.content.state
            state.stops = Round.mark(state.stops, log: garden.log,
                                     since: activity.attributes.started,
                                     alive: alive)
            await put(state, into: activity)
        }
        for activity in Activity<TripAttributes>.activities
            where Self.running(activity.activityState) {
            let fresh = status(activity.attributes)
            guard fresh != activity.content.state else { continue }
            await activity.update(ActivityContent(
                state: fresh, staleDate: activity.attributes.leave))
        }
        look()
    }

    // MARK: - Внутри

    /// Пройден обход — итог, и живое действие уходит само.
    private func put(_ state: RoundAttributes.ContentState,
                     into activity: Activity<RoundAttributes>) async {
        guard state != activity.content.state else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        if Round.next(state.stops) == nil {
            await activity.end(content, dismissalPolicy: .after(
                Date().addingTimeInterval(Self.linger)))
        } else {
            await activity.update(content)
        }
    }

    private func status(_ trip: TripAttributes) -> TripAttributes.ContentState {
        let garden = Garden.shared
        let needs = Trip.needs(in: garden.rooms,
                               days: Trip.days(from: trip.leave, to: trip.back))
        return TripAttributes.ContentState(
            watered: Trip.watered(garden.rooms, log: garden.log),
            neighbour: needs.count,
            visit: Trip.firstVisit(needs, leave: trip.leave))
    }

    private func end<Kind: ActivityAttributes>(_ kind: Kind.Type) async {
        for activity in Activity<Kind>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func look() {
        rounding = Activity<RoundAttributes>.activities.contains {
            Self.running($0.activityState)
        }
        counting = Activity<TripAttributes>.activities.contains {
            Self.running($0.activityState)
        }
    }

    /// Идёт, устарело или ждёт своего часа — ещё не закончено.
    private static func running(_ state: ActivityState) -> Bool {
        switch state {
        case .active, .stale, .pending: true
        default: false
        }
    }
}
