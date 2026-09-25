import SwiftUI

/// Детали презентации «Итоги года»: живой фон, проявление текста по
/// буквам, счёт до числа, дождь из капель, кольцо года, часы полива,
/// месяцы и пьедестал.

/// Цвета слайдов — по сетке 3×3 для `MeshGradient`, от тёмного угла к
/// светлому: белый текст читается на любом.
enum RecapTheme {
    static func colors(_ slide: Recap.Slide) -> [Color] {
        switch slide {
        case .intro: mesh(0x06301C, 0x0B6B3A, 0x14A44D, 0x0A4D2E, 0x1FB86A,
                          0x6FE3A5, 0x0E7A45, 0x3CCB7F, 0xB8F5C9)
        case .waterings: mesh(0x04204A, 0x0A4C9E, 0x0B7BE0, 0x08356E, 0x1E90FF,
                              0x5BC0FF, 0x0C5CB8, 0x40A8F5, 0xA7E3FF)
        case .favorite: mesh(0x3A1600, 0x8A3A00, 0xD9731A, 0x6B2A00, 0xF08A24,
                             0xFFC15E, 0xA84E0C, 0xFFB03A, 0xFFE7A8)
        case .podium: mesh(0x2B0033, 0x6A0F7A, 0xB02BC4, 0x4C0A5C, 0xC743D9,
                           0xF28CFF, 0x84199A, 0xE56BF5, 0xFFD2FF)
        case .streak: mesh(0x3D0008, 0x8C0A1F, 0xE0243F, 0x660514, 0xFF4A5E,
                           0xFF9AA5, 0xB0122B, 0xFF7384, 0xFFD6DB)
        case .rhythm: mesh(0x0B0A2E, 0x2A1F7A, 0x4E3BD1, 0x191452, 0x6552F0,
                           0xA99CFF, 0x33279E, 0x8676FF, 0xD9D2FF)
        case .aim: mesh(0x002E2B, 0x00665F, 0x00A396, 0x004A44, 0x00BFAE,
                        0x6FF0E0, 0x007F75, 0x33D9C7, 0xB9FFF5)
        case .months: mesh(0x2E2400, 0x7A5E00, 0xC99A00, 0x544000, 0xE2BA00,
                           0xFFE066, 0x9C7700, 0xF5CF2E, 0xFFF4B8)
        case .garden: mesh(0x0A2A12, 0x1E6B2C, 0x39A845, 0x14461E, 0x4CC25A,
                           0xA6EE9E, 0x2B8A38, 0x7CDB7A, 0xDDFBD2)
        case .awards: mesh(0x1F1500, 0x5C3F00, 0xA87400, 0x3D2A00, 0xD49A0F,
                           0xFFD66B, 0x7A5500, 0xF2BA3A, 0xFFF0C2)
        case .outro: mesh(0x06301C, 0x0A4C9E, 0x14A44D, 0x08356E, 0x1FB86A,
                          0x5BC0FF, 0x0E7A45, 0x40A8F5, 0xB8F5C9)
        }
    }

    private static func mesh(_ hex: Int...) -> [Color] {
        hex.map { value in
            Color(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
        }
    }

    /// Шрифт огромных чисел и заголовков — круглый, чёрный: читается с
    /// другого конца комнаты, как в годовых итогах музыкальных сервисов.
    static func huge(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static let caption = Font.system(.headline, design: .rounded, weight: .bold)
    static let line = Font.system(.title3, design: .rounded, weight: .semibold)
}

/// Живой фон: сетка цветов 3×3, внутренние точки медленно плывут.
struct Backdrop: View {
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        TimelineView(.animation(paused: still)) { frame in
            MeshGradient(width: 3, height: 3,
                         points: points(frame.date.timeIntervalSinceReferenceDate),
                         colors: colors)
        }
        .ignoresSafeArea()
    }

    private func points(_ time: Double) -> [SIMD2<Float>] {
        func drift(_ phase: Double, _ reach: Double) -> Float {
            Float(sin(time * 0.45 + phase) * reach)
        }
        return [
            SIMD2(0, 0), SIMD2(0.5 + drift(0, 0.12), 0), SIMD2(1, 0),
            SIMD2(0, 0.5 + drift(1.3, 0.12)),
            SIMD2(0.5 + drift(2.1, 0.16), 0.5 + drift(3.4, 0.16)),
            SIMD2(1, 0.5 + drift(4.2, 0.12)),
            SIMD2(0, 1), SIMD2(0.5 + drift(5.6, 0.12), 1), SIMD2(1, 1),
        ]
    }
}

/// Текст проявляется по буквам: каждая всплывает из размытия чуть позже
/// предыдущей — волной слева направо.
struct Reveal: TextRenderer, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let glyphs = layout.flatMap { line in line.flatMap { run in run } }
        let count = max(glyphs.count, 1)
        for (index, glyph) in glyphs.enumerated() {
            let start = Double(index) / Double(count) * 0.55
            let t = min(max((progress - start) / 0.45, 0), 1)
            let eased = 1 - pow(1 - t, 3)
            var copy = context
            copy.opacity = eased
            copy.translateBy(x: 0, y: (1 - eased) * 16)
            if eased < 1 { copy.addFilter(.blur(radius: (1 - eased) * 6)) }
            copy.draw(glyph)
        }
    }
}

extension View {
    /// Проявить текст внутри волной; `shown` — пора ли.
    func revealed(_ shown: Bool, delay: Double = 0,
                  seconds: Double = 1.1) -> some View {
        textRenderer(Reveal(progress: shown ? 1 : 0))
            .animation(.easeOut(duration: seconds).delay(delay), value: shown)
    }
}

