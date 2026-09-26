import SwiftUI

/// Заставка на холодном запуске. Держится, пока приложение поднимается под
/// ней, чтобы не было чёрного экрана; цвет тот же, что у системного экрана
/// запуска, иначе на стыке мигнуло бы. На поле — бледный узор из фигурок, а
/// по нему плывут стеклянные капли: жидкое стекло iOS 26 преломляет узор
/// под собой, и капли видно, хотя они прозрачные.
struct Splash: View {
    /// Свойством, а не из окружения: заставка висит поверх вкладок, и сад
    /// туда не достаёт.
    let owner: String

    @State private var hello = false
    @State private var mark: Double = 0
    @State private var drops = false

    var body: some View {
        ZStack {
            Palette.welcome
                .ignoresSafeArea()

            Sprinkle()
                .ignoresSafeArea()
                .opacity(hello ? 1 : 0)

            Droplets(shown: drops)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            SproutLogo(height: Metrics.welcomeLogo, aspect: SproutLogo.plain,
                       reveal: mark)

            VStack(spacing: 0) {
                Text(Seed.greeting(for: owner))
                    .font(Typography.welcome)
                    .foregroundStyle(Palette.welcomeInk)
                    .multilineTextAlignment(.center)
                    .modifier(Grow(shown: hello, blurs: true))
                Spacer(minLength: 0)
            }
            .padding(.top, Metrics.welcomeTop)
            .padding(.horizontal, Metrics.margin)
        }
        .task { await show() }
    }

    /// Первый шаг — не пауза для красоты: смену в том же проходе, где вью
    /// появилась, SwiftUI схлопывает. У логотипа ход линейный: разъезд частей
    /// задан внутри него.
    private func show() async {
        try? await Task.sleep(for: .milliseconds(30))
        withAnimation(Motion.welcomeIn) { hello = true }
        try? await Task.sleep(for: .seconds(Motion.welcomeStep))
        withAnimation(.linear(duration: Motion.logoSeconds)) { mark = 1 }
        drops = true
    }
}

/// Бледный узор заставки — те же фигурки, что на фоне сада, вразброс и под
/// углами. Холстом: полсотни фигурок вью были бы дороже.
private struct Sprinkle: View {
    var body: some View {
        Canvas { context, size in
            let pieces = SproutShapes.pieces
            let step: CGFloat = 74
            let columns = Int(size.width / step) + 2
            let rows = Int(size.height / step) + 2
            for row in 0 ..< rows {
                for column in 0 ..< columns {
                    let index = row * columns + column
                    let piece = pieces[index % pieces.count]
                    var layer = context
                    layer.opacity = 0.09
                    // Шахматный сдвиг — чтобы не читалась сетка.
                    let shift: CGFloat = row % 2 == 0 ? 0 : step / 2
                    layer.translateBy(x: CGFloat(column) * step + shift - 20,
                                      y: CGFloat(row) * step - 10)
                    layer.rotate(by: .degrees(Double(index * 47 % 90) - 45))
                    layer.scaleBy(x: 0.8, y: 0.8)
                    layer.translateBy(x: -piece.centre.x, y: -piece.centre.y)
                    layer.fill(piece.path, with: .color(Palette.welcomeInk))
                }
            }
        }
    }
}

/// Стеклянные капли: всплывают пружиной одна за другой и медленно плывут,
/// покачиваясь. Всё о капле — из её номера, без случайных чисел: кадр от
/// кадра не мигает. Просили меньше движения — стоят на местах.
private struct Droplets: View {
    let shown: Bool

    @Environment(\.accessibilityReduceMotion) private var still

    @State private var start = Date()

    /// Доля экрана по горизонтали и вертикали, поперечник в пунктах.
    private static let drops: [(x: Double, y: Double, side: CGFloat)] = [
        (0.18, 0.22, 92), (0.82, 0.16, 58), (0.74, 0.62, 118),
        (0.2, 0.7, 70), (0.5, 0.86, 46), (0.9, 0.84, 84), (0.08, 0.46, 40),
    ]

    var body: some View {
        TimelineView(.animation(paused: still || !shown)) { frame in
            let time = frame.date.timeIntervalSince(start)
            GeometryReader { proxy in
                ForEach(Self.drops.indices, id: \.self) { index in
                    let drop = Self.drops[index]
                    let phase = Double(index) * 1.7
                    let sway: CGFloat = still ? 0
                        : CGFloat(sin(time * 0.6 + phase) * 10)
                    let rise: CGFloat = still ? 0
                        : CGFloat(cos(time * 0.45 + phase) * 8 - time * 6)
                    Color.clear
                        .frame(width: drop.side, height: drop.side)
                        .glassEffect(.regular, in: .circle)
                        .scaleEffect(shown ? 1 : 0.2)
                        .opacity(shown ? 1 : 0)
                        .animation(.spring(duration: 0.7, bounce: 0.35)
                            .delay(Double(index) * 0.07), value: shown)
                        .position(x: proxy.size.width * CGFloat(drop.x) + sway,
                                  y: proxy.size.height * CGFloat(drop.y) + rise)
                }
            }
        }
        .onChange(of: shown) { _, now in if now { start = Date() } }
    }
}

/// Приветствие подрастает на место и собирается из размытия. Без сдвигов:
/// посреди пустого экрана любое движение вбок читалось бы промахом вёрстки.
private struct Grow: ViewModifier {
    let shown: Bool
    var blurs = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : Motion.welcomeScale)
            .blur(radius: blurs && !shown && !reduceMotion
                  ? Metrics.chromeBlur : 0)
            .opacity(shown ? 1 : 0)
    }
}
