import Foundation
import Observation
import SwiftUI

/// Фигурки фонового узора и логотипа.
///
/// Росток, капля и логотип не нарисованы на глаз — это те же кривые, что
/// в макете. Figma отдаёт их в fillGeometry при запросе с geometry=paths,
/// отсюда и взяты. Цветок и горшок в макете не рисовались: их добавила
/// настройка «сколько фигурок в узоре», и они построены по числам — см.
/// каждый из них.
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

    /// Середины фигур узора. Вокруг них фигурка и раздаётся, когда
    /// растение полили: масштаб от угла увёл бы её с места. Ими же
    /// фигурка ставится на своё место в сетке — см. `SproutPattern`.
    static let leafCentre = CGPoint(x: 25.1033, y: 21.1164)
    static let dropCentre = CGPoint(x: 15.2097, y: 21.1164)

    /// Середина двух дорисованных фигурок. Обе нарисованы в коробке
    /// капли — 30.42 в ширину, — и середина у них общая с ней.
    ///
    /// Ширина здесь не вкус, а условие. Фигурки стоят в сетке через
    /// 44.3 pt серединами, а на гребне волны раздаются в 1.15 раза,
    /// пока соседняя ещё держит 1.06: половины должны уложиться в
    /// промежуток. У ростка с каплей они укладываются впритык — 28.87
    /// плюс 16.12 против 44.99, — и всё, что не шире капли, встаёт в те
    /// же зазоры, ничего не задев.
    static let addedCentre = CGPoint(x: 15.2097, y: 21.1164)

    /// Цветок: пять лепестков по кругу и сердцевина.
    ///
    /// Не обведён по макету — в макете его нет, — а построен: пять
    /// одинаковых кругов, расставленных через 72° на расстоянии 8.4 от
    /// середины, плюс круг посередине. Радиус лепестка 6.8 подобран так,
    /// чтобы соседние заходили друг за друга и силуэт вышел сплошным, а
    /// не гирляндой из шариков: их середины отстоят на 9.87, и при 6.8
    /// пересечение есть, а очертания лепестков ещё читаются.
    ///
    /// Половина ширины — 8.4·cos 18° + 6.8 = 14.79, чуть меньше капли:
    /// в зазоры сетки цветок проходит с запасом.
    ///
    /// Сердцевина нужна, потому что сами лепестки середины не
    /// закрывают: 8.4 больше 6.8, и в центре оставалась бы дырка
    /// звёздочкой в четыре пункта. На восьми процентах плотности это
    /// читалось бы браком заливки, а не рисунком.
    static let flower: Path = {
        var p = Path()
        let middle = addedCentre
        let reach = 8.4, petal = 6.8
        for step in 0 ..< 5 {
            // Первый лепесток смотрит вверх: цветок с лепестком строго
            // сверху стоит ровно, а повёрнутый на полшага — валится вбок.
            let angle = -Double.pi / 2 + Double(step) * 2 * .pi / 5
            let spot = CGPoint(x: middle.x + reach * cos(angle),
                               y: middle.y + reach * sin(angle))
            p.addEllipse(in: CGRect(x: spot.x - petal, y: spot.y - petal,
                                    width: 2 * petal, height: 2 * petal))
        }
        p.addEllipse(in: CGRect(x: middle.x - 4.6, y: middle.y - 4.6,
                                width: 9.2, height: 9.2))
        return p
    }()

    /// Горшок: ободок и сужающееся книзу тулово.
    ///
    /// Тоже построен, а не обведён. Ободок во всю ширину коробки, тулово
    /// на 3.4 уже с каждой стороны сверху и на 7.5 снизу — обычный конус
    /// цветочного горшка. Свес ободка нужен именно такой: при двух
    /// пунктах на тридцать он терялся и горшок читался просто трапецией.
    /// Нижние углы скруглены на те же 1.6, что и ободок: острые углы в
    /// узоре, где всё остальное собрано из дуг, кололи бы глаз.
    ///
    /// По высоте горшок занимает от 5.4 до 36.8 — те же 21.1 посередине,
    /// что и у ростка с каплей, поэтому ряды остаются рядами.
    static let pot: Path = {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 0, y: 5.4, width: 30.4193, height: 7.4),
                         cornerSize: CGSize(width: 1.6, height: 1.6))
        p.move(to: CGPoint(x: 3.4, y: 12.8))
        p.addLine(to: CGPoint(x: 27.0, y: 12.8))
        p.addLine(to: CGPoint(x: 22.85, y: 35.0))
        p.addQuadCurve(to: CGPoint(x: 21.0, y: 36.8),
                       control: CGPoint(x: 22.5, y: 36.8))
        p.addLine(to: CGPoint(x: 9.4, y: 36.8))
        p.addQuadCurve(to: CGPoint(x: 7.55, y: 35.0),
                       control: CGPoint(x: 7.9, y: 36.8))
        p.closeSubpath()
        return p
    }()

    /// Фигурка узора: контур и его середина.
    struct Piece {
        var path: Path
        var centre: CGPoint
    }

    /// Все фигурки узора по порядку. Настройка выбирает не набор, а
    /// докуда по этому порядку идти: узор этого приложения начинается с
    /// ростка, и оставить один горшок без ростка было бы уже не им.
    static let pieces: [Piece] = [
        Piece(path: leaf, centre: leafCentre),
        Piece(path: drop, centre: dropCentre),
        Piece(path: flower, centre: addedCentre),
        Piece(path: pot, centre: addedCentre),
    ]

    /// Коробка, по которой фигурки сравниваются между собой: самая
    /// широкая и самая высокая из них. По ней их и показывают рядом в
    /// настройках — каждая в своём размере, как в узоре, а не растянутая
    /// на всю клетку.
    static let pieceBox = CGSize(width: 50.2067, height: 42.2327)

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
/// вместе с ним. Свойства этой вью при этом остаются прежними, поэтому
/// при пересборке SwiftUI видит её неизменной и тела не трогает: холст не
/// перерисовывается, а только съезжает. Иначе на каждый кадр наклона
/// заново собирался бы контур из полутора сотен ростков.
///
/// Тему при этом вью читает явно. Холст рисуется замыканием, и снаружи не
/// видно, что цвет узора зависит от темы; без этой зависимости вью так и
/// осталась бы «прежней» при переключении темы и не перерисовалась бы.
private struct SproutPattern: View {
    /// Где сейчас волна всплесков, 0…1. Пусто — волны нет, и узор
    /// собирается как обычно.
    ///
    /// Пока волны нет, значение не меняется, и параллакс по-прежнему
    /// двигает готовый холст, не перерисовывая его. Зато пока волна идёт,
    /// узор пересобирается каждый кадр — иначе фигуркам нечем
    /// всплёскивать поодиночке.
    var wave: Double?

