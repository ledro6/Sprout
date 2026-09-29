import SwiftUI

/// Сцена под слайдами «Итогов» — одна на всю презентацию и во весь экран,
/// с вырезом и полоской внизу. Цвета слайдов перетекают друг в друга, а
/// фигурки узора, парящие над фоном, на каждой смене слайда взмывают
/// вихрем: листают вперёд — вверх, назад — вниз. Граница слайда нигде не
/// видна — меняется только то, что на нём написано.
struct RecapStage: View {
    let slide: Recap.Slide
    /// Номер слайда: по нему видно, вперёд листают или назад.
    let step: Int

    @Environment(\.accessibilityReduceMotion) private var still

    /// Смена цветов: откуда, куда и когда пошла.
    @State private var from: [SIMD3<Double>]
    @State private var to: [SIMD3<Double>]
    @State private var shift = 0.0

    /// Вихрь: сколько фигурки уже пролетели прежними вихрями, когда поднялся
    /// последний и предпоследний — тот ещё стихает — и куда дует.
    @State private var carried = 0.0
    @State private var gust = -100.0
    @State private var before = -100.0
    @State private var toward = 1.0

    /// Смена цветов, секунд.
    private static let morph = 0.9
    private static let count = 16
    /// Как далеко уносит вихрь — в долях высоты экрана — и как быстро.
    private static let reach = 0.6
    private static let pace = 0.28

    init(slide: Recap.Slide, step: Int) {
        self.slide = slide
        self.step = step
        let colors = RecapTheme.rgb(slide)
        _from = State(initialValue: colors)
        _to = State(initialValue: colors)
    }

    var body: some View {
        TimelineView(.animation(paused: still)) { frame in
            let time = frame.date.timeIntervalSinceReferenceDate
            ZStack {
                MeshGradient(width: 3, height: 3,
                             points: Backdrop.points(still ? 0 : time),
                             colors: palette(at: time))
                Canvas { context, size in
                    // Не `blown` — имя метода: локальное заслонило бы его.
                    let lift = travelled(at: time)
                    let gusty = blown(at: time)
                    for index in 0 ..< Self.count {
                        piece(index, time: time, lift: lift, blown: gusty,
                              in: size, into: &context)
                    }
                }
                // Сверху темнее — под полосками и крестиком; по краям лёгкая
                // виньетка: текст посередине читается на любом цвете.
                LinearGradient(colors: [.black.opacity(0.3), .clear],
                               startPoint: .top,
                               endPoint: UnitPoint(x: 0.5, y: 0.25))
                RadialGradient(colors: [.clear, .black.opacity(0.22)],
                               center: .center, startRadius: 160,
                               endRadius: 620)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: step) { old, new in
            let now = Date().timeIntervalSinceReferenceDate
            // Цвета — от тех, что на экране сейчас: смена посреди смены не
            // прыгает.
            from = still ? RecapTheme.rgb(slide) : mix(at: now)
            to = RecapTheme.rgb(slide)
            shift = now
            guard !still else { return }
            carried = travelled(at: now)
            before = gust
            gust = now
            toward = new >= old ? 1 : -1
        }
    }

    // MARK: - Цвета

    private func mix(at time: Double) -> [SIMD3<Double>] {
        guard from.count == to.count else { return to }
        let raw = min(max((time - shift) / Self.morph, 0), 1)
        let share = raw * raw * (3 - 2 * raw)
        return zip(from, to).map { old, new in old + (new - old) * share }
    }

    private func palette(at time: Double) -> [Color] {
        mix(at: time).map { Color(red: $0.x, green: $0.y, blue: $0.z) }
    }

    // MARK: - Вихрь

    /// Путь вихря от нуля до `reach`: трогается плавно, разгоняется и
    /// тормозит — без рывка ни в начале, ни в конце.
    private func push(_ since: Double) -> Double {
        guard since > 0 else { return 0 }
        let t = since / Self.pace
        return 1 - (1 + t) * exp(-t)
    }

    /// Сколько вихри унесли фигурки к мигу `time`, в долях высоты.
    private func travelled(at time: Double) -> Double {
        carried + toward * Self.reach * push(time - gust)
    }

    /// Сила вихря: нарастает, пока он дует, и стихает. Прошлый стихает
    /// своим ходом — новый не обрывает его щелчком.
    private func blown(at time: Double) -> Double {
        func pulse(_ since: Double) -> Double {
            guard since > 0 else { return 0 }
            let t = since / Self.pace
            return t * exp(1 - t)
        }
        return min(pulse(time - gust) + pulse(time - before), 1.4)
    }

    private func piece(_ index: Int, time: Double, lift: Double,
                       blown: Double, in size: CGSize,
                       into context: inout GraphicsContext) {
        func unit(_ salt: Int) -> Double { Scatter.unit(index, salt) }
        let pieces = SproutShapes.pieces
        let shape = pieces[index % pieces.count]
        let height = Double(size.height)
        let span = height + 160
        // Своё неспешное всплытие и то, что унёс вихрь, — по кругу.
        let rise = time * (12 + unit(1) * 20) + unit(2) * span
            + lift * height * (0.7 + unit(8) * 0.6)
        let wrapped = rise.truncatingRemainder(dividingBy: span)
        let climb = wrapped < 0 ? wrapped + span : wrapped
        let sway = sin(time * 0.5 + unit(4) * 6) * 18
            + sin(time * 2.4 + unit(9) * 6) * 26 * blown
        var layer = context
        layer.opacity = (0.1 + unit(6) * 0.14) * (1 + 1.6 * blown)
        layer.translateBy(x: CGFloat(unit(3) * Double(size.width) + sway),
                          y: CGFloat(height + 80 - climb))
        layer.rotate(by: .radians(sin(time * 0.4 + unit(7) * 6) * 0.5
                                  + (unit(10) - 0.5) * 2 * blown))
        let scale = CGFloat((0.45 + unit(5) * 0.7) * (1 + 0.3 * blown))
        layer.scaleBy(x: scale, y: scale)
        layer.translateBy(x: -shape.centre.x, y: -shape.centre.y)
        layer.fill(shape.path, with: .color(.white))
    }
}

/// Слайд целиком на любом телефоне: содержимое меряется в свой рост и, если
/// выше места, ужимается целиком — не обрезается и не налезает на полоски.
struct RecapFit<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var natural: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let room = geometry.size.height
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: geometry.size.width, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height }
                    action: { natural = $0 }
                .scaleEffect(natural > room ? room / natural : 1,
                             anchor: .leading)
                .frame(width: geometry.size.width, height: room,
                       alignment: .leading)
        }
    }
}

/// Смена слайда: написанное тает в размытии и уходит вверх, новое всплывает
/// снизу. Фон общий — сцена — и не двигается.
private struct Drift: ViewModifier {
    let gone: Double
    let rise: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: 16 * gone)
            .opacity(1 - gone)
            .offset(y: rise * gone)
    }
}

extension AnyTransition {
    static var recapDrift: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: Drift(gone: 1, rise: 40),
                                 identity: Drift(gone: 0, rise: 40)),
            removal: .modifier(active: Drift(gone: 1, rise: -30),
                               identity: Drift(gone: 0, rise: -30)))
    }
}
