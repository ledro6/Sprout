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

    /// Тот же сдвиг, огрублённый до полупункта.
    ///
    /// По нему фигурки расходятся между собой — см. `Sway`, — а это
    /// значит пересборку холста: поправка у каждой фигурки своя, одним
    /// `offset` её не сделать. Огрубление затем и нужно, чтобы холст не
    /// пересобирался на каждую сотую долю пункта: до фигурки от общего
    /// сдвига доходит меньше десятой, и полупункта ей хватает с запасом.
    ///
    /// Само присвоение под проверкой: `@Observable` будит зависимых на
    /// каждую запись, даже если записали то же самое.
    private(set) var sway: CGSize = .zero

    /// Шаг огрубления.
    private static let swayStep: CGFloat = 0.5

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
            sway = .zero
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
        sway = .zero
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

        let rough = CGSize(width: Self.rough(shift.width),
                           height: Self.rough(shift.height))
        if rough != sway { sway = rough }
    }

    /// Округление до шага огрубления.
    private static func rough(_ value: CGFloat) -> CGFloat {
        (value / swayStep).rounded() * swayStep
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