    /// Откуда волна пошла — в координатах окна.
    var origin: CGPoint

    /// Откуда пошли всходы, в радианах. Своё на каждый запуск.
    var bloomAngle: Double

    /// Насколько узор взошёл при запуске, 0…1.
    ///
    /// Всходит он по фигурке: у каждой свой черёд, очередь идёт снизу
    /// вверх. Ростом от нуля, а не проявлением, — узор рисуется одной
    /// заливкой на весь экран, своей прозрачности у фигурки быть не
    /// может, а свой размер может: он и так уезжает в её преобразование.
    var bloom: Double

    /// Какие фигурки в узоре — их номера, по порядку. Приходит из
    /// настроек.
    var shapes: [Int]

    /// Как они разложены по сетке. Своя на каждый запуск — см. `Weave`.
    var weave: Weave

    /// Идёт ли сейчас смена набора и как далеко зашла.
    var swap: Reshape?

    /// Цвет узора в покое и цвет волны полива. Оба из настроек, а пока
    /// цвет меняется — смесь прежнего с новым, см. `Repaint`.
    ///
    /// Имена с хвостом: `wave` выше — это доля волны, а не её цвет.
    var baseShade: Shade
    var waveShade: Shade

    @Environment(\.colorScheme) private var scheme

    /// Шаг сетки из макета: ячейки через 89.4 pt, ряды через 46.7 pt.
    private let pitchX: CGFloat = 89.4
    private let pitchY: CGFloat = 46.68

    /// Где внутри ячейки стоят середины двух фигурок.
    ///
    /// Числа не новые: в макете росток стоит углом на нуле, капля — на
    /// 55, и середины у них приходятся ровно сюда. Раньше фигурки
    /// ставились углом, и это годилось, пока их было ровно две и каждая
    /// знала своё место. Теперь на место может встать любая из четырёх, а
    /// коробки у них разной ширины: поставленная углом широкая фигурка
    /// уехала бы вправо и налезла на соседнюю ячейку. Середина же у всех
    /// одна, и от неё они и раздаются на волне — то есть по ней и надо
    /// расставлять.
    private let anchors: [CGFloat] = [25.1033, 70.2097]

    /// На сколько ступеней разбит переход от зелёного к синему.
    ///
    /// Ступенями, а не плавно у каждой фигурки. Холст заливает контур
    /// одной командой на цвет, а цвет у каждой фигурки на волне свой:
    /// плавно — значит по команде на фигурку, под три сотни на кадр,
    /// ровно то, от чего этот холст в своё время и ушёл. Шесть ступеней —
    /// шесть команд, а разницы между соседними ступенями глаз на
    /// восьмипроцентной заливке не берёт: соседние фигурки и так
    /// отличаются на восьмую долю прохода.
    private static let tints = 6

    var body: some View {
        Canvas { context, size in
            let layers = pattern(covering: size)
            // Свечение — те же синие фигурки, размытые, под ними самими.
            // Отдельным слоем, потому что размытие в холсте берёт всё, что
            // в слой попало, а зелёному узору размываться незачем.
            context.drawLayer { halo in
                halo.addFilter(.blur(radius: Metrics.splashGlow))
                for (step, layer) in layers.enumerated()
                where step > 0 && !layer.isEmpty {
                    halo.fill(layer, with: .color(
                    Palette.glow(waveShade, level: level(step))))
                }
            }
            for (step, layer) in layers.enumerated() where !layer.isEmpty {
                context.fill(layer, with: .color(Palette.pattern(
                    baseShade, wave: waveShade, splash: level(step))))
            }
        }
        .id(scheme)
    }

    /// Насколько посинела фигурка на этой ступени, 0…1.
    private func level(_ step: Int) -> Double {
        Double(step) / Double(Self.tints - 1)
    }

    /// Место нажатия в координатах холста.
    ///
    /// Холст начинается выше и левее экрана ровно на размах параллакса —
    /// отсюда сдвиг. Сам параллакс в пересчёт не берётся: он не больше
    /// четырнадцати пунктов, а волна расходится на сотни, и на её ходе
    /// такой сдвиг не читается.
    private var source: CGPoint {
        CGPoint(x: origin.x + Metrics.parallax,
                y: origin.y + Metrics.parallax)
    }

