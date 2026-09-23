import CoreMotion
import Observation
import SwiftUI
import UIKit

/// Наклон телефона — источник параллакса узора, и он же слышит тряску.
///
/// Один на приложение: датчик у телефона один; пока ни один экран не смотрит,
/// он выключен. Отсчёт — от медленно ползущей «привычной» точки, а не от
/// вертикали: так узор не упирается в край, как бы ни держали телефон, и
/// калибровка не нужна.
@Observable
final class Tilt {
    static let shared = Tilt()

    private(set) var shift: CGSize = .zero

    /// Расхождение каждого слоя фигурок с узором, огрублённое до полупункта,
    /// — см. `Sway`. Огрубление — чтобы холст не пересобирался на каждую
    /// сотую пункта; присвоение под проверкой, потому что `@Observable` будит
    /// зависимых на каждую запись.
    private(set) var lag: [CGSize] = []

    /// Меняется в покое — и с ним жребий, каким фигуркам какая вязкость.
    private(set) var era = 0

    private static let swayStep: CGFloat = 0.5

    @ObservationIgnored private var places: [CGSize] = []

    @ObservationIgnored private var calm = 0.0

    /// Настройку кладёт фон: датчик не знает про хранилище. Выключенный
    /// параллакс не гасит датчик — тряску выключать не просили; узор встаёт
    /// на место сразу.
    var parallax = true {
        didSet {
            guard parallax != oldValue, !parallax else { return }
            shift = .zero
            lag = []
            places = []
            calm = 0
        }
    }

    /// Полный размах — примерно за 17°.
    private static let gain = Metrics.parallax / 0.3

    /// Привычная точка возвращается в середину примерно за полторы секунды.
    private static let baseEase = 0.011

    /// Сглаживает дрожь датчика.
    private static let ease = 0.12

    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var watchers = 0
    @ObservationIgnored private var base: (x: Double, z: Double)?

    @ObservationIgnored private var shaken = 0.0
    @ObservationIgnored private var lastSample: Date?

    /// Порог тряски в долях тяжести (`userAcceleration`): при ходьбе там до
    /// трети, так что случайно не набрать.
    private static let shakeForce = 1.5

    /// Сколько надо натрясти в сумме, а не подряд: за взмах датчик выходит за
    /// порог дважды. Спускается вдвое быстрее, чем копится.
    private static let shakeSeconds = 2.2
    private static let shakeFade = 2.0

    private init() {}

    func watch() {
        watchers += 1
        guard watchers == 1,
              // При «Уменьшении движения» датчик не включается вовсе.
              !UIAccessibility.isReduceMotionEnabled,
              motion.isDeviceMotionAvailable
        else { return }

        base = nil
        motion.deviceMotionUpdateInterval = 1.0 / 60
        shaken = 0
        lastSample = nil
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.step(x: data.gravity.x, z: data.gravity.z)
            self.feel(data.userAcceleration)
        }
    }

    func unwatch() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        motion.stopDeviceMotionUpdates()
        base = nil
        shaken = 0
        lastSample = nil
        shift = .zero
        lag = []
        places = []
        calm = 0
    }

    /// Сила тяжести в осях телефона: `x` — крен, `z` — наклон к себе и от
    /// себя; третья ось меняется вместе с `z`.
    private func step(x: Double, z: Double) {
        guard let seen = base else {
            base = (x, z)
            return
        }
        base = (seen.x + (x - seen.x) * Self.baseEase,
                seen.z + (z - seen.z) * Self.baseEase)

        guard parallax else { return }

        // Против наклона — так узор читается лежащим за экраном.
        let target = CGSize(width: limit(-(x - seen.x) * Self.gain),
                            height: limit(-(z - seen.z) * Self.gain))
        shift = CGSize(
            width: shift.width + (target.width - shift.width) * Self.ease,
            height: shift.height + (target.height - shift.height) * Self.ease)

        if places.count != Sway.eases.count { places = Sway.rest(at: shift) }
        places = Sway.settle(places, toward: target)
        let fresh = Sway.lag(places, behind: shift).map(Self.rough)
        if fresh != lag { lag = fresh }

        if fresh.allSatisfy({ $0.width == 0 && $0.height == 0 }) {
            calm += motion.deviceMotionUpdateInterval
            if calm >= Sway.shuffleSeconds {
                calm = 0
                era &+= 1
            }
        } else {
            calm = 0
        }
    }

    private static func rough(_ size: CGSize) -> CGSize {
        CGSize(width: (size.width / swayStep).rounded() * swayStep,
               height: (size.height / swayStep).rounded() * swayStep)
    }

    /// Трясут ли телефон — тем же `CMDeviceMotion`, что идёт ради параллакса.
    /// См. `Frolic`.
    private func feel(_ push: CMAcceleration) {
        let now = Date()
        // Промежуток по часам, а не по числу отсчётов: они задерживаются.
        // Сверху ограничен — приложение могло стоять в фоне.
        let gap = min(max(now.timeIntervalSince(lastSample ?? now), 0), 0.1)
        lastSample = now

        let force = sqrt(push.x * push.x + push.y * push.y + push.z * push.z)
        guard force > Self.shakeForce else {
            shaken = max(0, shaken - gap * Self.shakeFade)
            return
        }
        shaken += gap
        guard shaken >= Self.shakeSeconds else { return }
        shaken = 0
        // Отклик — только с настоящим началом, иначе бил бы каждые две
        // секунды, пока трясут.
        guard Frenzy.shared.begin() else { return }
        Task { @MainActor in Feel.frenzy() }
    }

    private func limit(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, -Metrics.parallax), Metrics.parallax))
    }
}
