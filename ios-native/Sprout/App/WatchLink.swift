import Foundation
import WatchConnectivity

/// Часы: телефон шлёт им сад после каждой записи, они ему — поливы. Сад на
/// часах — лёгкий слепок (`Wrist`), а не весь файл. Посылка ложится в
/// контекст: часы получат последнюю, когда проснутся, даже если телефон к
/// тому времени уснёт. Полив с часов будит приложение в фоне.
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Нет часов или на них нет Sprout — слать некому.
    @MainActor
    func send() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired,
              session.isWatchAppInstalled,
              let data = Wrist.of(Garden.shared.rooms).encoded()
        else { return }
        try? session.updateApplicationContext([Wrist.Key.garden: data])
    }

    /// Полив с часов — в сад, в журнал и обратно на часы.
    @MainActor
    private func water(_ id: String, at moment: Date) {
        let garden = Garden.shared
        garden.reload()
        garden.advance()
        _ = garden.water(id, at: min(moment, Date()))
    }

    @MainActor
    private func reply() -> [String: Any] {
        guard let data = Wrist.of(Garden.shared.rooms).encoded() else {
            return [:]
        }
        return [Wrist.Key.garden: data]
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: (any Error)?) {
        guard state == .activated else { return }
        Task { @MainActor in self.send() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Сменили часы — связь заново, уже с новыми.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Поставили Sprout на часы — пусть сразу получат сад.
    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.send() }
    }

    /// Часы рядом — полив сразу, в ответ свежий сад.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        let id = message[Wrist.Key.water] as? String
        Task { @MainActor in
            if let id { self.water(id, at: Date()) }
            replyHandler(self.reply())
        }
    }

    /// Часы были далеко — полив дошёл позже, но записан мигом с часов.
    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any]) {
        guard let id = userInfo[Wrist.Key.water] as? String else { return }
        let moment = (userInfo[Wrist.Key.when] as? Double)
            .map(Date.init(timeIntervalSince1970:)) ?? Date()
        Task { @MainActor in self.water(id, at: moment) }
    }
}
