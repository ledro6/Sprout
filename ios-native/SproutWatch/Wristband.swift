import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Сад на часах: что прислал телефон и что полили отсюда. Хранится в общей
/// папке — её читает и циферблат.
@MainActor
@Observable
final class Wristband {
    static let shared = Wristband()

    private(set) var wrist: Wrist?

    @ObservationIgnored private let relay = Relay()

    private init() {
        wrist = Wrist.read()
        relay.start()
    }

    /// Посылка с телефона. Старая не перетирает новую: посылки ходят не
    /// всегда по порядку, а полив с часов новее того, что телефон собрал до
    /// него.
    func take(_ data: Data) {
        guard let fresh = Wrist.decoded(data) else { return }
        if let wrist, fresh.older(than: wrist) { return }
        keep(fresh)
    }

    /// Полили с часов — сразу здесь и на циферблате, телефону — вдогонку.
    func water(_ id: String) {
        guard var current = wrist else { return }
        current.water(id)
        keep(current)
        relay.water(id)
    }

    private func keep(_ fresh: Wrist) {
        wrist = fresh
        fresh.write()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Связь с телефоном. Отдельно от сада: система зовёт её не с главной
/// очереди.
final class Relay: NSObject, WCSessionDelegate {
    /// Поливы, случившиеся до того, как связь поднялась. Только на главной
    /// очереди: туда же приходит и подъём связи.
    @MainActor private var waiting: [[String: Any]] = []

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Телефон рядом — сразу, с ответом свежим садом; нет — посылкой, она
    /// дойдёт, когда он проснётся.
    @MainActor
    func water(_ id: String) {
        let note: [String: Any] = [
            Wrist.Key.water: id,
            Wrist.Key.when: Date().timeIntervalSince1970,
        ]
        let session = WCSession.default
        guard session.activationState == .activated else {
            waiting.append(note)
            return
        }
        guard session.isReachable else {
            session.transferUserInfo(note)
            return
        }
        session.sendMessage(note, replyHandler: { reply in
            guard let data = reply[Wrist.Key.garden] as? Data else { return }
            Task { @MainActor in Wristband.shared.take(data) }
        }, errorHandler: { _ in
            session.transferUserInfo(note)
        })
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: (any Error)?) {
        guard state == .activated else { return }
        let data = session.receivedApplicationContext[Wrist.Key.garden] as? Data
        Task { @MainActor in
            for note in self.waiting { session.transferUserInfo(note) }
            self.waiting.removeAll()
            if let data { Wristband.shared.take(data) }
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext context: [String: Any]) {
        guard let data = context[Wrist.Key.garden] as? Data else { return }
        Task { @MainActor in Wristband.shared.take(data) }
    }
}
