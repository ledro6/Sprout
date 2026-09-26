import SwiftUI

/// «Все политы!» — полили последнего, кто ждал воды: сверху кружась падают
/// листья цвета узора, а посередине на пару секунд встаёт стеклянная
/// плашка. Холстом, по кадрам, как блёстки праздника медали.
struct LeafFall: View {
    let done: () -> Void

    @State private var start = Date()
    @State private var shown = false

    @Environment(\.accessibilityReduceMotion) private var still

    private static let count = 44
    private static let seconds = 3.0

    private let settings = Settings.shared

    var body: some View {
        ZStack {
            if !still {
                TimelineView(.animation) { frame in
                    let elapsed = frame.date.timeIntervalSince(start)
                    Canvas { context, size in
                        guard elapsed < Self.seconds else { return }
                        let leaf = context.resolveSymbol(id: 0)
                        for index in 0 ..< Self.count {
                            draw(index, at: elapsed, in: size, leaf: leaf,
                                 into: &context)
                        }
                    } symbols: {
                        // Белым: цвет узора кладёт умножение.
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .tag(0)
                    }
                }
                .ignoresSafeArea()
            }
            Label("Все политы!", systemImage: "checkmark.circle.fill")
                .font(Typography.detail)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
                .scaleEffect(shown ? 1 : Motion.medalScale)
                .opacity(shown ? 1 : 0)
        }
        .allowsHitTesting(false)
        .task {
            withAnimation(Motion.medal) { shown = true }
            try? await Task.sleep(for: .seconds(Self.seconds - 0.8))
            withAnimation(Motion.leave) { shown = false }
            try? await Task.sleep(for: .seconds(0.8))
            done()
        }
        .accessibilityElement(children: .combine)
    }

    /// Всё о листе — из его номера: кадр от кадра не мигает.
    private func draw(_ index: Int, at time: Double, in size: CGSize,
                      leaf: GraphicsContext.ResolvedSymbol?,
                      into context: inout GraphicsContext) {
        guard let leaf else { return }
        func unit(_ salt: Int) -> Double {
            let mixed = (index &* 2_654_435_761 &+ salt &* 40_503) & 0xFFFF
            return Double(mixed) / Double(0xFFFF)
        }
        let delay = unit(1) * 0.9
        let t = time - delay
        guard t > 0 else { return }
        let fall = 140 + unit(2) * 160
        let sway = sin(t * (1.6 + unit(4) * 1.4) + unit(5) * 6) * 30
        let x = CGFloat(unit(3) * Double(size.width) + sway)
        let y = CGFloat(-30 + t * fall + 40 * t * t)
        guard y < size.height + 30 else { return }
        let fade = max(0, 1 - t / (Self.seconds - delay))
        let hue = index % 3 == 0 ? settings.waveHue : settings.patternHue
        var piece = context
        piece.opacity = fade
        piece.translateBy(x: x, y: y)
        piece.rotate(by: .radians(sin(t * 2 + unit(6) * 6) * 0.9 + unit(7) * 6))
        piece.scaleBy(x: CGFloat(0.7 + unit(8) * 0.6), y: CGFloat(0.7 + unit(8) * 0.6))
        piece.addFilter(.colorMultiply(Palette.swatch(hue)))
        piece.draw(leaf, at: .zero)
    }
}
