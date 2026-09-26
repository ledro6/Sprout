import SwiftUI

/// Оранжерея садовника: стеклянный домик, в котором с уровнем прибавляется
/// жизни, см. `Gardener.Glasshouse`. Холстом: десяток растений из вью
/// стоил бы дороже. Качаются листья и порхают бабочки только там, где
/// оранжерея крупно, — на карточке дня она стоит тихо и заряд не ест.
struct GlasshouseView: View {
    let house: Gardener.Glasshouse
    var animated = false

    @Environment(\.accessibilityReduceMotion) private var still
    @Environment(\.colorScheme) private var scheme

    /// Ширина к высоте.
    static let aspect = 1.4

    var body: some View {
        // Бережём заряд — оранжерея стоит, как на карточке. См. `Power`.
        let moving = animated && !still && !Power.shared.calm
        TimelineView(.animation(minimumInterval: 1.0 / 30,
                                paused: !moving)) { frame in
            let time = moving ? frame.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, size in
                draw(into: &context, size: size, time: time)
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: - Рисунок

    private var dark: Bool { scheme == .dark }

    /// 0…1 по номеру и соли — без случайных чисел кадр от кадра не мигал бы.
    private func unit(_ index: Int, _ salt: Int) -> Double {
        let mixed = (index &* 2_654_435_761 &+ salt &* 40_503) & 0xFFFF
        return Double(mixed) / Double(0xFFFF)
    }

    private func draw(into context: inout GraphicsContext, size: CGSize,
                      time: Double) {
        let width = size.width
        let height = size.height
        let floor = height * 0.88
        let left = width * 0.08
        let right = width * 0.92
        let eaves = height * 0.4
        let ridge = height * 0.08
        let line = max(width / 140, 0.8)

        // Земля под домиком.
        let ground = Path(roundedRect: CGRect(x: left - width * 0.04, y: floor,
                                              width: right - left + width * 0.08,
                                              height: height * 0.07),
                          cornerRadius: height * 0.035)
        context.fill(ground, with: .color(Color(red: 0.52, green: 0.36,
                                                blue: 0.24).opacity(0.85)))

        // Стекло: стены и двускатная крыша.
        var glass = Path()
        glass.move(to: CGPoint(x: left, y: floor))
        glass.addLine(to: CGPoint(x: left, y: eaves))
        glass.addLine(to: CGPoint(x: width / 2, y: ridge))
        glass.addLine(to: CGPoint(x: right, y: eaves))
        glass.addLine(to: CGPoint(x: right, y: floor))
        glass.closeSubpath()
        context.fill(glass, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.72, green: 0.88, blue: 1).opacity(dark ? 0.16 : 0.42),
                Color(red: 0.86, green: 0.96, blue: 0.9).opacity(dark ? 0.08 : 0.28),
            ]),
            startPoint: CGPoint(x: width / 2, y: ridge),
            endPoint: CGPoint(x: width / 2, y: floor)))

        if house.lights { garland(into: &context, width: width, left: left,
                                  right: right, eaves: eaves, ridge: ridge,
                                  time: time) }

        // Горшки с растениями — от края до края, поровну.
        let inner = (right - left) * 0.86
        let slot = inner / CGFloat(max(house.pots, 1))
        let pot = min(slot * 0.62, width * 0.1)
        let start = width / 2 - inner / 2 + slot / 2
        func roof(_ x: CGFloat) -> CGFloat {
            eaves - (eaves - ridge) * (1 - abs(x - width / 2) / (width / 2 - left))
        }
        // Листья — от ширины оранжереи, а не от горшка: в тесноте горшки
        // мельчают, а растения не должны превращаться в палочки.
        let leaf = max(pot, width * 0.075)
        for index in 0 ..< house.pots {
            let x = start + slot * CGFloat(index)
            // Вверх — до ската крыши над горшком, с зазором.
            plant(index, at: x, floor: floor, pot: pot,
                  room: floor - pot * 0.8 - roof(x) - height * 0.07,
                  leaf: leaf, time: time, into: &context)
        }

        // Рамы — поверх растений, как стекло.
        let frame = Color(white: dark ? 0.78 : 0.5).opacity(0.9)
        context.stroke(glass, with: .color(frame),
                       style: StrokeStyle(lineWidth: line * 1.4,
                                          lineJoin: .round))
        var ribs = Path()
        for step in 1 ... 3 {
            let x = left + (right - left) * CGFloat(step) / 4
            ribs.move(to: CGPoint(x: x, y: roof(x)))
            ribs.addLine(to: CGPoint(x: x, y: floor))
        }
        ribs.move(to: CGPoint(x: left, y: eaves))
        ribs.addLine(to: CGPoint(x: right, y: eaves))
        context.stroke(ribs, with: .color(frame.opacity(0.55)),
                       lineWidth: line)

        for index in 0 ..< house.butterflies {
            butterfly(index, width: width, height: height, time: time,
                      into: &context)
        }
    }

    private func plant(_ index: Int, at x: CGFloat, floor: CGFloat,
                       pot: CGFloat, room: CGFloat, leaf: CGFloat, time: Double,
                       into context: inout GraphicsContext) {
        // Горшок — терракота, сужается к донцу.
        let top = floor - pot * 0.8
        var body = Path()
        body.move(to: CGPoint(x: x - pot / 2, y: top))
        body.addLine(to: CGPoint(x: x + pot / 2, y: top))
        body.addLine(to: CGPoint(x: x + pot * 0.36, y: floor))
        body.addLine(to: CGPoint(x: x - pot * 0.36, y: floor))
        body.closeSubpath()
        context.fill(body, with: .color(Color(red: 0.8, green: 0.45,
                                              blue: 0.3)))
        context.fill(Path(roundedRect: CGRect(x: x - pot * 0.56,
                                              y: top - pot * 0.14,
                                              width: pot * 1.12,
                                              height: pot * 0.2),
                          cornerRadius: pot * 0.06),
                     with: .color(Color(red: 0.86, green: 0.52, blue: 0.36)))

        // Растение растёт из земли в горшке и качается от основания.
        let tall = room * CGFloat(house.growth) * (0.72 + 0.28 * unit(index, 1))
        let sway = sin(time * 1.3 + Double(index) * 1.7) * 0.04
        var sprout = context
        sprout.translateBy(x: x, y: top - pot * 0.06)
        sprout.rotate(by: .radians(sway))
        let tone = (red: 0.18 + 0.12 * unit(index, 2),
                    green: 0.52 + 0.16 * unit(index, 3),
                    blue: 0.26 + 0.06 * unit(index, 9))
        let green = Color(red: tone.red, green: tone.green, blue: tone.blue)
        let shade = Color(red: tone.red * 0.78, green: tone.green * 0.78,
                          blue: tone.blue * 0.78)
        let petal = [
            Color(red: 1, green: 0.55, blue: 0.7),
            Color(red: 1, green: 0.82, blue: 0.3),
            Color(red: 0.7, green: 0.55, blue: 1),
            Color(red: 1, green: 0.96, blue: 0.9),
        ][index % 4]
        switch index % 4 {
        case 0: stem(index, tall: tall, leaf: leaf, green: green,
                     petal: petal, time: time, into: &sprout)
        case 1: bush(tall: tall * 0.6, leaf: leaf, green: green, shade: shade,
                     petal: petal, time: time, into: &sprout)
        case 2: fronds(index, tall: tall * 0.85, leaf: leaf, green: green,
                       into: &sprout)
        default: cactus(tall: tall * 0.5, leaf: leaf, time: time,
                        into: &sprout)
        }
    }

    /// Лист — вытянутый овал от черешка наружу.
    private func blade(at point: CGPoint, angle: Double, length: CGFloat,
                       colour: Color, into context: inout GraphicsContext) {
        var piece = context
        piece.translateBy(x: point.x, y: point.y)
        piece.rotate(by: .radians(angle))
        piece.fill(Path(ellipseIn: CGRect(x: 0, y: -length * 0.19,
                                          width: length,
                                          height: length * 0.38)),
                   with: .color(colour))
    }

    /// Стебель с листьями вразнобой и цветком на макушке.
    private func stem(_ index: Int, tall: CGFloat, leaf: CGFloat, green: Color,
                      petal: Color, time: Double,
                      into context: inout GraphicsContext) {
        var line = Path()
        line.move(to: .zero)
        line.addQuadCurve(to: CGPoint(x: 0, y: -tall),
                          control: CGPoint(x: leaf * 0.2, y: -tall / 2))
        context.stroke(line, with: .color(green),
                       style: StrokeStyle(lineWidth: max(leaf * 0.09, 0.8),
                                          lineCap: .round))
        let count = 3 + Int(house.growth * 4)
        for step in 0 ..< count {
            let along = CGFloat(step + 1) / CGFloat(count + 1)
            let side: Double = step.isMultiple(of: 2) ? -1 : 1
            // Влево — угол от π: овал рисуется от черешка вправо.
            let tilt = 0.55 + 0.25 * Double(along)
            blade(at: CGPoint(x: leaf * 0.1 * along, y: -tall * along),
                  angle: side < 0 ? .pi + tilt : -tilt,
                  length: leaf * (0.62 + 0.3 * CGFloat(unit(index, step + 4)))
                      * (1.1 - along * 0.4),
                  colour: green.opacity(0.94), into: &context)
        }
        if house.blooms {
            flower(at: CGPoint(x: 0, y: -tall), radius: leaf * 0.15,
                   colour: petal, time: time, into: &context)
        }
    }

    /// Куст — купол из листьев, в цвету — с огоньками цветков. Растёт
    /// вширь, а не ввысь: выше полутора листьев куст стал бы шаром.
    private func bush(tall: CGFloat, leaf: CGFloat, green: Color, shade: Color,
                      petal: Color, time: Double,
                      into context: inout GraphicsContext) {
        let height = min(max(tall, leaf * 0.8), leaf * 1.5)
        let middle = CGPoint(x: 0, y: -height * 0.5)
        context.fill(Path(ellipseIn: CGRect(x: -height * 0.42,
                                            y: -height * 0.9,
                                            width: height * 0.84,
                                            height: height * 0.9)),
                     with: .color(shade))
        let count = 6 + Int(house.growth * 6)
        for step in 0 ..< count {
            let angle = -.pi * (0.08 + 0.84 * Double(step) / Double(count - 1))
            let reach = height * 0.28
            let point = CGPoint(x: middle.x + CGFloat(cos(angle)) * reach,
                                y: middle.y + CGFloat(sin(angle)) * reach)
            blade(at: point, angle: angle, length: leaf * 0.6,
                  colour: green, into: &context)
        }
        guard house.blooms else { return }
        for step in 0 ..< 3 {
            let angle = -.pi * (0.25 + 0.25 * Double(step))
            flower(at: CGPoint(x: CGFloat(cos(angle)) * height * 0.36,
                               y: -height * 0.5 + CGFloat(sin(angle)) * height * 0.36),
                   radius: leaf * 0.09, colour: petal, time: time,
                   into: &context)
        }
    }

    /// Веер длинных листьев, как у папоротника или пальмы.
    private func fronds(_ index: Int, tall: CGFloat, leaf: CGFloat,
                        green: Color, into context: inout GraphicsContext) {
        let count = 4 + Int(house.growth * 3)
        for step in 0 ..< count {
            let spread = Double(step) / Double(count - 1) * 2 - 1
            let angle = spread * 1.05
            let reach = tall * (0.75 + 0.25 * CGFloat(1 - abs(spread)))
            let end = CGPoint(x: CGFloat(sin(angle)) * reach * 0.75,
                              y: -CGFloat(cos(angle)) * reach)
            var frond = Path()
            frond.move(to: .zero)
            frond.addQuadCurve(to: end, control: CGPoint(x: end.x * 0.35,
                                                         y: -reach * 1.05))
            context.stroke(frond, with: .color(green),
                           style: StrokeStyle(lineWidth: max(leaf * 0.2, 1),
                                              lineCap: .round))
        }
    }

    /// Кактус — столбик с рёбрами и рукой сбоку; в цвету — розовый цветок.
    private func cactus(tall: CGFloat, leaf: CGFloat, time: Double,
                        into context: inout GraphicsContext) {
        let width = leaf * 0.5
        let height = max(tall, width * 1.4)
        let flesh = Color(red: 0.3, green: 0.62, blue: 0.42)
        context.fill(Path(roundedRect: CGRect(x: -width / 2, y: -height,
                                              width: width, height: height),
                          cornerRadius: width / 2),
                     with: .color(flesh))
        if house.growth > 0.55 {
            let arm = width * 0.62
            var elbow = Path()
            elbow.move(to: CGPoint(x: width * 0.3, y: -height * 0.45))
            elbow.addLine(to: CGPoint(x: width * 0.9, y: -height * 0.45))
            elbow.addLine(to: CGPoint(x: width * 0.9, y: -height * 0.72))
            context.stroke(elbow, with: .color(flesh),
                           style: StrokeStyle(lineWidth: arm, lineCap: .round,
                                              lineJoin: .round))
        }
        var ribs = Path()
        for offset in [-0.18, 0.18] {
            ribs.move(to: CGPoint(x: width * offset, y: -height + width * 0.4))
            ribs.addLine(to: CGPoint(x: width * offset, y: -width * 0.2))
        }
        context.stroke(ribs, with: .color(.white.opacity(0.28)),
                       lineWidth: max(width * 0.07, 0.6))
        if house.blooms {
            flower(at: CGPoint(x: 0, y: -height), radius: leaf * 0.12,
                   colour: Color(red: 1, green: 0.45, blue: 0.62), time: time,
                   into: &context)
        }
    }

    /// Пять лепестков и серединка.
    private func flower(at center: CGPoint, radius: CGFloat, colour: Color,
                        time: Double, into context: inout GraphicsContext) {
        for step in 0 ..< 5 {
            let angle = Double(step) / 5 * 2 * .pi + time * 0.2
            let spot = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                               y: center.y + CGFloat(sin(angle)) * radius)
            context.fill(Path(ellipseIn: CGRect(x: spot.x - radius,
                                                y: spot.y - radius,
                                                width: radius * 2,
                                                height: radius * 2)),
                         with: .color(colour))
        }
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.7,
                                            y: center.y - radius * 0.7,
                                            width: radius * 1.4,
                                            height: radius * 1.4)),
                     with: .color(Color(red: 1, green: 0.78, blue: 0.2)))
    }

    /// Бабочка: верхние крылья больше нижних, складываются и раскрываются;
    /// летает под крышей.
    private func butterfly(_ index: Int, width: CGFloat, height: CGFloat,
                           time: Double, into context: inout GraphicsContext) {
        let phase = Double(index) * 2.1
        let x = width * CGFloat(0.5 + 0.28 * sin(time * 0.35 + phase))
        let y = height * CGFloat(0.3 + 0.07 * sin(time * 0.9 + phase * 1.3)
                                 + 0.08 * Double(index % 2))
        let flap = time == 0 ? 0.85 : abs(sin(time * 7 + phase)) * 0.75 + 0.25
        let span = width * 0.028
        let colour = [
            Color(red: 1, green: 0.62, blue: 0.2),
            Color(red: 0.45, green: 0.6, blue: 1),
            Color(red: 1, green: 0.45, blue: 0.62),
        ][index % 3]
        var piece = context
        piece.translateBy(x: x, y: y)
        piece.rotate(by: .radians(sin(time * 0.8 + phase) * 0.25))
        piece.scaleBy(x: CGFloat(flap), y: 1)
        for side: CGFloat in [-1, 1] {
            piece.fill(Path(ellipseIn: CGRect(x: side < 0 ? -span * 1.1 : span * 0.05,
                                              y: -span * 1.05, width: span * 1.05,
                                              height: span * 0.95)),
                       with: .color(colour))
            piece.fill(Path(ellipseIn: CGRect(x: side < 0 ? -span * 0.8 : span * 0.05,
                                              y: -span * 0.05, width: span * 0.75,
                                              height: span * 0.7)),
                       with: .color(colour.opacity(0.85)))
        }
        piece.fill(Path(roundedRect: CGRect(x: -span * 0.08, y: -span * 0.8,
                                            width: span * 0.16,
                                            height: span * 1.4),
                        cornerRadius: span * 0.08),
                   with: .color(Color(white: 0.2)))
    }

    /// Гирлянда под скатами крыши: провод провисает между огоньками, те
    /// мерцают по очереди.
    private func garland(into context: inout GraphicsContext, width: CGFloat,
                         left: CGFloat, right: CGFloat, eaves: CGFloat,
                         ridge: CGFloat, time: Double) {
        let count = 11
        let drop = (eaves - ridge) * 0.2
        let bulbs = (0 ..< count).map { index -> CGPoint in
            let along = CGFloat(index) / CGFloat(count - 1)
            let x = left + (right - left) * (0.04 + 0.92 * along)
            let roof = eaves - (eaves - ridge) * (1 - abs(x - width / 2)
                                                  / (width / 2 - left))
            return CGPoint(x: x, y: roof + drop)
        }
        var wire = Path()
        wire.move(to: bulbs[0])
        for (from, to) in zip(bulbs, bulbs.dropFirst()) {
            wire.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2,
                                                       y: max(from.y, to.y)
                                                           + drop * 0.35))
        }
        context.stroke(wire, with: .color(Color(white: dark ? 0.7 : 0.45)
                                            .opacity(0.6)),
                       lineWidth: max(width / 400, 0.5))
        let radius = width * 0.008
        for (index, bulb) in bulbs.enumerated() {
            let glow = time == 0 ? 0.9
                : 0.55 + 0.45 * sin(time * 2.4 + Double(index) * 0.9)
            var halo = context
            halo.opacity = glow * (dark ? 0.4 : 0.22)
            halo.fill(Path(ellipseIn: CGRect(x: bulb.x - radius * 2,
                                             y: bulb.y - radius * 1.2,
                                             width: radius * 4,
                                             height: radius * 4)),
                      with: .color(Color(red: 1, green: 0.85, blue: 0.45)))
            var light = context
            light.opacity = glow
            light.fill(Path(ellipseIn: CGRect(x: bulb.x - radius,
                                              y: bulb.y,
                                              width: radius * 2,
                                              height: radius * 2)),
                       with: .color(Color(red: 1, green: 0.8, blue: 0.3)))
        }
    }
}
