import Foundation
import SwiftUI

/// Фон: ровный цвет и узор — от угла окна, поэтому узор у экрана и листа
/// поверх него совпадает. Узор можно убрать совсем — останется цвет. Он же
/// — вуаль входа во вкладку, см. `TabEntrance`.
struct SproutField: View {
    /// Угол холста в окне: лист настроек висит ниже окна.
    @State private var corner: CGPoint = .zero

    /// Угол сверяется, когда лист встал, — см. `Settle`.
    @State private var settle = Settle()

    /// Просили меньше движения — узора нет: он живой, волны и всходы.
    @Environment(\.accessibilityReduceMotion) private var still

    /// Просили меньше прозрачности — узора нет: под стеклом шапки и
    /// плашек он и есть то, что просвечивает.
    @Environment(\.accessibilityReduceTransparency) private var solid

    var body: some View {
        // Настройку читаем телом поля, а не внутри `TimelineView`: на паузе
        // расписания смена фигурок осталась бы незамеченной. Время года
        // добавляет свою фигурку к выбранным.
        let motif = Festive.shared.motif
        let shapes = motif.dress(Settings.shared.chosen)
        let weave = Launch.shared.weave(for: shapes.count)
        let baseShade = Settings.shared.patternHue.shade
        let waveShade = Settings.shared.waveHue.shade
        let busy = !Cheer.shared.rings.isEmpty
            || Launch.shared.bloomStart != nil
            || Launch.shared.swapStart != nil
            || Ember.shared.start != nil
            || Repaint.shared.start != nil
            || Frenzy.shared.start != nil
        let lit = motif == .garland
        // Бережём заряд — огонь тоже стоит: фон рисуется на каждом экране, и
        // бегущая гирлянда — это холст десять раз в секунду. См. `Power`.
        let running = lit && !still && !Power.shared.calm
        // Узора нет вовсе при «Уменьшении движения», «Понижении
        // прозрачности» и в режиме энергосбережения системы — остаётся
        // ровный фон. Свой бережный режим и жар узор только замораживают.
        let shown = Settings.shared.pattern && !still && !solid
            && !Power.shared.lowPower
        return ZStack {
            Palette.background

            // Холст шире экрана на размах параллакса, но живёт в наложении на
            // пустой слой и обрезан по нему — иначе ZStack вырос бы.
            if shown {
                Color.clear
                    .overlay {
                        // Долю берём у `TimelineView`: он будит ровно к кадру.
                        // Нет ни волны, ни всходов, ни переходов — расписание на
                        // паузе; бежит одна гирлянда — будит реже.
                        TimelineView(.animation(
                            minimumInterval: busy ? nil : Motion.garlandFrame,
                            paused: !busy && !running)) { frame in
                            SproutPattern(waves: Cheer.shared
                                              .waves(at: frame.date),
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
                                          baseShade: baseShade,
                                          waveShade: waveShade,
                                          lag: Settings.shared.sway
                                              ? Tilt.shared.lag : [],
                                          era: Tilt.shared.era,
                                          ember: Ember.shared
                                              .smoulder(at: frame.date),
                                          garland: lit ? (running
                                              ? frame.date
                                                  .timeIntervalSinceReferenceDate
                                              : 0) : nil)
                        }
                        .padding(-Metrics.parallax)
                        .offset(x: Tilt.shared.shift.width,
                                y: Tilt.shared.shift.height)
                    }
                    .clipped()
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin }
            action: { spot in settle.put(spot) { corner = $0 } }
    }
}

/// Угол холста без спешки. Лист едет — пальцем, показом, разворачиванием
/// карточки — и угол меняется на каждом кадре; ставь его сразу, узор
/// перерисовывался бы целиком каждый кадр, и лист смахивался рывками.
/// Пока едет — узор едет вместе с ним; встал — угол сверяется с окном.
/// Первый замер — сразу, чтобы узор с самого начала стоял как у экрана.
@MainActor
private final class Settle {
    private var job: Task<Void, Never>?
    private var placed = false

    func put(_ spot: CGPoint, apply: @escaping (CGPoint) -> Void) {
        job?.cancel()
        guard placed else {
            placed = true
            apply(spot)
            return
        }
        job = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            apply(spot)
        }
    }
}

/// Фон экрана — узор во весь экран, без растяжки под панелью вкладок: она
/// серым мылила узор внизу. Равенство не объявлено нарочно: тема приходит
/// окружением, и по равенству свойств холст остался бы в старой теме.
struct SproutBackground: View {
    var body: some View {
        SproutField()
            .ignoresSafeArea()
            .onAppear { Tilt.shared.watch() }
            .onDisappear { Tilt.shared.unwatch() }
            // `initial` — чтобы выключенный параллакс не ждал первой смены.
            // Без узора наклону двигать нечего.
            .onChange(of: Settings.shared.parallax && Settings.shared.pattern,
                      initial: true) { _, on in
                Tilt.shared.parallax = on
            }
    }
}

extension View {
    /// Верх прокрутки — мягкий край, как под панелями iOS: уезжающее под
    /// строку состояния размывается, а не режется полосой узора. Полоса
    /// объявлена прокрутке панелью (`safeAreaBar`) — по ней система и
    /// кладёт край. У главной край свой, под лентой комнат.
    func sproutSoftTop() -> some View {
        safeAreaBar(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: Metrics.softTop)
                .allowsHitTesting(false)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
