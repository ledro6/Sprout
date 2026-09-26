import SwiftUI

/// Рисунок планетария: орбиты, ворота, следы, вспышки, солнце и планеты.
/// Холстом, а не вью: планет десятки, и двигаются они каждый кадр.
struct OrreryDial: View {
    let planets: [Orrery.Planet]
    var flashes: [Orrery.Flash] = []
    var picked: Plant.ID?
    var beat: Double = 0
    /// На обзоре — мелко и без подписей.
    var small = false

    /// Где планета в рамке размера `size` — общая мерка для рисунка и
    /// нажатий.
    static func point(_ planet: Orrery.Planet, in size: CGSize,
                      small: Bool = false) -> CGPoint {
        spot(radius: planet.radius, angle: planet.angle, in: size,
             small: small)
    }

    private static func reach(_ size: CGSize, small: Bool) -> CGFloat {
        min(size.width, size.height) / 2 - (small ? 5 : 16)
    }

    private static func spot(radius: Double, angle: Double, in size: CGSize,
                             small: Bool) -> CGPoint {
        let full = reach(size, small: small) * CGFloat(radius)
        return CGPoint(x: size.width / 2 + full * CGFloat(sin(angle)),
                       y: size.height / 2 - full * CGFloat(cos(angle)))
    }

    var body: some View {
        Canvas { context, size in
            let middle = CGPoint(x: size.width / 2, y: size.height / 2)
            let full = Self.reach(size, small: small)
            let sun = small ? Metrics.sun * 0.45 : Metrics.sun

            // Орбиты — тонкими кругами, выбранная — ярче.
            for planet in planets {
                let r = full * CGFloat(planet.radius)
                let lit = planet.id == picked
                context.stroke(
                    Path(ellipseIn: CGRect(x: middle.x - r, y: middle.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(lit ? 0.4 : 0.1)),
                    lineWidth: lit ? 1.4 : 0.6)
            }

            // Ворота: сектор и луч от солнца вверх.
            var wedge = Path()
            wedge.move(to: middle)
            for step in 0 ... 12 {
                let angle = -Orrery.gate + 2 * Orrery.gate * Double(step) / 12
                wedge.addLine(to: CGPoint(
                    x: middle.x + (full + 8) * CGFloat(sin(angle)),
                    y: middle.y - (full + 8) * CGFloat(cos(angle))))
            }
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Palette.water.opacity(0.1)))
            var beam = Path()
            beam.move(to: CGPoint(x: middle.x, y: middle.y - sun / 2))
            beam.addLine(to: CGPoint(x: middle.x, y: middle.y - full - 6))
            context.stroke(beam, with: .linearGradient(
                Gradient(colors: [Palette.water.opacity(0.9),
                                  Palette.water.opacity(0.15)]),
                startPoint: middle,
                endPoint: CGPoint(x: middle.x, y: middle.y - full)),
                style: StrokeStyle(lineWidth: small ? 1.5 : 2.5,
                                   lineCap: .round))

            // Следы — пройденная от луча часть круга: чем длиннее, тем суше.
            for planet in planets {
                let travelled = planet.angle
                let steps = max(Int(travelled / (2 * .pi) * 72), 1)
                var trail = Path()
                for step in 0 ... steps {
                    let angle = travelled * Double(step) / Double(steps)
                    let at = Self.spot(radius: planet.radius, angle: angle,
                                       in: size, small: small)
                    if step == 0 { trail.move(to: at) } else {
                        trail.addLine(to: at)
                    }
                }
                context.stroke(trail,
                               with: .color(Palette.level(planet.moisture)
                                   .opacity(0.3)),
                               style: StrokeStyle(lineWidth: small ? 1.2 : 2,
                                                  lineCap: .round))
            }

            // Вспышки полива у ворот.
            for flash in flashes {
                let at = Self.spot(radius: flash.radius, angle: 0, in: size,
                                   small: small)
                let r = 5 + (1 - flash.strength) * 18
                context.stroke(
                    Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(Palette.water.opacity(flash.strength)),
                    lineWidth: 2)
            }

            // Солнце — источник воды.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: sun / 3))
                layer.fill(Path(ellipseIn: CGRect(x: middle.x - sun * 0.7,
                                                  y: middle.y - sun * 0.7,
                                                  width: sun * 1.4,
                                                  height: sun * 1.4)),
                           with: .color(Palette.water.opacity(0.55)))
            }
            context.fill(Path(ellipseIn: CGRect(x: middle.x - sun / 2,
                                                y: middle.y - sun / 2,
                                                width: sun, height: sun)),
                         with: .radialGradient(
                             Gradient(colors: [.white, Palette.water]),
                             center: middle, startRadius: 0,
                             endRadius: sun / 2))
            var drop = context.resolve(Image(systemName: "drop.fill"))
            drop.shading = .color(Palette.space.opacity(0.8))
            let glyph = sun * 0.42
            context.draw(drop, in: CGRect(x: middle.x - glyph / 2,
                                          y: middle.y - glyph * 0.6,
                                          width: glyph, height: glyph * 1.2))

            // Свечение планет — одним слоем: размытие на каждую дорого.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: small ? 2 : 5))
                for planet in planets {
                    let at = Self.point(planet, in: size, small: small)
                    let r = diameter(of: planet) * 0.9
                    layer.fill(Path(ellipseIn: CGRect(x: at.x - r,
                                                      y: at.y - r,
                                                      width: r * 2,
                                                      height: r * 2)),
                               with: .color(Palette.level(planet.moisture)
                                   .opacity(0.8)))
                }
            }
            for planet in planets {
                let at = Self.point(planet, in: size, small: small)
                let r = diameter(of: planet) / 2
                let disc = Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r,
                                                  width: r * 2, height: r * 2))
                // Шар, а не кружок: светлая сторона смотрит на солнце, по
                // другой — ночь.
                let tone = Palette.level(planet.moisture)
                let away = CGVector(dx: middle.x - at.x, dy: middle.y - at.y)
                let length = max(hypot(away.dx, away.dy), 1)
                let lit = CGPoint(x: at.x + away.dx / length * r * 0.45,
                                  y: at.y + away.dy / length * r * 0.45)
                context.fill(disc, with: .radialGradient(
                    Gradient(colors: [tone.mix(with: .white, by: 0.5), tone,
                                      tone.mix(with: .black, by: 0.55)]),
                    center: lit, startRadius: 0, endRadius: r * 1.7))
                if planet.id == picked {
                    context.stroke(disc, with: .color(.white), lineWidth: 2)
                    let name = context.resolve(
                        Text(planet.name)
                            .font(Typography.cardCaption.weight(.semibold))
                            .foregroundStyle(.white))
                    let right = at.x < size.width * 0.7
                    context.draw(name,
                                 at: CGPoint(x: at.x + (right ? r + 6 : -r - 6),
                                             y: at.y),
                                 anchor: right ? .leading : .trailing)
                }
            }
        }
    }

    /// Выбранная — крупнее; сухие дышат.
    private func diameter(of planet: Orrery.Planet) -> CGFloat {
        let base = planet.id == picked ? Metrics.planetPicked : Metrics.planet
        let scaled = small ? base * 0.62 : base
        guard Thirst(moisture: planet.moisture) == .alarm else { return scaled }
        return scaled * (1 + 0.3 * CGFloat(beat))
    }
}
