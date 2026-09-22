import CoreMotion
import Observation
import SwiftUI
import UIKit

/// Наклон телефона — источник параллакса для фонового узора, и он же
/// слышит тряску.
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

    /// Насколько каждый слой фигурок разошёлся с узором, огрублённое до
    /// полупункта.
    ///
    /// Слоёв несколько, у каждого своя вязкость — см. `Sway`. Пока
    /// телефон качают, слои расходятся, и фигурки плывут порознь; в покое
    /// все нули, и узор стоит ровной сеткой.
    ///
    /// Это пересборка холста: у слоёв сдвиги разные, одним `offset` их не
    /// сделать. Огрубление затем и нужно, чтобы холст не пересобирался на
    /// каждую сотую долю пункта.
    ///
    /// Само присвоение под проверкой: `@Observable` будит зависимых на
    /// каждую запись, даже если записали то же самое.
    private(set) var lag: [CGSize] = []

    /// Номер захода. Меняется в покое, и с ним меняется, каким фигуркам
    /// достанется какая вязкость: плывут каждый раз другие.
    private(set) var era = 0

    /// Шаг огрубления.
    private static let swayStep: CGFloat = 0.5

    /// Где сейчас стоит каждый слой. Не наблюдается: наружу уходит не
    /// место слоя, а его расхождение с узором.
    @ObservationIgnored private var places: [CGSize] = []

    /// Сколько секунд подряд узор уже стоит ровно.
    @ObservationIgnored private var calm = 0.0

    /// Двигать ли узор. Настройку кладёт сюда фон: датчик не знает про
    /// хранилище, а `Settings` — про датчик.
    ///
    /// Выключенный параллакс не гасит датчик: тем же потоком слышится
    /// тряска, а её выключать не просили. Узор просто встаёт на место —
    /// и встаёт сразу, а не доезжает по инерции: выключатель на то и
    /// выключатель.
    var parallax = true {
        didSet {
            guard parallax != oldValue, !parallax else { return }
            shift = .zero
            lag = []
            places = []
            calm = 0
        }
    }

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

    /// Сколько секунд подряд телефон уже трясут.
    @ObservationIgnored private var shaken = 0.0
    @ObservationIgnored private var lastSample: Date?

    /// С какой силы толчок считается тряской, в долях тяжести.
    ///
    /// Берётся `userAcceleration` — то, что осталось от датчика после
    /// вычитания силы тяжести. В покое там сотые доли, при ходьбе с
    /// телефоном в руке — до трети, так что порог в полторы тяжести
    /// случайно не набрать: телефон надо именно трясти.
    private static let shakeForce = 1.5

    /// Сколько всего надо натрясти, чтобы узор пустился вразнос.
    ///
    /// Секунды не подряд, а в сумме: за взмах датчик выходит за порог
    /// дважды — в начале и в конце, — а между ними рука на миг
    /// останавливается. Копим то, что за порогом, и спускаем накопленное
    /// вдвое быстрее, чем набираем: положил телефон — за секунду всё
    /// забылось.
    private static let shakeSeconds = 2.2
    private static let shakeFade = 2.0

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
        shaken = 0
        lastSample = nil
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.step(x: data.gravity.x, z: data.gravity.z)
            self.feel(data.userAcceleration)
        }
    }

    /// Экран ушёл.
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

        guard parallax else { return }

        // Узор едет против наклона — так он читается лежащим за экраном,
        // а не наклеенным на него.
        let target = CGSize(width: limit(-(x - seen.x) * Self.gain),
                            height: limit(-(z - seen.z) * Self.gain))
        shift = CGSize(
            width: shift.width + (target.width - shift.width) * Self.ease,
            height: shift.height + (target.height - shift.height) * Self.ease)

        // Слои плывут к той же цели, что и узор, но каждый со своей
        // вязкостью: отсюда и разъезд, и доплывание после наклона.
        if places.count != Sway.eases.count { places = Sway.rest(at: shift) }
        places = Sway.settle(places, toward: target)
        let fresh = Sway.lag(places, behind: shift).map(Self.rough)
        if fresh != lag { lag = fresh }

        // Жребий перебрасывается только в покое: слой — это вязкость, и
        // смена её на ходу дёрнула бы фигурку скачком.
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

    /// Округление до шага огрубления.
    private static func rough(_ size: CGSize) -> CGSize {
        CGSize(width: (size.width / swayStep).rounded() * swayStep,
               height: (size.height / swayStep).rounded() * swayStep)
    }

    /// Не трясут ли телефон.
    ///
    /// Натрясли — узор пускается вразнос: фигурки волной меняются на
    /// другие и перекрашиваются, а через пять секунд всё возвращается на
    /// место. См. `Frolic`.
    ///
    /// Слушается здесь, а не отдельным датчиком: `CMDeviceMotion` и так
    /// уже идёт ради параллакса, и своего ускорения ему просить не нужно.
    /// Отсюда же и уважение к «Уменьшению движения»: при нём датчик не
    /// включается вовсе, значит и тряска не слышна.
    private func feel(_ push: CMAcceleration) {
        let now = Date()
        // Промежуток берём у часов, а не «одна шестидесятая»: отсчёты
        // задерживаются, и по числу отсчётов секунды считались бы
        // неверно. Сверху ограничен — приложение могло простоять в фоне.
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
        // Пока кутерьма идёт, второй раз она не начнётся: трясти-то
        // продолжают. Отклик в руке идёт только с настоящим началом —
        // иначе он бил бы каждые две секунды, пока телефон в руке.
        guard Frenzy.shared.begin() else { return }
        Task { @MainActor in Feel.frenzy() }
    }

    private func limit(_ value: Double) -> CGFloat {
        CGFloat(min(max(value, -Metrics.parallax), Metrics.parallax))
    }
}