    /// Весь узор одним контуром.
    ///
    /// Раньше здесь было по команде заливки на каждый росток и каплю —
    /// под три сотни отдельных вызовов на кадр. Собранные в один контур,
    /// они уходят одной: рисуется столько же, а команд в двести раз
    /// меньше. Волна этого не ломает: у каждой фигурки свой масштаб, но
    /// он уезжает в её собственное преобразование при добавлении в
    /// контур, и заливка всё та же одна.
    private func pattern(covering size: CGSize) -> [Path] {
        var layers = [Path](repeating: Path(), count: Self.tints)
        // Настройке не доверяем на слово: узор рисуется каждый кадр
        // волны, и промах по границам обошёлся бы падением, а не кривым
        // рисунком. Пустой набор тоже отводим — рисовать нечем, а фон
        // без узора это не фон этого приложения.
        let picked = shapes.filter(SproutShapes.pieces.indices.contains)
        let list = picked.isEmpty ? [0] : picked
        let leaving = swap?.from.filter(SproutShapes.pieces.indices.contains)
        // Середина по вертикали у всех фигурок общая: они и нарисованы в
        // коробках одной высоты, оттого и стоят рядами.
        let centreY = SproutShapes.leafCentre.y
        var row = 0
        var y = -pitchY
        while y < size.height + pitchY {
            var column = 0
            var x = -pitchX
            while x < size.width + pitchX {
                for (slot, anchor) in anchors.enumerated() {
                    let middle = CGPoint(x: x + anchor, y: y + centreY)
                    let grow = pop(at: middle)
                    var scale = grow
                    var here = list
                    var mesh = weave
                    if let swap, let leaving, !leaving.isEmpty {
                        let (share, old) = change(swap, at: middle, over: size)
                        scale *= share
                        if old { here = leaving; mesh = swap.fromWeave }
                    } else {
                        scale *= sprouted(at: middle, over: size)
                    }
                    guard scale > 0 else { continue }
                    let index = mesh.index(column: column, slot: slot,
                                           row: row, of: here.count)
                    add(SproutShapes.pieces[here[index]], at: middle,
                        scale: scale, tint: tint(of: grow), to: &layers)
                }
                x += pitchX
                column += 1
            }
            y += pitchY
            row += 1
        }
        return layers
    }

    /// Поставить фигурку в свой слой: серединой на своё место, в своём
    /// размере и своего цвета.
    private func add(_ piece: SproutShapes.Piece, at middle: CGPoint,
                     scale: CGFloat, tint: Int, to layers: inout [Path]) {
        guard scale != 1 else {
            layers[tint].addPath(piece.path, transform: CGAffineTransform(
                translationX: middle.x - piece.centre.x,
                y: middle.y - piece.centre.y))
            return
        }
        // Раздаётся фигурка вокруг своей середины: от угла её уводило бы
        // вправо и вниз.
        layers[tint].addPath(piece.path, transform:
            CGAffineTransform(translationX: middle.x, y: middle.y)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -piece.centre.x, y: -piece.centre.y))
    }

    /// Как фигурка переживает смену набора: во сколько раз она сейчас
    /// меньше себя и чей набор ещё рисует — прежний или новый.
    ///
    /// Проход у фигурки один и делится пополам: сперва она сжимается до
    /// нуля, потом из нуля же вырастает — уже другой. Обе кривые у нуля
    /// крутые, поэтому сквозь него фигурка проскакивает быстро и пустого
    /// места на её клетке почти не бывает.
    ///
    /// Очередь идёт по выбранной стороне, как и всходы, — и волна ухода с
    /// волной прихода идут внахлёст: пока дальний край ещё стоит прежним,
    /// ближний уже стоит новым.
    private func change(_ swap: Reshape, at middle: CGPoint,
                        over size: CGSize) -> (CGFloat, Bool) {
        let turn = queue(at: middle, over: size, angle: swap.angle)
        let step = (swap.step - turn * (1 - Metrics.swapSpan)) / Metrics.swapSpan
        guard step > 0 else { return (1, true) }
        guard step < 1 else { return (1, false) }
        guard step >= 0.5 else {
            let x = step * 2
            return (CGFloat(1 - x * x * x), true)
        }
        let x = (step - 0.5) * 2
        return (CGFloat(1 - pow(1 - x, 3)), false)
    }

    /// Черёд фигурки в очереди, 0…1: ноль у той, с которой всё
    /// начинается, единица у самой дальней.
    ///
    /// Место считается от размера холста, а не экрана. Холст у подложки
    /// под вырезом свой, куда ниже, и очередь в ней пойдёт своя — но на
    /// главной подложки нет, а всходы бывают только на запуске, то есть
    /// только на главной.
    private func queue(at middle: CGPoint, over size: CGSize,
                       angle: Double) -> Double {
        let x = Double(middle.x / max(size.width, 1)) - 0.5
        let y = Double(middle.y / max(size.height, 1)) - 0.5
        let dx = cos(angle), dy = sin(angle)
        // Проекция на направление, растянутая на весь ход. У косого
        // направления размах шире, чем у прямого, и без пересчёта часть
        // хода уходила бы впустую.
        let reach = (abs(dx) + abs(dy)) / 2
        return min(max((x * dx + y * dy) / (2 * reach) + 0.5, 0), 1)
    }

    /// Насколько фигурка посинела — ступенью от нуля до последней.
    ///
    /// Считается от подъёма, а не от общего размера. Общий размер — это
    /// ещё и всходы при запуске, и по нему всходящая фигурка синела бы
    /// просто оттого, что не доросла.
    ///
    /// Поджатая остаётся зелёной: синеет только то, что поднялось. Волна
    /// от этого читается синим гребнем между двумя зелёными ямками, а не
    /// синей полосой во всю ширину прохода.
    private func tint(of grow: CGFloat) -> Int {
        guard grow > 1 else { return 0 }
        let share = min(Double(grow - 1) / Metrics.popAmp, 1)
        return Int((share * Double(Self.tints - 1)).rounded())
    }

    /// Насколько фигурка взошла при запуске.
    ///
    /// Черёд у каждой свой и берётся из её же места: очередь идёт по
    /// выбранному направлению, а направление на каждый запуск своё, любое
    /// из круга. Прежде она шла всегда снизу вверх — и на третий запуск
    /// это уже заставка, а не всходы.
    ///
    /// Место считается от размера холста, а не экрана. Холст у подложки
    /// под вырезом свой, куда ниже, и очередь в ней пойдёт своя — но на
    /// главной подложки нет, а всходы бывают только на запуске, то есть
    /// только на главной.
    private func sprouted(at middle: CGPoint, over size: CGSize) -> CGFloat {
        guard bloom < 1 else { return 1 }
        guard bloom > 0 else { return 0 }
        let turn = queue(at: middle, over: size, angle: bloomAngle)
        let step = (bloom - turn * (1 - Metrics.bloomSpan)) / Metrics.bloomSpan
        guard step > 0 else { return 0 }
        guard step < 1 else { return 1 }
        // Быстрый выход из нуля и мягкая посадка: та же кривая, что у
        // частей логотипа на заставке.
        return CGFloat(1 - pow(1 - step, 3))
    }

    /// Насколько фигурка сейчас раздалась.
    ///
    /// Всё решает расстояние до места нажатия: ближние всплёскивают
    /// первыми, дальние — следом, и по фону расходится кольцо. Ни размах,
    /// ни длительность у фигурок не разнятся. Раньше разнились, и обе
    /// вразнобой: кольца за этим видно не было, по экрану шла рябь.
    ///
    /// Проход не «раздалась и вернулась», а ямка — гребень — ямка: перед
    /// поднявшимися идут поджатые, за ними тоже.
    ///
    /// Окно всплеска широкое — семь с половиной делений сетки, — и в
    /// каждой полосе оказывается по два с половиной ряда. Волна от этого
    /// идёт полосами, а не перебором рядов: соседи по ряду поднимаются
    /// вместе, одной группой, а поджатая полоса стоит через два ряда от
    /// гребня. Узким окном каждый ряд отрабатывал свой всплеск сам,
    /// вплотную за соседним, и это читалось перещёлкиванием.
    private func pop(at middle: CGPoint) -> CGFloat {
        guard let wave else { return 1 }
        let far = hypot(middle.x - source.x, middle.y - source.y)
        let start = Double(min(far / Metrics.waveReach, 1))
            * (1 - Metrics.popSpan)
        let step = (wave - start) / Metrics.popSpan
        guard step > 0, step < 1 else { return 1 }
        // Полтора периода синуса: вниз, вверх, вниз — ямка перед гребнем,
        // ямка за ним. Второй множитель — оболочка: он ничего не меняет
        // на гребне, зато прижимает концы окна к нулю не только по
        // высоте, но и по скорости.
        //
        // Без неё фигурка трогалась с места сразу на полном ходу — волна
        // до неё дошла, и та в тот же кадр рванула. Отсюда и дёрганье:
        // на краю окна скорость падает с 9.4 до 0.03, а на самом
        // движении сказывается едва.
        let swing = -sin(3 * .pi * step) * sin(.pi * step)
        // Размах переходит в поджим плавно, а не по знаку. По знаку
        // множитель прыгал втрое, трижды за проход, и фигурка на
        // возврате к своему размеру спотыкалась: значение на стыке не
        // прыгало, а наклон прыгал.
        let mean = (Metrics.popAmp + Metrics.popDip) / 2
        let half = (Metrics.popAmp - Metrics.popDip) / 2
        return CGFloat(1 + swing * (mean + half * tanh(swing / Metrics.popBlend)))
    }
}

