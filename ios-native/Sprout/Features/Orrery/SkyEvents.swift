import SwiftUI

/// Тихая картинка редких событий поверх звёзд: сияние у верхнего края,
/// комета наискосок, редкие метеоры. Едва заметно и не ловит касаний; при
/// «Уменьшить движение» не рисуется совсем — строка в «Небе сада»
/// остаётся.
struct SkyEvents: View {
    let kinds: Set<Rare.Kind>
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        if !still, !kinds.isEmpty {
            TimelineView(.animation(minimumInterval: Power.shared.calm
                                    ? 1.0 / 15 : 1.0 / 30)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { canvas, size in
                    if kinds.contains(.aurora) {
                        Self.aurora(&canvas, size: size, time: time)
                    }
                    if kinds.contains(.comet) {
                        Self.comet(&canvas, size: size, time: time)
                    }
                    if kinds.contains(.meteor) {
                        Self.meteors(&canvas, size: size, time: time)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Три мягкие ленты у верхнего края, плывущие вразнобой.
    private static func aurora(_ canvas: inout GraphicsContext, size: CGSize,
                               time: Double) {
        let w = Double(size.width)
        let h = Double(size.height)
        let tones: [Color] = [.mint, .teal, .green]
        for (index, tone) in tones.enumerated() {
            let shift = Double(index) * 1.7
            var band = Path()
            band.move(to: CGPoint(x: 0, y: 0))
            band.addLine(to: CGPoint(x: w, y: 0))
            let steps = 24
            for step in stride(from: steps, through: 0, by: -1) {
                let x = w * Double(step) / Double(steps)
                let wave = sin(x / w * 5 + time / 6 + shift)
                let y = h * (0.10 + 0.04 * Double(index) + 0.03 * wave)
                band.addLine(to: CGPoint(x: x, y: y))
            }
            band.closeSubpath()
            let breath = 0.5 + 0.5 * sin(time / 7 + shift)
            canvas.fill(band, with: .linearGradient(
                Gradient(colors: [tone.opacity(0.10 + 0.08 * breath),
                                  tone.opacity(0)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: h * 0.28)))
        }
    }

    /// Комета пролетает наискосок раз в десяток секунд.
    private static func comet(_ canvas: inout GraphicsContext, size: CGSize,
                              time: Double) {
        let phase = (time / 11).truncatingRemainder(dividingBy: 1)
        guard phase < 0.45 else { return }
        let t = phase / 0.45
        let w = Double(size.width)
        let h = Double(size.height)
        let head = CGPoint(x: w * (1.05 - 1.1 * t), y: h * (0.04 + 0.30 * t))
        let tail = CGPoint(x: head.x + w * 0.22, y: head.y - h * 0.07)
        var path = Path()
        path.move(to: head)
        path.addLine(to: tail)
        let fade = sin(t * .pi)
        canvas.stroke(path, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.7 * fade), Color.white.opacity(0)]),
            startPoint: head, endPoint: tail),
            style: StrokeStyle(lineWidth: 2, lineCap: .round))
        canvas.fill(Path(ellipseIn: CGRect(x: head.x - 2.5, y: head.y - 2.5,
                                           width: 5, height: 5)),
                    with: .color(.white.opacity(0.85 * fade)))
    }

    /// Несколько коротких штрихов, падающих в разное время.
    private static func meteors(_ canvas: inout GraphicsContext, size: CGSize,
                                time: Double) {
        for index in 0 ..< 5 {
            let period = 5.0 + Double(index)
            let phase = (time / period + Double(index) * 0.37)
                .truncatingRemainder(dividingBy: 1)
            guard phase < 0.12 else { continue }
            let t = phase / 0.12
            let w = Double(size.width)
            let h = Double(size.height)
            let startX = w * (0.15 + 0.18 * Double(index))
            let head = CGPoint(x: startX - w * 0.18 * t,
                               y: h * (0.05 + 0.12 * t)
                                   + h * 0.05 * Double(index % 3))
            let tail = CGPoint(x: head.x + w * 0.08, y: head.y - h * 0.03)
            var path = Path()
            path.move(to: head)
            path.addLine(to: tail)
            canvas.stroke(path, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.6 * sin(t * .pi)),
                                  .white.opacity(0)]),
                startPoint: head, endPoint: tail),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}
