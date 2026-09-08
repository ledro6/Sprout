import CoreMotion
import Observation
import SwiftUI
import UIKit

/// Наклон телефона — источник параллакса для фонового узора.
///
/// Один на всё приложение: датчик у телефона один, а фон рисуется на
/// каждом экране. Экраны подписываются и отписываются, и пока не смотрит
/// никто, датчик выключен — включённым он тратит батарею и на погашенном
/// экране.
///
/// Отсчёт идёт не от вертикали, а от медленно ползущей «привычной» точки.
/// Телефон держат как угодно — стоя, полулёжа, на столе, — и привязка к
/// вертикали означала бы, что у половины поз узор упирается в край и там
/// стоит. Привычная точка подтягивается к текущему наклону за пару
/// секунд: качнул телефон — узор поехал, держишь ровно — вернулся в
/// середину. Это же снимает вопрос калибровки: её просто нет.
@Observable
final class Tilt {
    static let shared = Tilt()

    /// Куда уехал узор, в пунктах. Больше `Metrics.parallax` не бывает.
    private(set) var shift: CGSize = .zero

    /// Насколько наклон превращается в пункты. Полный размах набирается
    /// примерно за 17° — заметно рукой, но не требует размахивать.
    private static let gain = Metrics.parallax / 0.3

    /// Насколько привычная точка догоняет наклон за кадр. При 60 Гц это
    /// около полутора секунд до возврата в середину.
    private static let baseEase = 0.011

    /// Насколько узор догоняет цель за кадр. Сглаживает дрожь датчика:
    /// без него узор мелко трясётся вместе с рукой.
    private static let ease = 0.12

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var watchers = 0
    @ObservationIgnored private var base: (x: Double, z: Double)?

    private init() {}

    /// Экран показался и хочет параллакс.
    func watch() {
        watchers += 1
        guard watchers == 1,
              // Уважаем «Уменьшение движения»: для того эта настройка и
              // есть. Датчик тогда даже не включается, и узор стоит.
              !UIAccessibility.isReduceMotionEnabled,
              motion.isDeviceMotionAvailable
        else { return }

        base = nil
        motion.deviceMotionUpdateInterval = 1.0 / 60
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let gravity = data?.gravity else { return }
            self.step(x: gravity.x, z: gravity.z)
        }
    }

    /// Экран ушёл.
    func unwatch() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        motion.stopDeviceMotionUpdates()
        base = nil
        shift = .zero
    }

    /// Очередной отсчёт силы тяжести в осях телефона.
    ///
    /// Берём две составляющие: вдоль экрана вбок (`x` — крен) и по
    /// нормали к экрану (`z` — наклон от себя и к себе). Третья, вдоль
    /// экрана вверх, для параллакса лишняя: она меняется вместе с `z`.
    private func step(x: Double, z: Double) {
        guard let seen = base else {
            base = (x, z)
            return
        }
        base = (seen.x + (x - seen.x) * Self.baseEase,
                seen.z + (z - seen.z) * Self.baseEase)

        // Узор едет против наклона — так он читается лежащим за экраном,
        // а не наклеенным на него.
        let target = CGSize(width: limit(-(x - seen.x) * Self.gain),
                            height: limit(-(z - seen.z) * Self.gain))
        shift = CGSize(
            width: shift.width + (target.width - shift.width) * Self.ease,
            height: shift.height + (target.height - shift.height) * Self.ease)
    }

    private func limit(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, -Metrics.parallax), Metrics.parallax))
    }
}
