import Observation
import SwiftUI

/// Фоновый узор: чередование ростка и капли.
///
/// Контуры не нарисованы на глаз — это те же кривые, что в макете. Figma
/// отдаёт их в fillGeometry при запросе с geometry=paths, отсюда и взяты.
enum SproutShapes {
    /// Росток: два листа, сходящихся к общей точке внизу.
    ///
    /// Хранимое, а не вычисляемое: узор обращается к нему сотни раз за
    /// кадр, и каждое обращение собирало бы контур заново.
    static let leaf: Path = {
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
    }()

    /// Коробка, в которой нарисован логотип в макете: группа «лого»,
    /// 74.92 × 137.51. Все точки ниже — в ней.
    static let logoBox = CGSize(width: 74.9208, height: 137.5099)

    /// Толщина обводки листьев в той же коробке.
    static let logoStroke: CGFloat = 7.4455

    /// Ломаная по точкам: замкнутая — лист, открытая — стебель.
    private static func line(_ points: [CGPoint], closed: Bool) -> Path {
        var p = Path()
        p.addLines(points)
        if closed { p.closeSubpath() }
        return p
    }

    /// Листья логотипа. В макете это не кривые, а ломаные: Figma отдаёт
    /// их в vectorNetwork прямыми сегментами, обведёнными зелёным.
    static let logoLeaves: [Path] = [
        // Левый лист и его стебель.
        line([CGPoint(x: 24.8960, y: 70.2674),
              CGPoint(x: 0, y: 49.3268),
              CGPoint(x: 0, y: 85.8565),
              CGPoint(x: 24.8960, y: 108.8912)], closed: true),
        line([CGPoint(x: 24.8960, y: 123.5496),
              CGPoint(x: 24.8960, y: 108.8912)], closed: false),
        // Правый, самый крупный, с длинным стеблем.
        line([CGPoint(x: 37.6930, y: 63.5198),
              CGPoint(x: 37.6930, y: 115.4059),
              CGPoint(x: 74.9207, y: 85.6238),
              CGPoint(x: 74.9207, y: 32.1089)], closed: true),
        line([CGPoint(x: 37.6930, y: 115.4059),
              CGPoint(x: 37.6930, y: 137.5099)], closed: false),
        // Верхний, самый мелкий.
        line([CGPoint(x: 39.7870, y: 13.9604),
              CGPoint(x: 23.4999, y: 27.2228),
              CGPoint(x: 23.4999, y: 50.0248),
              CGPoint(x: 26.9900, y: 54.2129),
              CGPoint(x: 39.7870, y: 43.2772)], closed: true),
    ]

    /// Две капли воды: заливка, без обводки.
    static let logoDrops: [Path] = [
        line([CGPoint(x: 2.0941, y: 39.9268),
              CGPoint(x: 8.6090, y: 26.5248),
              CGPoint(x: 15.5891, y: 39.9268),
              CGPoint(x: 8.6090, y: 46.0694)], closed: true),
        line([CGPoint(x: 47.6980, y: 23.2939),
              CGPoint(x: 59.1552, y: 0),
              CGPoint(x: 71.4307, y: 23.2939),
              CGPoint(x: 59.1552, y: 33.9703)], closed: true),
    ]

    /// Капля.
    static let drop: Path = {
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
    }()
}

/// Узор фона — отдельной вью, а не куском фона.
///
/// Сдвиг параллакса меняется каждый кадр, и тело фона пересобирается
/// вместе с ним. У этой вью своих свойств нет, поэтому при пересборке
/// SwiftUI видит её прежней и тела не трогает: холст не перерисовывается,
/// а только съезжает. Иначе на каждый кадр наклона заново собирался бы
/// контур из полутора сотен ростков.
///
/// Тему при этом вью читает явно. Холст рисуется замыканием, и снаружи не
/// видно, что цвет узора зависит от темы; без этой зависимости вью так и
/// осталась бы «прежней» при переключении темы и не перерисовалась бы.
private struct SproutPattern: View {
    @Environment(\.colorScheme) private var scheme

    /// Шаг сетки из макета: ростки через 89.4 pt, капля посередине между
    /// ними, ряды через 46.7 pt.
    private let pitchX: CGFloat = 89.4
    private let pitchY: CGFloat = 46.68
    private let dropOffsetX: CGFloat = 55

    var body: some View {
        Canvas { context, size in
            context.fill(pattern(covering: size),
                         with: .color(Palette.pattern))
        }
        .id(scheme)
    }

    /// Весь узор одним контуром.
    ///
    /// Раньше здесь было по команде заливки на каждый росток и каплю —
    /// под три сотни отдельных вызовов на кадр. Собранные в один контур,
    /// они уходят одной: рисуется столько же, а команд в двести раз
    /// меньше.
    private func pattern(covering size: CGSize) -> Path {
        var path = Path()
        var y = -pitchY
        while y < size.height + pitchY {
            var x = -pitchX
            while x < size.width + pitchX {
                path.addPath(SproutShapes.leaf,
                             transform: .init(translationX: x, y: y))
                path.addPath(SproutShapes.drop,
                             transform: .init(translationX: x + dropOffsetX,
                                              y: y))
                x += pitchX
            }
            y += pitchY
        }
        return path
    }
}

/// Повод порадоваться: растение полили.
///
/// Один на приложение и без данных — только счётчик поводов. Узор на
/// фоне подписан на него и вздрагивает; кто, где и что полил, ему знать
/// незачем, а поливают с двух экранов и из двух меню.
@Observable
final class Cheer {
    static let shared = Cheer()

    private(set) var beat = 0

