import SwiftUI

/// Звёзды планетария — неподвижные, мерцают вразнобой. Места — из
/// постоянного зерна: небо не перетасовывается при каждом открытии.
struct StarField: View {
    private static let stars: [(x: Double, y: Double, size: Double,
                                phase: Double)] = {
        var seed: UInt64 = 0x5EED
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0 ..< 90).map { _ in
            (next(), next(), 0.6 + next() * 1.6, next())
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                canvas.fill(Path(CGRect(origin: .zero, size: size)),
                            with: .radialGradient(
                                Gradient(colors: [Palette.spaceGlow,
                                                  Palette.space]),
                                center: CGPoint(x: size.width / 2,
                                                y: size.height * 0.3),
                                startRadius: 0,
                                endRadius: max(size.width, size.height) * 0.8))
                for star in Self.stars {
                    let twinkle = (sin((time / 2.6 + star.phase) * 2 * .pi)
                                   + 1) / 2
                    let r = star.size * (0.7 + 0.3 * twinkle)
                    canvas.fill(Path(ellipseIn: CGRect(
                                    x: star.x * size.width - r / 2,
                                    y: star.y * size.height - r / 2,
                                    width: r, height: r)),
                                with: .color(.white.opacity(0.25
                                                            + 0.55 * twinkle)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