/// Повод порадоваться: растение полили.
///
/// Один на приложение. Держит саму волну — когда началась и откуда, — а
/// не только повод. Фон рисуется в двух местах: на экране и подложкой
/// под вырезом. Веди каждый свою волну, они разошлись бы на кадр-другой,
/// и по нижнему краю подложки стало бы видно шов.
///
/// Кто, где и что полил, узору знать незачем — только точку, откуда
/// расходиться. А поливают с двух экранов и из двух меню.
///
/// Хранится начало, а не «где волна сейчас». Здесь стоял свой шаг —
/// цикл со сном по шестнадцать миллисекунд, — и волна от него дёргалась:
/// сон отмеряет не меньше положенного, а не ровно, и его такт с
/// обновлением экрана не совпадает. Одни кадры получали двойной шаг,
/// другие ни одного. Теперь шага нет вовсе: время спрашивает сам экран,
/// через `TimelineView`, и каждый кадр берёт долю ровно на свой момент.
@Observable
final class Cheer {
    static let shared = Cheer()

    /// Когда началась текущая волна. Пусто — волны нет.
    private(set) var start: Date?

    /// Откуда она пошла — в координатах окна.
    private(set) var origin: CGPoint = .zero

    /// Чем волна кончится. Поливать можно чаще, чем она успевает
    /// отыграть, и новая должна отменять старую, а не спорить с ней.
    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    /// Полили вот здесь. Плашка — в координатах окна: узор отсчитывается
    /// от верхнего левого угла экрана, других координат он не знает.
    ///
    /// Расходится волна по-прежнему из середины плашки, кругами. Но
    /// начинается не с нуля, а с форой ровно на путь от середины до края:
    /// под плашкой узора всё равно не видно, и без форы узор рядом с ней
    /// трогался четвертью секунды позже голубой тени — событие читалось
    /// растянутым, сперва тень, потом, отдельно, фон.
    ///
    /// Форе негде себя выдать: она вся уходит на то, что закрыто плашкой,
    /// а первая же видимая фигурка застаёт волну в самом начале своего
    /// окна и трогается с нуля, как и раньше.
    func now(from plate: CGRect) {
        run?.cancel()
        origin = CGPoint(x: plate.midX, y: plate.midY)
        let lead = Self.lead(across: plate)
        start = Date().addingTimeInterval(-lead)
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.cheerSeconds - lead))
            // Прервали ради новой волны — она уже идёт, и гасить нечего.
            guard !Task.isCancelled else { return }
            start = nil
        }
    }

    /// Сколько волне идти от середины плашки до её края.
    ///
    /// По вписанной окружности, а не по описанной: так фронт к началу
    /// стоит внутри плашки со всех сторон, и наружу ничего не выпрыгивает.
    private static func lead(across plate: CGRect) -> Double {
        let radius = Double(min(plate.width, plate.height)) / 2
        return radius / Double(Metrics.waveReach)
            * (1 - Metrics.popSpan) * Motion.cheerSeconds
    }

    /// Где волна на этот момент, 0…1. Пусто — волны нет или уже отыграла.
    func wave(at moment: Date) -> Double? {
        guard let start else { return nil }
        let step = moment.timeIntervalSince(start) / Motion.cheerSeconds
        return step < 1 ? step : nil
    }
}