/// Число, которое набегает от нуля: SwiftUI сам ведёт промежуточные
/// значения, а вью только округляет.
struct CountUp: View, Animatable {
    var value: Double
    var format: (Int) -> String = { $0.formatted() }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(Int(value.rounded())))
            .monospacedDigit()
    }
}

/// Дождь из капель — тех же, что в узоре: падают с разной скоростью,
/// покачиваясь, и уходят за край.
struct DropRain: View {
    var count = 34

    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        TimelineView(.animation(paused: still)) { frame in
            let time = frame.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for index in 0 ..< count {
                    drop(index, at: time, in: size, into: &context)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drop(_ index: Int, at time: Double, in size: CGSize,
                      into context: inout GraphicsContext) {
        func unit(_ salt: Int) -> Double {
            Double((index &* 2_654_435_761 &+ salt &* 97_531) & 0xFFFF) / 65_535
        }
        let speed = 90 + unit(1) * 160
        let span = Double(size.height) + 80
        let fall = (time * speed + unit(2) * span)
            .truncatingRemainder(dividingBy: span)
        let y = CGFloat(fall - 40)
        let sway = sin(time * (0.8 + unit(4)) + unit(5) * 6) * 10
        let x = CGFloat(unit(3) * Double(size.width) + sway)
        let scale = CGFloat(0.35 + unit(6) * 0.55)
        let piece = SproutShapes.dropCentre
        var layer = context
        layer.opacity = 0.25 + unit(7) * 0.45
        layer.translateBy(x: x, y: y)
        layer.scaleBy(x: scale, y: scale)
        layer.translateBy(x: -piece.x, y: -piece.y)
        layer.fill(SproutShapes.drop, with: .color(.white))
    }
}

/// Год кольцом: точка на день, дни с поливом горят. Точки зажигаются по
/// ходу года, пока `progress` идёт от нуля к единице.
struct YearRing: View {
    let lit: Set<Int>
    let days: Int
    var progress: Double

    var body: some View {
        Canvas { context, size in
            let middle = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 8
            let shown = Int(Double(days) * progress)
            for day in 0 ..< days {
                let angle = CGFloat(day) / CGFloat(days) * 2 * .pi - .pi / 2
                let on = lit.contains(day) && day < shown
                let reach = radius - (on ? 0 : 6)
                let spot = CGPoint(x: middle.x + cos(angle) * reach,
                                   y: middle.y + sin(angle) * reach)
                let side: CGFloat = on ? 5 : 2.2
                let dot = Path(ellipseIn: CGRect(x: spot.x - side / 2,
                                                 y: spot.y - side / 2,
                                                 width: side, height: side))
                context.fill(dot, with: .color(.white.opacity(
                    on ? 1 : (day < shown ? 0.35 : 0.12))))
            }
        }
    }
}

/// Сутки циферблатом: столбик на час, самый длинный — час, когда поливают
/// чаще всего.
struct HourDial: View {
    let hours: [Int]
    let peak: Int?
    var progress: Double

    var body: some View {
        Canvas { context, size in
            let middle = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2
            let inner = outer * 0.42
            let most = CGFloat(max(hours.max() ?? 0, 1))
            for hour in 0 ..< 24 {
                let angle = CGFloat(hour) / 24 * 2 * .pi - .pi / 2
                let share = CGFloat(hours[hour]) / most * CGFloat(progress)
                let reach = inner + (outer - inner) * max(share, 0.04)
                var bar = Path()
                bar.move(to: CGPoint(x: middle.x + cos(angle) * inner,
                                     y: middle.y + sin(angle) * inner))
                bar.addLine(to: CGPoint(x: middle.x + cos(angle) * reach,
                                        y: middle.y + sin(angle) * reach))
                context.stroke(bar, with: .color(.white.opacity(
                    hour == peak ? 1 : 0.45)),
                    style: StrokeStyle(lineWidth: hour == peak ? 9 : 6,
                                       lineCap: .round))
            }
        }
    }
}

/// Двенадцать месяцев столбиками — растут по очереди, лучший горит.
struct MonthBars: View {
    let months: [Int]
    let best: Int?
    var progress: Double

    var body: some View {
        let most = Double(max(months.max() ?? 0, 1))
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0 ..< 12, id: \.self) { month in
                let lag = Double(month) / 12 * 0.5
                let grown = min(max((progress - lag) / 0.5, 0), 1)
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.white.opacity(month == best ? 1 : 0.5))
                        .frame(height: max(4, 150 * Double(months[month]) / most
                                                * grown))
                    Text(Self.initial(month))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 180, alignment: .bottom)
    }

    /// Первая буква месяца на языке приложения — «Я», «Ф», «М»…
    static func initial(_ month: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Lang.locale
        let symbols = calendar.veryShortStandaloneMonthSymbols
        return symbols.indices.contains(month) ? symbols[month] : ""
    }

    static func name(_ month: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Lang.locale
        let symbols = calendar.standaloneMonthSymbols
        return symbols.indices.contains(month) ? symbols[month].capitalized(with: Lang.locale) : ""
    }
}

/// Снимок растения из итогов — как на карточке: своё фото или рисунок вида.
struct StarPhoto: View {
    let star: Recap.Star

    var body: some View {
        if let shot = star.shot, let image = Snapshot.image(shot) {
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 28,
                                            style: .continuous))
        } else {
            Image(star.photo)
                .resizable()
                .scaledToFit()
        }
    }
}
