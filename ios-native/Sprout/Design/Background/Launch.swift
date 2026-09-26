import Foundation
import Observation
import SwiftUI

/// Запуск: заставка и ступени входа — узор, заголовок, комната, сетка, панель
/// вкладок. Заставка — одна за жизнь приложения. Ступени отыгрывают и после
/// замка: сад заперли — вход прячется под замком, открыли по лицу или
/// пальцу — узор всходит и всё встаёт на места заново, как после
/// приветствия.
@Observable
final class Launch {
    static let shared = Launch()

    private(set) var step = 0

    private(set) var greeting = true

    /// Всходы — полосой в случайную сторону, своей на каждый запуск.
    @ObservationIgnored private(set) var bloomFront =
        Front.sweep(Double.random(in: 0 ..< 2 * Double.pi))

    /// Три числа раскладки — свои на каждый холодный запуск.
    @ObservationIgnored private let twistX = Int.random(in: 0 ..< 64)
    @ObservationIgnored private let twistY = Int.random(in: 0 ..< 64)
    @ObservationIgnored private let twistStart = Int.random(in: 0 ..< 64)

    private(set) var swapStart: Date?

    @ObservationIgnored private var swapping: Reshape?
    @ObservationIgnored private var swaps: [Reshape] = []
    @ObservationIgnored private var swapRun: Task<Void, Never>?

    /// Из тех же трёх чисел: пока фигурок столько же, раскладка та же.
    func weave(for count: Int) -> Weave {
        Weave(count: count, twistX: twistX, twistY: twistY, start: twistStart)
    }

    /// Часами, а не долей в состоянии вью — по той же причине, что у `Cheer`.
    private(set) var bloomStart: Date?

    static let last = 5

    @ObservationIgnored private var ran = false

    /// Новые всходы отменяют прежние.
    @ObservationIgnored private var blooming: Task<Void, Never>?

    /// Ступени, что идут сейчас: запертый посреди входа сад их обрывает.
    @ObservationIgnored private var entering: Task<Void, Never>?

    private init() {}

    /// Второй раз ничего не делает: запуск у приложения один. Сад заперт —
    /// приветствие ждёт ключа: под замком его никто бы не увидел.
    @MainActor
    func run() async {
        guard !ran else { return }
        ran = true
        while Lock.shared.on, !Lock.shared.open {
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .seconds(Motion.welcomeHold))
        withAnimation(Motion.welcomeLeave) { greeting = false }
        // Ступени ждут, пока заставка сойдёт: иначе узор и заголовок вставали
        // на места под ней.
        try? await Task.sleep(for: .seconds(Motion.welcomeLeaveSeconds))
        let steps = Task { @MainActor in await enter() }
        entering = steps
        await steps.value
    }

    /// Сад заперли — вход прячется под замком: так после ключа ему есть что
    /// играть. Пока идёт приветствие, прятать нечего.
    @MainActor
    func hide() {
        guard !greeting else { return }
        entering?.cancel()
        entering = nil
        blooming?.cancel()
        bloomStart = nil
        step = 0
    }

    /// Открыли по лицу или пальцу — вход заново: всходы и ступени.
    @MainActor
    func replay() {
        guard !greeting, step == 0 else { return }
        entering?.cancel()
        entering = Task { @MainActor in await enter() }
    }

    @MainActor
    private func enter() async {
        while step < Self.last {
            if Task.isCancelled { return }
            withAnimation(Motion.enter) { step += 1 }
            if step == 1 { sprout() }
            try? await Task.sleep(for: .seconds(Motion.enterStep))
        }
    }

    /// Сменить набор фигурок: прежний уходит волной, новый приходит следом —
    /// из нажатой клетки или с краёв. Второе нажатие встаёт в очередь; пары
    /// «откуда — куда» сцепляются сами.
    @MainActor
    func reshape(from before: [Int], to after: [Int], front: Front) {
        // Очередь — как у `Repaint.begin`.
        if swaps.count >= Motion.queued, var last = swaps.popLast() {
            last.to = after
            last.toWeave = weave(for: after.count)
            last.front = front
            swaps.append(last)
        } else {
            swaps.append(Reshape(from: before,
                                 fromWeave: weave(for: before.count),
                                 to: after, toWeave: weave(for: after.count),
                                 front: front, step: 0))
        }
        guard swapRun == nil else { return }
        // Первая смена трогается здесь — см. `Repaint.begin`.
        swapStep()
        swapRun = Task { @MainActor in
            while swapping != nil {
                // Пока идёт промежуток, узор держит набор отыгравшего, а не
                // настройку.
                try? await Task.sleep(
                    for: .seconds(Motion.swapSeconds + Motion.changeGap))
                if Task.isCancelled { break }
                swapStep()
            }
            swapping = nil
            swapStart = nil
            swapRun = nil
        }
    }

    @MainActor
    private func swapStep() {
        swapping = swaps.isEmpty ? nil : swaps.removeFirst()
        swapStart = swapping == nil ? nil : Date()
    }

    func reshape(at moment: Date) -> Reshape? {
        guard var now = swapping, let swapStart else { return nil }
        let done = moment.timeIntervalSince(swapStart) / Motion.swapSeconds
        now.step = min(max(done, 0), 1)
        return now
    }

    @MainActor
    func sprout() {
        bloomFront = .sweep(Double.random(in: 0 ..< 2 * Double.pi))
        bloomStart = Date()
        Feel.sprout()
        blooming?.cancel()
        // Погасим часы, чтобы расписание холста встало на паузу.
        blooming = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.bloomSeconds))
            guard !Task.isCancelled else { return }
            bloomStart = nil
        }
    }

    func bloom(at moment: Date) -> Double {
        guard let bloomStart else { return step >= 1 ? 1 : 0 }
        let done = moment.timeIntervalSince(bloomStart) / Motion.bloomSeconds
        return done < 1 ? done : 1
    }
}

/// Ступень входа: элемент поднимается на место и наводится на резкость.
/// Начальное значение — из счётчика, иначе созданный позже элемент всплывал
/// бы заново.
struct Enter: ViewModifier {
    let step: Int

    let rise: CGFloat

    @State private var shown: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(step: Int, rise: CGFloat = Motion.enterRise) {
        self.step = step
        self.rise = rise
        _shown = State(initialValue: Launch.shared.step >= step)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown || reduceMotion ? 0 : Metrics.textBlur)
            .offset(y: shown ? 0 : rise)
            .onChange(of: Launch.shared.step >= step) { _, open in
                withAnimation(Motion.enter) { shown = open }
            }
    }
}

/// Замер, спрятанный от SwiftUI: меняется каждый кадр прокрутки, а читается
/// только в обработчике нажатия. Прятать то, что рисуется, нельзя — на этом
/// уже обжигались, см. `revealed` на главной.
final class Spot {
    var rect: CGRect = .zero

}