/// Глубина выреза. Ставит корень приложения, читают экраны.
///
/// Через окружение: число берётся у окна, а окно видно только из корня.
private struct NotchKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var notch: CGFloat {
        get { self[NotchKey.self] }
        set { self[NotchKey.self] = newValue }
    }
}

/// Смена цвета узора: плавный переход от прежней пары оттенков к новой.
///
/// Плавный, но без волны — в отличие от смены набора фигурок. Там на
/// месте одной фигурки оказывается другая, и подмена кадром читается
/// рывком, поэтому прежним приходится уходить, а новым приходить. Цвет же
/// меняется у той же самой фигурки: ей довольно перелиться из прежнего
/// цвета в новый, и уходить незачем.
///
/// Хранится начало перехода, а не доля. Фон рисуется в двух местах — на
/// экране и подложкой под вырезом, — и веди каждый свой переход, они
/// разошлись бы на кадр-другой. Та же причина, что у волны, см. `Cheer`.
@Observable
final class Repaint {
    static let shared = Repaint()

    /// Когда начался переход. Пусто — цвет стоит.
    private(set) var start: Date?

    /// Откуда переходим. Пара целиком: сменить могли и цвет узора, и цвет
    /// волны, а перелиться должно то, что на экране.
    @ObservationIgnored private(set) var from = Shade(Tint.defaultPattern)
    @ObservationIgnored private(set) var fromWave = Shade(Tint.defaultWave)

    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    /// Начать переход от этой пары.
    ///
    /// Зовётся до того, как настройка поменяется: прежний цвет надо
    /// запомнить, пока он ещё прежний.
    ///
    /// Если переход уже идёт, отсчёт начинается не от полной прежней
    /// пары, а от того, что сейчас на экране. Иначе второй выбор подряд
    /// дёрнул бы узор назад, к цвету, от которого он уже наполовину ушёл.
    @MainActor
    func begin(base: Tint, wave: Tint, at moment: Date = Date()) {
        let part = blend(at: moment)
        from = part.map { Shade.mix(from, Shade(base), $0) } ?? Shade(base)
        fromWave = part.map { Shade.mix(fromWave, Shade(wave), $0) }
            ?? Shade(wave)
        start = moment
        run?.cancel()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.repaintSeconds))
            guard !Task.isCancelled else { return }
            start = nil
        }
    }

    /// Насколько переход прошёл, 0…1. Пусто — перехода нет.
    func blend(at moment: Date) -> Double? {
        guard let start else { return nil }
        let done = moment.timeIntervalSince(start) / Motion.repaintSeconds
        guard done < 1 else { return nil }
        // Плавно и на входе, и на выходе: цвет не должен трогаться с места
        // рывком и не должен вставать как вкопанный.
        return done * done * (3 - 2 * done)
    }
}

/// Смена набора фигурок в узоре: чем узор был и как далеко зашла подмена.
///
/// Прежний набор приходится держать вместе с новым: фигурки не
/// подменяются разом, а уходят волной и той же волной возвращаются, и
/// пока волна не прошла, на экране стоят оба набора — впереди прежний,
/// позади новый.
///
/// Раскладка у прежнего своя: она считается от числа фигурок, а их стало
/// другое количество. Без неё уходящий узор перед самым уходом
/// перетасовался бы.
struct Reshape {
    /// Что было в узоре до смены.
    var from: [Int]
    var fromWeave: Weave
    /// С какой стороны идёт волна, в радианах. Своя на каждую смену.
    var angle: Double
    /// Насколько смена прошла, 0…1.
    var step: Double
}

/// Запуск приложения: заставка и ступени, которыми собирается экран.
///
/// Один на приложение и создаётся один раз за его жизнь — потому
/// заставка и показывается только на холодном запуске. Вернувшись из
/// фона, приложение застаёт `Launch` уже отыгравшим и собирается сразу.
///
/// Ступени номерами, а не набором флагов: их порядок и есть весь смысл —
/// узор, заголовок, комната, сетка, панель вкладок. Каждый элемент знает
/// только свой номер и ждёт, пока счётчик до него дойдёт.
@Observable
final class Launch {
    static let shared = Launch()

    /// Сколько ступеней открыто. Ноль — не открыто ничего.
    private(set) var step = 0

    /// Показывать ли заставку.
    private(set) var greeting = true

    /// Откуда пойдут всходы, в радианах. Выбирается заново на каждые
    /// всходы: на третий раз всходы всегда снизу — это уже заставка, а не
    /// всходы.
    @ObservationIgnored private(set) var bloomAngle =
        Double.random(in: 0 ..< 2 * Double.pi)

    /// Три числа, из которых складывается раскладка узора. Свои на каждый
    /// запуск — оттого при каждом холодном пуске фигурки стоят иначе.
    @ObservationIgnored private let twistX = Int.random(in: 0 ..< 64)
    @ObservationIgnored private let twistY = Int.random(in: 0 ..< 64)
    @ObservationIgnored private let twistStart = Int.random(in: 0 ..< 64)

    /// Когда началась смена набора фигурок. Пусто — не менялся.
    private(set) var swapStart: Date?

