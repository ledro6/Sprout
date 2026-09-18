import Foundation
import LocalAuthentication
import Observation

/// Замок на приложении: Face ID, Touch ID или код-пароль телефона.
///
/// Это и есть здешние «вход» и «выход». Учётной записи у Sprout нет: нет
/// сервера, нет регистрации, нечего забыть и нечего украсть. Входить,
/// стало быть, некуда — а вот запереть сад от чужих рук на своём же
/// телефоне осмысленно, и это система умеет сама.
///
/// Через `deviceOwnerAuthentication`, а не `deviceOwnerAuthenticationWithBiometrics`:
/// первая сама откатывается на код-пароль, когда лицо не узнали или
/// биометрии на телефоне нет вовсе. Со второй человек, у которого Face ID
/// не настроен, остался бы перед запертой дверью без ключа.
@Observable
final class Lock {
    static let shared = Lock()

    /// Запирать ли приложение, когда его убирают с экрана.
    var on: Bool {
        didSet {
            store.set(on, forKey: Self.mark)
            // Выключили замок — дверь открыта: держать её запертой после
            // того, как замок сняли, было бы не запиранием, а поломкой.
            if !on { open = true }
        }
    }

    /// Открыто ли сейчас. Не сохраняется: новый запуск начинается
    /// запертым, если замок включён.
    private(set) var open: Bool

    /// Спрашивают ли прямо сейчас. Нужен, чтобы уход в систему за лицом
    /// не считался уходом приложения в фон и не запирал заново.
    private(set) var asking = false

    @ObservationIgnored private let store: UserDefaults
    private static let mark = "lock"

    init(store: UserDefaults = .standard) {
        self.store = store
        let want = store.bool(forKey: Self.mark)
        on = want
        open = !want
    }

    /// Есть ли чем запирать и как это зовётся. Нет ни биометрии, ни
    /// код-пароля — замок предлагать нечего: включённый, он запер бы сад
    /// навсегда.
    ///
    /// Спрашивается один раз и запоминается. Каждый опрос заводит свой
    /// `LAContext` и ходит за ответом в систему, а читают это из тела
    /// экрана — то есть на каждой перерисовке. Настроить Face ID, не
    /// выходя из Sprout, всё же можно, и для этого есть `refresh`: профиль
    /// зовёт его при появлении.
    @ObservationIgnored private lazy var probe = Self.sense()

    var ready: Bool { probe.ready }

    /// Чем открывают — в дательном падеже, для строки «Открывать по …».
    /// «По код-пароль» — просто ошибка в строке, поэтому падеж выбран
    /// здесь, а не на экране.
    var means: String { probe.name }

    /// Спросить систему заново — вдруг Face ID настроили только что.
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

    /// Запереть. Зовётся, когда приложение уходит с экрана.
    func close() {
        guard on, !asking else { return }
        open = false
    }

    /// Спросить ключ. Отказ оставляет дверь запертой — и это не тупик:
    /// на запертом экране есть кнопка, чтобы спросить снова.
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