    private init() {}

    func now() { beat += 1 }
}

/// Фон экрана: узор и две белые растяжки поверх него.
///
/// Растяжки взяты из макета один в один: сплошной белый до 40% высоты
/// полосы, дальше сход в прозрачность. Благодаря им заголовок вверху и
/// панель внизу читаются, а узор не спорит с текстом.
/// Проверку на равенство фон намеренно не объявляет, хотя и зависит от
/// одного флага. Цвета в нём меняются вместе с темой системы, а тема
/// приходит не свойством вью, а окружением: пропустив перерисовку по
/// равенству свойств, холст остался бы в старой теме. Рисовать его
/// дёшево — узор уходит одной командой, — так что и экономить нечего.
struct SproutBackground: View {
    /// Насколько узор сейчас вздрогнул, −1…1.
    @State private var cheer = 0.0

    var body: some View {
        ZStack {
            Palette.background

            // Узор съезжает вслед за наклоном телефона. Холст для этого
            // шире экрана на размах сдвига — иначе, отъехав, он обнажил
            // бы край, — но наружу этот запас не выходит: он живёт в
            // наложении на пустой слой и обрезан по нему. Иначе ZStack
            // вырос бы вместе с ним и растяжки внизу и вверху уехали бы
            // за край экрана.
            Color.clear
                .overlay {
                    SproutPattern()
                        .padding(-Metrics.parallax)
                        .offset(x: Tilt.shared.shift.width,
                                y: Tilt.shared.shift.height)
                        .scaleEffect(1 + Metrics.cheerScale * cheer)
                        .rotationEffect(.degrees(Metrics.cheerTilt * cheer))
                }
                .clipped()

            VStack {
                // Сверху фон ничем не гасится: там лежит подложка из
                // корня, и она сама сходит в прозрачность. Узор идёт под
                // ней сплошняком и проступает по мере того, как подложка
                // тает, — стыку взяться неоткуда.
                Spacer(minLength: 0)
                wash
            }
        }
        .ignoresSafeArea()
        .onAppear { Tilt.shared.watch() }
        .onDisappear { Tilt.shared.unwatch() }
        .onChange(of: Cheer.shared.beat) { _, _ in wobble() }
    }

    /// Встряска: затухающие качания, каждое своей длительности.
    ///
    /// Цепочкой из задержек, а не одним движением: качание туда-обратно
    /// одной анимацией не описать, а ключевые кадры ради пяти значений
    /// заводить незачем. Каждая следующая анимация начинается там, где
    /// кончилась предыдущая.
    private func wobble() {
        var delay = 0.0
        for beat in Motion.cheerBeats {
            withAnimation(.easeInOut(duration: beat.duration).delay(delay)) {
                cheer = beat.value
            }
            delay += beat.duration
        }
    }

    /// Полоса, гасящая узор у нижнего края: узор не спорит с панелью
    /// вкладок, а сама панель ни на что не опирается.
    ///
    /// Верхней такой полосы больше нет. В макете она есть, и здесь была,
    /// но там ей нечего было держать, кроме края экрана. Край теперь
    /// держит подложка в корне приложения — ровно по вырезу и поверх
    /// содержимого, — а растяжка только гасила узор на добрых полтораста
    /// пунктов, там, где он должен просвечивать.
    private var wash: some View {
        // Возврат явный: из-за строки выше тело перестаёт быть одним
        // выражением, и неявный возврат SwiftUI на него не действует.
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

/// Логотип Sprout: три листа контуром и две капли воды.
///
/// Раньше здесь обводился лист фонового узора — получались закорючки,
/// к логотипу отношения не имеющие. Теперь это сам логотип из макета.
///
/// В плашке под чёлкой коробка контуров 13.37 × 21.1 — по пропорциям
/// шире, чем та же группа на отдельном экране логотипа. То есть в макете
/// логотип вписан в плашку с разным масштабом по осям, поэтому здесь две
/// шкалы, а не одна.
struct SproutLogo: View {
    /// Высота логотипа: в плашке макета 21.1.
    ///
    /// Ровно коробка контуров, без запаса. Обводка выходит за неё только
    /// вбок: концы стеблей внизу срезаны прямо, а сверху всё перекрывает
    /// капля, у которой обводки нет. Так это и записано в макете —
    /// absoluteRenderBounds группы выше самой группы на половину
    /// толщины слева и справа и совпадает с ней по высоте.
    var height: CGFloat = 21.1

    private static let aspect: CGFloat = 14.6986 / 21.1

    var body: some View {
        Canvas { context, size in
            let box = SproutShapes.logoBox
            let pad = SproutShapes.logoStroke / 2
            let sx = size.width / (box.width + 2 * pad)
            let sy = size.height / box.height
            let scale = CGAffineTransform(scaleX: sx, y: sy)
            // Стыки острые, концы срезаны — как в макете. Предел острия
            // 4 отвечает фигмовским 28.96°, за которыми она сама срезает
            // угол; здесь до него не доходит ни один стык.
            let style = StrokeStyle(
                lineWidth: SproutShapes.logoStroke * (sx * sy).squareRoot(),
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 4)

            func place(_ path: Path) -> Path {
                path.applying(scale).offsetBy(dx: pad * sx, dy: 0)
            }

            for leaf in SproutShapes.logoLeaves {
                context.stroke(place(leaf), with: .color(Palette.green),
                               style: style)
            }
            for drop in SproutShapes.logoDrops {
                context.fill(place(drop), with: .color(Palette.water))
            }
        }
        .frame(width: height * Self.aspect, height: height)
        .accessibilityHidden(true)
    }
}