    @ObservationIgnored private var swapAngle = 0.0
    @ObservationIgnored private var swapFrom: [Int] = []

    /// Раскладка узора для такого числа фигурок.
    ///
    /// Считается из тех же трёх чисел, поэтому смена набора в настройках
    /// не тасует узор заново: пока фигурок столько же, раскладка та же.
    func weave(for count: Int) -> Weave {
        Weave(count: count, twistX: twistX, twistY: twistY, start: twistStart)
    }

    /// Когда узор начал всходить. Пусто — либо ещё не начал, либо уже
    /// весь на месте.
    ///
    /// Часами, а не долей в состоянии вью: фон рисуется в двух местах —
    /// на экране и подложкой под вырезом, — и веди каждый свои всходы,
    /// они разошлись бы на кадр-другой. Ровно та же причина, что у
    /// волны, см. `Cheer`.
    private(set) var bloomStart: Date?

    /// Последняя ступень — панель вкладок.
    static let last = 5

    @ObservationIgnored private var ran = false

    /// Задача, гасящая часы всходов. Одна на всех: всходы бывают и при
    /// запуске, и при смене набора фигурок, и новая должна отменять
    /// старую, а не спорить с ней.
    @ObservationIgnored private var blooming: Task<Void, Never>?

    private init() {}

    /// Отыграть запуск. Второй раз ничего не делает: экраны появляются и
    /// исчезают, а запуск у приложения один.
    @MainActor
    func run() async {
        guard !ran else { return }
        ran = true
        try? await Task.sleep(for: .seconds(Motion.welcomeHold))
        withAnimation(Motion.welcomeLeave) { greeting = false }
        // Ступени ждут, пока заставка сойдёт совсем. Здесь они шли
        // из-под неё — и первых двух, узора и заголовка, попросту не было
        // видно: они успевали встать на места, пока заставка ещё тает.
        try? await Task.sleep(for: .seconds(Motion.welcomeLeaveSeconds))
        for _ in 1...Self.last {
            withAnimation(Motion.enter) { step += 1 }
            // Первая ступень — узор, и всходит он своим ходом, по
            // фигурке. Ступень при этом обычная: она открывает всходам
            // дорогу, а рисует их сам узор.
            if step == 1 { sprout() }
            try? await Task.sleep(for: .seconds(Motion.enterStep))
        }
    }

    /// Сменить набор фигурок: прежний уходит волной, новый той же волной
    /// приходит следом.
    ///
    /// Зовётся из настроек. Подменить фигурки кадром было нельзя: узор —
    /// вещь на весь экран, и подмена в нём читается рывком. Но и всходов,
    /// как при запуске, здесь мало: они начинаются с пустого экрана, а
    /// тут экран не пустой, и прежнему узору надо сперва уйти.
    ///
    /// Сторона своя на каждую смену: одно и то же направление на третий
    /// раз читается заставкой, а не сменой.
    @MainActor
    func reshape(from before: [Int]) {
        swapFrom = before
        swapAngle = Double.random(in: 0 ..< 2 * Double.pi)
        swapStart = Date()
        blooming?.cancel()
        blooming = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.swapSeconds))
            guard !Task.isCancelled else { return }
            swapStart = nil
        }
    }

    /// Где сейчас смена набора. Пусто — её нет.
    func reshape(at moment: Date) -> Reshape? {
        guard let swapStart else { return nil }
        let done = moment.timeIntervalSince(swapStart) / Motion.swapSeconds
        guard done < 1 else { return nil }
        return Reshape(from: swapFrom,
                       fromWeave: weave(for: swapFrom.count),
                       angle: swapAngle,
                       step: done)
    }

    /// Пустить всходы — с новой стороны и по всей сетке. Зовётся при
    /// запуске: узор всходит на пустом экране.
    @MainActor
    func sprout() {
        bloomAngle = Double.random(in: 0 ..< 2 * Double.pi)
        bloomStart = Date()
        blooming?.cancel()
        // Дождёмся конца и погасим часы, чтобы расписание холста встало на
        // паузу: пока всходов нет, будить его нечем.
        blooming = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.bloomSeconds))
            guard !Task.isCancelled else { return }
            bloomStart = nil
        }
    }

    /// Насколько узор взошёл к этому мгновению, 0…1.
    func bloom(at moment: Date) -> Double {
        guard let bloomStart else { return step >= 1 ? 1 : 0 }
        let done = moment.timeIntervalSince(bloomStart) / Motion.bloomSeconds
        return done < 1 ? done : 1
    }
}

/// Ступень входа: пока её черёд не настал, элемента нет; настал — он
/// поднимается на место.
///
/// Начальное значение берётся из счётчика, а не «нет». Сетка ленивая, и
/// созданная позже карточка иначе всплывала бы заново — та же история,
/// что и с появлением карточек.
struct Enter: ViewModifier {
    let step: Int

    /// Насколько элемент приходит снизу.
    let rise: CGFloat

    @State private var shown: Bool

    init(step: Int, rise: CGFloat = Motion.enterRise) {
        self.step = step
        self.rise = rise
        _shown = State(initialValue: Launch.shared.step >= step)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : rise)
            .onChange(of: Launch.shared.step >= step) { _, open in
                withAnimation(Motion.enter) { shown = open }
            }
    }
}

/// Место на экране, которое никто не рисует.
///
/// Где лежит карточка, нужно ровно в одну секунду — когда нажали
/// «Полить», — а меняется это на каждом кадре прокрутки. Лежи замер в
/// состоянии вью, каждый такой кадр пересобирал бы её ради числа,
/// которого в теле никто не читает.
///
/// Прятать от SwiftUI то, что рисуется, нельзя: на этом здесь уже
/// обжигались — журнал показанных карточек уехал в такой же класс, тело
/// экрана перестало пересобираться, и появление заиграло заново на
/// каждой прокрутке. Тут наоборот: значение читается только в
/// обработчике нажатия, и застыть ему негде.
final class Spot {
    var rect: CGRect = .zero

}

