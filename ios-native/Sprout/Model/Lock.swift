import Foundation
import LocalAuthentication
import Observation

/// Замок на приложении: Face ID, Touch ID или код-пароль. Учётной записи у
/// Sprout нет, так что это и есть «вход».
///
/// `deviceOwnerAuthentication`, а не `…WithBiometrics`: первая сама
/// откатывается на код-пароль, и без настроенного Face ID сад не запрётся
/// навсегда.
@Observable
final class Lock {
    static let shared = Lock()

    var on: Bool {
        didSet {
            store.set(on, forKey: Self.mark)
            if !on { open = true }
        }
    }

    /// Не сохраняется: новый запуск начинается запертым.
    private(set) var open: Bool

    /// Уход в систему за лицом не должен считаться уходом в фон и запирать
    /// заново.
    private(set) var asking = false

    @ObservationIgnored private let store: UserDefaults
    private static let mark = "lock"

    init(store: UserDefaults = .standard) {
        self.store = store
        let want = store.bool(forKey: Self.mark)
        on = want
        open = !want
    }

    /// Спрашивается один раз: читают из тела экрана, а каждый опрос ходит в
    /// систему. После настройки Face ID профиль зовёт `refresh`. Нечем
    /// запирать — замок не предлагаем, иначе он запер бы сад навсегда.
    @ObservationIgnored private lazy var probe = Self.sense()

    var ready: Bool { probe.ready }

    /// В дательном падеже — для «Открывать по …».
    var means: String { probe.name }

    func refresh() { probe = Self.sense() }

    private static func sense() -> (ready: Bool, name: String) {
        let context = LAContext()
        // Опрос обязателен: до него `biometryType` всегда `none`.
        let ready = context.canEvaluatePolicy(.deviceOwnerAuthentication,
                                              error: nil)
        switch context.biometryType {
        case .faceID: return (ready, "Face ID")
        case .touchID: return (ready, "Touch ID")
        default: return (ready, "код-паролю")
        }
    }

    func close() {
        guard on, !asking else { return }
        open = false
    }

    /// Отказ оставляет дверь запертой; на экране замка есть кнопка спросить
    /// снова.
    @MainActor
    func unlock() async {
        guard !open, !asking else { return }
        asking = true
        defer { asking = false }
        let context = LAContext()
        context.localizedCancelTitle = "Отмена"
        let granted = try? await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Чтобы открыть сад")
        if granted == true { open = true }
    }
}
