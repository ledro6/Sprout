import SwiftUI

/// Фоновый узор: чередование ростка и капли.
///
/// Контуры не нарисованы на глаз — это те же кривые, что в макете. Figma
/// отдаёт их в fillGeometry при запросе с geometry=paths, отсюда и взяты.
enum SproutShapes {
    static let leafSize = CGSize(width: 50.2067, height: 42.2327)
    static let dropSize = CGSize(width: 30.4193, height: 42.2327)

    /// Росток: два листа, сходящихся к общей точке внизу.
    static var leaf: Path {
        var p = Path()
        p.move(to: CGPoint(x: 50.2067, y: 0))
        p.addCurve(to: CGPoint(x: 25.1033, y: 42.2327),
                   control1: CGPoint(x: 50.2067, y: 16.0251),
                   control2: CGPoint(x: 38.9675, y: 42.2327))
        p.addCurve(to: CGPoint(x: 0, y: 0),
                   control1: CGPoint(x: 11.2391, y: 42.2327),
                   control2: CGPoint(x: 0, y: 16.0251))
        p.addCurve(to: CGPoint(x: 25.1033, y: 31.4466),
                   control1: CGPoint(x: 25.1033, y: 0),
                   control2: CGPoint(x: 11.2391, y: 31.4466))
        p.addCurve(to: CGPoint(x: 50.2067, y: 0),
                   control1: CGPoint(x: 38.9675, y: 31.4466),
                   control2: CGPoint(x: 25.1033, y: 0))
        p.closeSubpath()
        return p
    }

    /// Капля.
    static var drop: Path {
        var p = Path()
        p.move(to: CGPoint(x: 30.4193, y: 27.0336))
        p.addCurve(to: CGPoint(x: 15.2097, y: 42.2327),
                   control1: CGPoint(x: 30.4193, y: 35.4278),
                   control2: CGPoint(x: 23.6097, y: 42.2327))
        p.addCurve(to: CGPoint(x: 0, y: 27.0336),
                   control1: CGPoint(x: 6.8096, y: 42.2327),
                   control2: CGPoint(x: 0, y: 35.4278))
        p.addCurve(to: CGPoint(x: 15.2097, y: 0),
                   control1: CGPoint(x: 0, y: 18.6393),
                   control2: CGPoint(x: 14.513, y: 0))
        p.addCurve(to: CGPoint(x: 30.4193, y: 27.0336),
                   control1: CGPoint(x: 15.9063, y: 0),
                   control2: CGPoint(x: 30.4193, y: 18.6393))
        p.closeSubpath()
        return p
    }
}

/// Фон экрана: узор и две белые растяжки поверх него.
///
/// Растяжки взяты из макета один в один: сплошной белый до 40% высоты
/// полосы, дальше сход в прозрачность. Благодаря им заголовок вверху и
/// панель внизу читаются, а узор не спорит с текстом.
struct SproutBackground: View {
    /// Шаг сетки из макета: ростки через 89.4 pt, капля посередине между
    /// ними, ряды через 46.7 pt.
    private let pitchX: CGFloat = 89.4
    private let pitchY: CGFloat = 46.68
    private let dropOffsetX: CGFloat = 55

    var body: some View {
        ZStack {
            Palette.background

            Canvas { context, size in
                let paint = GraphicsContext.Shading.color(Palette.pattern)
                var y = -pitchY
                while y < size.height + pitchY {
                    var x = -pitchX
                    while x < size.width + pitchX {
                        context.fill(
                            SproutShapes.leaf.offsetBy(dx: x, dy: y), with: paint)
                        context.fill(
                            SproutShapes.drop.offsetBy(dx: x + dropOffsetX, dy: y),
                            with: paint)
                        x += pitchX
                    }
                    y += pitchY
                }
            }

            VStack {
                wash(fadingDown: true)
                Spacer(minLength: 0)
                wash(fadingDown: false)
            }
        }
        .ignoresSafeArea()
    }

    /// Полоса, гасящая узор у края экрана.
    ///
    /// Верхняя уходит в прозрачность вниз, нижняя — вверх. Направление
    /// важно: одинаковое для обеих давало у нижней сплошной белый сверху
    /// и обрыв посреди экрана вместо мягкого схода к панели.
    private func wash(fadingDown: Bool) -> some View {
        let solid = Palette.background
        let clear = Palette.background.opacity(0)
        let stops: [Gradient.Stop] = fadingDown
            ? [
                .init(color: solid, location: 0),
                .init(color: solid, location: Metrics.washStop),
                .init(color: clear, location: 1),
            ]
            : [
                .init(color: clear, location: 0),
                .init(color: solid, location: 1 - Metrics.washStop),
                .init(color: solid, location: 1),
            ]
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
            .frame(height: Metrics.washHeight)
    }
}

/// Логотип Sprout: росток контуром и две капли воды.
struct SproutLogo: View {
    var height: CGFloat = 21

    var body: some View {
        Canvas { context, size in
            let scale = size.height / (SproutShapes.leafSize.height * 1.35)
            var leaf = SproutShapes.leaf
            leaf = leaf.applying(CGAffineTransform(scaleX: scale, y: scale))
            context.stroke(
                leaf,
                with: .color(Palette.green),
                style: StrokeStyle(lineWidth: 3.4, lineJoin: .round))

            let dropScale = size.height / SproutShapes.dropSize.height
            let big = SproutShapes.drop
                .applying(CGAffineTransform(scaleX: dropScale * 0.16,
                                            y: dropScale * 0.16))
                .offsetBy(dx: size.width * 0.52, dy: 0)
            context.fill(big, with: .color(Palette.water))

            let small = SproutShapes.drop
                .applying(CGAffineTransform(scaleX: dropScale * 0.10,
                                            y: dropScale * 0.10))
                .offsetBy(dx: 0, dy: size.height * 0.24)
            context.fill(small, with: .color(Palette.water))
        }
        .frame(width: height * 13 / 21, height: height)
    }
}
