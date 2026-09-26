import SwiftUI

/// Небо над узором главной: днём — мягкое свечение солнца, которое идёт
/// дугой от левого края к правому и теплеет к утру и вечеру, с медленно
/// плывущими лучами; ночью — синеватый свет луны и мерцающие звёзды.
/// Поверх узора, под карточками, и едва заметно: это погода, а не картинка.
struct DaySky: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var still

    /// Звёзд немного: небо над садом, а не планетарий.
    private static let stars = 26

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: still)) {
            context in
            Canvas { canvas, size in
                let hour = Sky.hour(context.date)
                let time = context.date.timeIntervalSinceReferenceDate
                if let along = Sky.sun(at: hour) {
                    sun(&canvas, size: size, along: along, hour: hour,
                        time: still ? 0 : time)
                } else {
                    night(&canvas, size: size, time: still ? 0 : time)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func colour(_ channels: Channels) -> Color {
        Color(red: channels.red / 255, green: channels.green / 255,
              blue: channels.blue / 255)
    }

    private func sun(_ canvas: inout GraphicsContext, size: CGSize,
                     along: Double, hour: Double, time: Double) {
        let light = colour(Sky.glow(at: hour))
        let x = size.width * CGFloat(0.06 + 0.88 * along)
        let y = size.height * CGFloat(0.12 - 0.1 * Sky.height(along))
        let middle = CGPoint(x: x, y: y)
        let reach = max(size.width, size.height) * 0.75
        let strength = scheme == .dark ? 0.14 : 0.24
        canvas.fill(
            Path(ellipseIn: CGRect(x: x - reach, y: y - reach,
                                   width: reach * 2, height: reach * 2)),
            with: .radialGradient(
                Gradient(colors: [light.opacity(strength),
                                  light.opacity(strength * 0.35),
                                  light.opacity(0)]),
                center: middle, startRadius: 0, endRadius: reach))
        // Лучи — широкими клиньями, еле видно, поворачиваются за минуту.
        var rays = canvas
        rays.opacity = scheme == .dark ? 0.05 : 0.08
        rays.translateBy(x: x, y: y)
        rays.rotate(by: .radians(time / 60 * 2 * .pi / 6))
        for index in 0 ..< 6 {
            let angle = Double(index) / 6 * 2 * .pi
            var wedge = Path()
            wedge.move(to: .zero)
            wedge.addLine(to: CGPoint(x: cos(angle - 0.07) * reach,
                                      y: sin(angle - 0.07) * reach))
            wedge.addLine(to: CGPoint(x: cos(angle + 0.07) * reach,
                                      y: sin(angle + 0.07) * reach))
            wedge.closeSubpath()
            rays.fill(wedge, with: .radialGradient(
                Gradient(colors: [light, light.opacity(0)]),
                center: .zero, startRadius: 0, endRadius: reach))
        }
    }

    private func night(_ canvas: inout GraphicsContext, size: CGSize,
                       time: Double) {
        let moon = colour(Sky.glow(at: 0))
        let middle = CGPoint(x: size.width * 0.82, y: size.height * 0.06)
        let reach = max(size.width, size.height) * 0.6
        canvas.fill(
            Path(ellipseIn: CGRect(x: middle.x - reach, y: middle.y - reach,
                                   width: reach * 2, height: reach * 2)),
            with: .radialGradient(
                Gradient(colors: [moon.opacity(scheme == .dark ? 0.16 : 0.14),
                                  moon.opacity(0)]),
                center: middle, startRadius: 0, endRadius: reach))
        // Звёзды — из номера, без случайных чисел: стоят на своих местах и
        // мерцают вразнобой.
        let ink: Color = scheme == .dark ? .white : moon
        for index in 0 ..< Self.stars {
            func unit(_ salt: Int) -> Double {
                let mixed = (index &* 2_654_435_761 &+ salt &* 97_531) & 0xFFFF
                return Double(mixed) / Double(0xFFFF)
            }
            let x = size.width * CGFloat(unit(1))
            let y = size.height * CGFloat(0.02 + 0.3 * unit(2))
            let twinkle = 0.5 + 0.5 * sin(time * (0.8 + unit(3) * 1.6)
                                          + unit(4) * 2 * .pi)
            let r = CGFloat(0.8 + unit(5) * 1.4)
            canvas.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                               width: r * 2, height: r * 2)),
                        with: .color(ink.opacity(0.15 + 0.45 * twinkle)))
        }
    }
}
