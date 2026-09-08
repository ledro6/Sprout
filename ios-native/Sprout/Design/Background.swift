import Foundation
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

    /// Середины фигур узора. Вокруг них фигурка и раздаётся, когда
    /// растение полили: масштаб от угла увёл бы её с места.
    static let leafCentre = CGPoint(x: 25.1033, y: 21.1164)
    static let dropCentre = CGPoint(x: 15.2097, y: 21.1164)

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
    private func pattern(covering size: CGSize) -> Path {
        var path = Path()
        var y = -pitchY
        while y < size.height + pitchY {
            var x = -pitchX
            while x < size.width + pitchX {
                add(SproutShapes.leaf, at: CGPoint(x: x, y: y),
                    centre: SproutShapes.leafCentre, to: &path)
                add(SproutShapes.drop, at: CGPoint(x: x + dropOffsetX, y: y),
                    centre: SproutShapes.dropCentre, to: &path)
                x += pitchX
            }
            y += pitchY
        }
        return path
    }

    /// Поставить фигурку в общий контур: на своё место и в своём размере.
    private func add(_ shape: Path, at corner: CGPoint, centre: CGPoint,
                     to path: inout Path) {
        let middle = CGPoint(x: corner.x + centre.x, y: corner.y + centre.y)
        let scale = pop(at: middle)
        guard scale != 1 else {
            path.addPath(shape, transform: CGAffineTransform(
                translationX: corner.x, y: corner.y))
            return
        }
        // Раздаётся фигурка вокруг своей середины: от угла её уводило бы
        // вправо и вниз.
        path.addPath(shape, transform:
            CGAffineTransform(translationX: middle.x, y: middle.y)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -centre.x, y: -centre.y))
    }

    /// Насколько фигурка сейчас раздалась.
    ///
    /// Всё решает расстояние до места нажатия: ближние всплёскивают
    /// первыми, дальние — следом, и по фону расходится кольцо. Ни размах,
    /// ни длительность у фигурок не разнятся. Раньше разнились, и обе
    /// вразнобой: кольца за этим видно не было, по экрану шла рябь.
    ///
    /// Проход не «раздалась и вернулась», а ямка — гребень — ямка. Пока
    /// одна фигурка раздаётся, соседние по кольцу поджаты, и между ними
    /// остаётся зазор: обод читается ободом, а не сплошным утолщением, и
    /// фигурки не смыкаются боками.
    ///
    /// Отсюда и короткое окно всплеска: оно подобрано так, чтобы от ямки
    /// до гребня было примерно одно деление сетки. Будь окно длиннее,
    /// соседки попадали бы в одну фазу и раздавались бы разом.
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
        let amp = swing > 0 ? Metrics.popAmp : Metrics.popDip
        return CGFloat(1 + amp * swing)
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

    /// Полили вот здесь. Точка — в координатах окна: узор отсчитывается
    /// от верхнего левого угла экрана, других координат он не знает.
    func now(from point: CGPoint) {
        run?.cancel()
        origin = point
        start = Date()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.cheerSeconds))
            // Прервали ради новой волны — она уже идёт, и гасить нечего.
            guard !Task.isCancelled else { return }
            start = nil
        }
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

    /// Середина замера — отсюда и расходится волна.
    var middle: CGPoint { CGPoint(x: rect.midX, y: rect.midY) }
}

/// Фон как таковой: ровный цвет и узор поверх него.
///
/// Отдельным типом, потому что рисуется в двух местах — экраном и
/// подложкой под вырезом. Оба отсчитываются от верхнего левого угла
/// окна, поэтому узор в них стоит в одних и тех же точках.
private struct SproutField: View {
    var body: some View {
        ZStack {
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
                    TimelineView(.animation(paused: Cheer.shared.start == nil)) {
                        frame in
                        SproutPattern(wave: Cheer.shared.wave(at: frame.date),
                                      origin: Cheer.shared.origin)
                    }
                    .padding(-Metrics.parallax)
                    .offset(x: Tilt.shared.shift.width,
                            y: Tilt.shared.shift.height)
                }
                .clipped()
        }
    }
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
