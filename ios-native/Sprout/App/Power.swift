import Foundation
import Observation

/// Бережём заряд. Узор, небо и ореолы живут на каждом экране, а в режиме
/// энергосбережения, когда телефон нагрелся или хозяин так попросил в
/// настройках, они замирают: узор не ездит за наклоном — датчик слушает
/// только тряску, вчетверо реже, — небо стоит, капли и ореолы не дышат,
/// планеты и оранжерея двигаются реже. Как замерить расход — в README,
/// раздел «Батарея».
@MainActor
@Observable
final class Power {
    static let shared = Power()

    private(set) var lowPower: Bool
    private(set) var hot: Bool

    /// Живое на экране — замирает.
    var calm: Bool { Settings.shared.saver || lowPower || hot }

    @ObservationIgnored private var tokens: [NSObjectProtocol] = []

    private init() {
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        hot = Self.hot(ProcessInfo.processInfo.thermalState)
        let center = NotificationCenter.default
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange,
                     ProcessInfo.thermalStateDidChangeNotification] {
            // Уведомления приходят с чужой очереди — пересылаем на главную.
            tokens.append(center.addObserver(forName: name, object: nil,
                                             queue: .main) { _ in
                MainActor.assumeIsolated { Power.shared.refresh() }
            })
        }
    }

    /// Перечитать состояние телефона и передать датчику наклона.
    func refresh() {
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        hot = Self.hot(ProcessInfo.processInfo.thermalState)
        Tilt.shared.saving = calm
    }

    /// Горячо — с «серьёзного»: на «заметном» телефон ещё справляется сам.
    nonisolated static func hot(_ state: ProcessInfo.ThermalState) -> Bool {
        state == .serious || state == .critical
    }
}
