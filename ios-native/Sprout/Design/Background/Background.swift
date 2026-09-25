import Foundation
import SwiftUI

/// Через окружение: число берётся у окна, а окно видно только из корня.
private struct NotchKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var notch: CGFloat {
        get { self[NotchKey.self] }
        set { self[NotchKey.self] = newValue }
    }
}

/// Фон: ровный цвет и узор. Рисуется в двух местах — экраном и подложкой под
/// вырезом — от одного угла окна, поэтому узор в них совпадает.
private struct SproutField: View {
    /// Угол холста в окне: лист настроек висит ниже окна.
    @State private var corner: CGPoint = .zero

    var body: some View {
        // Настройку читаем телом поля, а не внутри `TimelineView`: на паузе
        // расписания смена фигурок осталась бы незамеченной.
        let shapes = Settings.shared.chosen
        let weave = Launch.shared.weave(for: shapes.count)
        let baseTint = Settings.shared.patternTint
        let waveTint = Settings.shared.waveTint
        let repainting = Repaint.shared.start != nil
        let frenzied = Frenzy.shared.start != nil
        return ZStack {
            Palette.background

            // Холст шире экрана на размах параллакса, но живёт в наложении на
            // пустой слой и обрезан по нему — иначе ZStack вырос бы.
            Color.clear
                .overlay {
                    // Долю берём у `TimelineView`: он будит ровно к кадру.
                    // Нет ни волны, ни всходов, ни переходов — расписание на
                    // паузе.
                    TimelineView(.animation(
                        paused: Cheer.shared.start == nil
                            && Launch.shared.bloomStart == nil
                            && Launch.shared.swapStart == nil
                            && Ember.shared.start == nil
                            && !repainting && !frenzied)) { frame in
                        SproutPattern(wave: Cheer.shared.wave(at: frame.date),
                                      origin: Cheer.shared.origin,
                                      canvas: corner,
                                      bloomFront: Launch.shared.bloomFront,
                                      bloom: Launch.shared.bloom(at: frame.date),
                                      shapes: shapes,
                                      weave: weave,
                                      swap: Launch.shared.reshape(at: frame.date),
                                      repaint: Repaint.shared
                                          .recolour(at: frame.date),
                                      frolic: Frenzy.shared
                                          .frolic(at: frame.date),
                                      baseShade: Shade(baseTint),
                                      waveShade: Shade(waveTint),
                                      lag: Settings.shared.sway
                                          ? Tilt.shared.lag : [],
                                      era: Tilt.shared.era,
                                      ember: Ember.shared
                                          .smoulder(at: frame.date))
                    }
                    .padding(-Metrics.parallax)
                    .offset(x: Tilt.shared.shift.width,
                            y: Tilt.shared.shift.height)
                }
                .clipped()
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin }
            action: { corner = $0 }
    }
}

/// Фон экрана: узор и растяжка внизу под панелью вкладок. Равенство не
/// объявлено нарочно: тема приходит окружением, и по равенству свойств холст
/// остался бы в старой теме.
struct SproutBackground: View {
    var body: some View {
        ZStack {
            SproutField()

            VStack {
                // Сверху не гасим: там подложка рисует тот же узор.
                Spacer(minLength: 0)
                wash
            }
        }
        .ignoresSafeArea()
        .onAppear { Tilt.shared.watch() }
        .onDisappear { Tilt.shared.unwatch() }
        // `initial` — чтобы выключенный параллакс не ждал первой смены.
        .onChange(of: Settings.shared.parallax, initial: true) { _, on in
            Tilt.shared.parallax = on
        }
    }

    private var wash: some View {
        let solid = Palette.background
        return LinearGradient(
            stops: [
                .init(color: solid.opacity(0), location: 0),
                .init(color: solid, location: 1 - Metrics.washStop),
                .init(color: solid, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Metrics.washHeight)
    }
}

extension View {
    /// Подложка под вырезом — экранам, у которых верх ничем не занят. Главной
    /// не нужна: верх там держит растяжка, и две подложки дали бы черту на
    /// границе.
    func sproutNotchCover() -> some View {
        modifier(SproutNotchCover())
    }
}

/// Подложка под вырезом — тот же фон от того же угла окна, обрезанный по
/// вырезу: узор проходит насквозь без шва, а содержимое под строку состояния
/// не заезжает.
private struct SproutNotchCover: ViewModifier {
    @Environment(\.notch) private var notch

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            // Без `clipped`: узор уже обрезан по своему слою, а лишний проход
            // растеризации стоил бы на каждом кадре волны.
            SproutField()
                .frame(height: notch)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}