/// Фон как таковой: ровный цвет и узор поверх него.
///
/// Отдельным типом, потому что рисуется в двух местах — экраном и
/// подложкой под вырезом. Оба отсчитываются от верхнего левого угла
/// окна, поэтому узор в них стоит в одних и тех же точках.
private struct SproutField: View {
    var body: some View {
        // Настройку читаем здесь, в теле поля, а не внутри расписания
        // ниже. Внутри её читало бы содержимое `TimelineView`, а оно
        // пересобирается по кадрам расписания — и на паузе, когда нет ни
        // волны, ни всходов, смена набора фигурок могла бы остаться
        // незамеченной. Прочитанная телом, она перерисовывает узор сразу.
        //
        // Возврат явный: из-за строки выше тело перестаёт быть одним
        // выражением.
        let shapes = Settings.shared.chosen
        let weave = Launch.shared.weave(for: shapes.count)
        let baseTint = Settings.shared.patternTint
        let waveTint = Settings.shared.waveTint
        let repainting = Repaint.shared.start != nil
        return ZStack {
            Palette.background

            // Узор съезжает вслед за наклоном телефона. Холст для этого
            // шире экрана на размах сдвига — иначе, отъехав, он обнажил
            // бы край, — но наружу этот запас не выходит: он живёт в
            // наложении на пустой слой и обрезан по нему. Иначе ZStack
            // вырос бы вместе с ним и растяжка внизу уехала бы за край
            // экрана.
            Color.clear
                .overlay {
                    // Долю волны берём у экрана, а не у своего таймера:
                    // `TimelineView` будит содержимое ровно к кадру, и
                    // каждый кадр получает свою долю, а не ту, что успел
                    // положить сон. Пока волны нет, расписание на паузе и
                    // не будит ничего.
                    // Холст будят и волна от полива, и всходы при
                    // запуске. Нет ни того ни другого — расписание на
                    // паузе и не будит ничего.
                    //
                    // Ступени `Enter` узору не досталось: он не
                    // проявляется слоем, а всходит по фигурке, и доля
                    // всходов приходит сюда тем же путём, что доля волны.
                    TimelineView(.animation(
                        paused: Cheer.shared.start == nil
                            && Launch.shared.bloomStart == nil
                            && Launch.shared.swapStart == nil
                            && !repainting)) { frame in
                        // Пока цвет переливается, оттенки на экране — не
                        // те, что в настройках, а смесь прежних с новыми.
                        let part = Repaint.shared.blend(at: frame.date)
                        SproutPattern(wave: Cheer.shared.wave(at: frame.date),
                                      origin: Cheer.shared.origin,
                                      bloomAngle: Launch.shared.bloomAngle,
                                      bloom: Launch.shared.bloom(at: frame.date),
                                      shapes: shapes,
                                      weave: weave,
                                      swap: Launch.shared.reshape(at: frame.date),
                                      baseShade: shade(baseTint,
                                                       from: Repaint.shared.from,
                                                       part: part),
                                      waveShade: shade(waveTint,
                                                       from: Repaint.shared.fromWave,
                                                       part: part))
                    }
                    .padding(-Metrics.parallax)
                    .offset(x: Tilt.shared.shift.width,
                            y: Tilt.shared.shift.height)
                }
                .clipped()
        }
    }
}

/// Оттенок, каким его рисовать сейчас: сам по себе или смешанный с
/// прежним, пока идёт переход.
private func shade(_ tint: Tint, from: Shade, part: Double?) -> Shade {
    guard let part else { return Shade(tint) }
    return Shade.mix(from, Shade(tint), part)
}

/// Фон экрана: узор и белая растяжка внизу.
///
/// Растяжка взята из макета один в один: сплошной фон до 40% высоты
/// полосы, дальше сход в прозрачность. Благодаря ей панель вкладок
/// читается, а узор с ней не спорит.
///
/// Проверку на равенство фон намеренно не объявляет. Цвета в нём
/// меняются вместе с темой системы, а тема приходит не свойством вью, а
/// окружением: пропустив перерисовку по равенству свойств, холст остался
/// бы в старой теме. Рисовать его дёшево — узор уходит одной командой, —
/// так что и экономить нечего.
struct SproutBackground: View {
    var body: some View {
        ZStack {
            SproutField()

            VStack {
                // Сверху фон ничем не гасится: там лежит подложка из
                // корня, и она рисует ровно тот же узор.
                Spacer(minLength: 0)
                wash
            }
        }
        .ignoresSafeArea()
        .onAppear { Tilt.shared.watch() }
        .onDisappear { Tilt.shared.unwatch() }
    }

