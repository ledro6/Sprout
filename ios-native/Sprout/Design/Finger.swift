import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Лежит ли палец на стекле — для «подержал дольше меню», как на «Домой».
///
/// Жестам SwiftUI этого не узнать: поднятое меню забирает касание себе, и
/// жесты под ним гаснут. Наблюдатель на окне видит касание до отрыва: он
/// ничего не распознаёт, никому не мешает, и никто не может его погасить.
@MainActor
final class Finger {
    static let shared = Finger()

    /// Номер нажатия: растёт, когда палец ложится на пустое стекло. По нему
    /// видно, что держат всё то же нажатие, а не отпустили и нажали снова.
    private(set) var press = 0

    private var touches: [Held] = []

    private init() {}

    var down: Bool { touches.contains { $0.alive } }

    /// Палец не отрывали с нажатия `press`.
    func holds(_ press: Int) -> Bool {
        down && self.press == press
    }

    /// Ставит наблюдателя на ключевое окно, если его там ещё нет. Окна при
    /// первом появлении может не быть — поэтому зовут и при возвращении.
    func watch() {
        guard let window = Self.windows.first(where: \.isKeyWindow),
              !(window.gestureRecognizers ?? []).contains(where: { $0 is Lookout })
        else { return }
        window.addGestureRecognizer(Lookout.make())
    }

    /// Закрывает открытое контекстное меню. У SwiftUI для этого ничего нет,
    /// а меню из UIKit закрывается по просьбе.
    func closeMenu() {
        Self.windows.forEach(Self.close)
    }

    fileprivate func began(_ touch: UITouch) {
        touches.removeAll { !$0.alive }
        if touches.isEmpty { press += 1 }
        touches.append(Held(touch: touch))
    }

    fileprivate func ended(_ touch: UITouch) {
        touches.removeAll { !$0.alive || $0.touch === touch }
    }

    private static var windows: [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
    }

    private static func close(_ view: UIView) {
        for case let menu as UIContextMenuInteraction in view.interactions {
            menu.dismissMenu()
        }
        view.subviews.forEach(close)
    }
}

/// Касание — слабой ссылкой: пропусти наблюдатель отрыв, касание само
/// скажет, что кончилось.
private struct Held {
    weak var touch: UITouch?

    @MainActor var alive: Bool {
        guard let touch else { return false }
        return touch.phase != .ended && touch.phase != .cancelled
    }
}

/// Смотрит на касания и ничего не распознаёт. Сам никого не гасит и не
/// гаснет ни от кого: иначе поднятое меню погасило бы его вместе с прочими.
private final class Lookout: UIGestureRecognizer, UIGestureRecognizerDelegate {
    /// Касания идут дальше без задержки и отмены.
    static func make() -> Lookout {
        let lookout = Lookout(target: nil, action: nil)
        lookout.cancelsTouchesInView = false
        lookout.delaysTouchesBegan = false
        lookout.delaysTouchesEnded = false
        lookout.delegate = lookout
        return lookout
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        touches.forEach(Finger.shared.began)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        off(touches, event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        off(touches, event)
    }

    /// Сняли все пальцы — наблюдатель сдаётся: так система вернёт его в
    /// исходное к следующему нажатию.
    private func off(_ touches: Set<UITouch>, _ event: UIEvent) {
        touches.forEach(Finger.shared.ended)
        let rest = (event.allTouches ?? []).filter {
            $0.phase != .ended && $0.phase != .cancelled
        }
        if rest.isEmpty { state = .failed }
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