    /// Полоса, гасящая узор у нижнего края: узор не спорит с панелью
    /// вкладок, а сама панель ни на что не опирается.
    ///
    /// Верхней такой полосы больше нет. В макете она есть, и здесь была,
    /// но там ей нечего было держать, кроме края экрана. Край теперь
    /// держит подложка под вырезом, а растяжка только гасила узор на
    /// добрых полтораста пунктов, там, где он должен просвечивать.
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

extension View {
    /// Подложка под вырезом — экранам, у которых верх ничем другим не
    /// занят.
    ///
    /// Главной она не нужна: там верх держит растяжка под строкой
    /// комнаты, и она доходит до самого края экрана. Две подложки разом
    /// не уживаются — растяжка гасит узор, а подложка показывает его во
    /// всю силу, и на их границе шла бы черта поперёк экрана.
    func sproutNotchCover() -> some View {
        modifier(SproutNotchCover())
    }
}

/// Подложка под вырезом: тот же фон, обрезанный по его глубине.
///
/// Нужна она затем, чтобы под строку состояния не заезжало содержимое.
/// Прежде это был ровный цвет — и он читался полосой, наклеенной поверх
/// экрана: узор под ним обрывался, и граница шла во всю ширину. Свести
/// её сходом не вышло ни разу: подложка и фон это два слоя с разной
/// разметкой и разным отсчётом, и совместить их край в край нельзя.
///
/// Сводить и нечего, если по обе стороны границы одно и то же. Подложка
/// рисует тот же фон и от того же угла окна, только обрезанный по
/// вырезу: узор проходит под ней насквозь, шва нет, а карточки под неё
/// всё так же не пролезают.
private struct SproutNotchCover: ViewModifier {
    @Environment(\.notch) private var notch

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            // Обрезать нечего: узор внутри уже обрезан по своему слою, а
            // ровный цвет ровно по размеру. Лишний `clipped` тут стоил бы
            // отдельного прохода растеризации на каждый кадр волны.
            SproutField()
                .frame(height: notch)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

/// Одна фигурка узора сама по себе — для выбора в настройках.
///
/// Формой, а не холстом: фигурку там надо и залить, и приглушить, и
/// вписать в клетку, а всё это форма умеет сама.
///
/// Масштаб общий на все четыре, а не «каждую враспор»: в узоре росток
/// крупнее капли, и в выборе они должны отличаться так же. Растянутая на
/// клетку капля обещала бы не ту фигурку, что появится на фоне.
struct SproutPiece: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let pieces = SproutShapes.pieces
        let piece = pieces[min(max(index, 0), pieces.count - 1)]
        let box = SproutShapes.pieceBox
        let scale = min(rect.width / box.width, rect.height / box.height)
        // Ставим серединой в середину клетки — той же серединой, вокруг
        // которой фигурка раздаётся на волне.
        return piece.path.applying(
            CGAffineTransform(translationX: rect.midX, y: rect.midY)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -piece.centre.x, y: -piece.centre.y))
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
struct SproutLogo: View, Animatable {
    /// Высота логотипа: в плашке макета 21.1.
    ///
    /// Ровно коробка контуров, без запаса. Обводка выходит за неё только
    /// вбок: концы стеблей внизу срезаны прямо, а сверху всё перекрывает
    /// капля, у которой обводки нет. Так это и записано в макете —
    /// absoluteRenderBounds группы выше самой группы на половину
    /// толщины слева и справа и совпадает с ней по высоте.
    var height: CGFloat = 21.1

    /// Пропорции. По умолчанию плашечные: в плашке под вырезом макет
    /// сжал логотип по ширине, и здесь это повторено. Сам по себе он не
    /// сжат — для него есть `plain`, и с ним обе шкалы внутри совпадают,
    /// то есть логотип не искажён.
    var aspect: CGFloat = Self.badge

    static let badge: CGFloat = 14.6986 / 21.1
    static let plain: CGFloat =
        (SproutShapes.logoBox.width + SproutShapes.logoStroke)
            / SproutShapes.logoBox.height

    /// Насколько логотип собрался, 0…1. Единица — весь, как в плашке.
    ///
    /// Числом, а не набором флагов: рисует все части один холст, и своей
    /// анимации у части быть не может. Число снаружи меняется ровно, а
    /// разъезжаются части задержкой — у каждой свой отрезок внутри хода.
    var reveal: Double = 1

    /// Анимируется именно эта доля. Без этого SwiftUI менял бы её
    /// скачком: холст — не фигура, промежуточных значений сам он для неё
    /// не считает.
    var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    /// Части в порядке появления — снизу вверх, как растёт росток. Лист
    /// со своим стеблем не делится: это одна фигура, просто в макете
    /// нарисована двумя контурами.
    private static let parts: [(leaves: [Int], drops: [Int])] = [
        (leaves: [2, 3], drops: []),
        (leaves: [0, 1], drops: []),
        (leaves: [4], drops: []),
        (leaves: [], drops: [0]),
        (leaves: [], drops: [1]),
    ]

    /// Насколько собралась часть под этим номером.
    private func grown(_ index: Int) -> Double {
        guard reveal < 1 else { return 1 }
        let span = 1 - Double(Self.parts.count - 1) * Motion.logoLag
        let step = (reveal - Double(index) * Motion.logoLag) / span
        guard step > 0 else { return 0 }
        guard step < 1 else { return 1 }
        // Быстрый приход и мягкая посадка: пружина здесь не годится —
        // частей пять, и отскок пятерых вразнобой читался бы дрожью.
        return 1 - pow(1 - step, 3)
    }

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

            for (index, part) in Self.parts.enumerated() {
                let t = grown(index)
                guard t > 0 else { continue }
                let leaves = part.leaves.map {
                    place(SproutShapes.logoLeaves[$0])
                }
                let drops = part.drops.map { place(SproutShapes.logoDrops[$0]) }

                // Часть подрастает вокруг собственной середины: от общей
                // она бы не росла, а съезжалась к центру логотипа.
                var layer = context
                if t < 1, let box = (leaves + drops)
                    .map(\.boundingRect)
                    .reduce(nil, { (all: CGRect?, one) in
                        all.map { $0.union(one) } ?? one
                    }) {
                    let scale = Motion.logoScale
                        + (1 - Motion.logoScale) * CGFloat(t)
                    layer.opacity = t
                    layer.translateBy(x: box.midX, y: box.midY)
                    layer.scaleBy(x: scale, y: scale)
                    layer.translateBy(x: -box.midX, y: -box.midY)
                }

                for leaf in leaves {
                    layer.stroke(leaf, with: .color(Palette.green),
                                 style: style)
                }
                for drop in drops {
                    layer.fill(drop, with: .color(Palette.water))
                }
            }
        }
        .frame(width: height * aspect, height: height)
        .accessibilityHidden(true)
    }
}
