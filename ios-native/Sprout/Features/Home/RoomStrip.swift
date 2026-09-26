import SwiftUI
import UIKit

/// Страница главной: комната или «Новая комната» за последней.
enum HomeLeaf: Hashable {
    case room(String)
    case fresh
}

/// Где сейчас листание главной и насколько прокручена каждая страница.
/// Меняется каждый кадр жеста, поэтому живёт не в состоянии экрана, а в
/// стороне: будит только шапку, которая его читает, а полки стоят.
@Observable
final class Glide {
    /// Положение листания в страницах: 0 — первая комната, дробное посреди
    /// жеста.
    private(set) var at: CGFloat = 0

    /// Прокрутка каждой страницы от верха её содержимого.
    private(set) var lifts: [HomeLeaf: CGFloat] = [:]

    /// В какую сторону растут номера страниц: +1 — следующая правее, −1 —
    /// левее, как справа налево. Сначала — по направлению письма, дальше —
    /// по самим страницам: две видимые разом говорят это наверняка, как бы
    /// SwiftUI ни зеркалил ленту.
    @ObservationIgnored private var toward: CGFloat?

    /// Прошлое сообщение — чтобы сверить с соседом.
    @ObservationIgnored private var last: (page: Int, x: CGFloat)?

    /// Страница сообщает, где стоит относительно ленты. Страницы одной
    /// ширины идут подряд, так что положение целиком знает любая видимая.
    func track(page: Int, frame: CGRect, flipped: Bool) {
        let width = frame.width
        guard width > 0 else { return }
        if let last, last.page != page {
            let apart = CGFloat(page - last.page)
            let gap = frame.minX - last.x
            // Сосед сообщил в том же кадре: расстояние — ровно шаг.
            if abs(abs(gap) - abs(apart) * width) < 1 {
                toward = gap / apart > 0 ? 1 : -1
            }
        }
        last = (page, frame.minX)
        let sign = toward ?? (flipped ? -1 : 1)
        let now = CGFloat(page) - sign * frame.minX / width
        if abs(now - at) > 0.0005 { at = now }
    }

    func track(_ leaf: HomeLeaf, lift: CGFloat) {
        if lifts[leaf] != lift { lifts[leaf] = lift }
    }

    /// Ушедшие страницы — из журнала вон.
    func keep(_ leaves: [HomeLeaf]) {
        let alive = Set(leaves)
        guard lifts.keys.contains(where: { !alive.contains($0) }) else { return }
        lifts = lifts.filter { alive.contains($0.key) }
    }

    /// Прокрутка между двумя соседними страницами — по доле листания: шапка
    /// переходит от одной к другой вместе с пальцем, а не щелчком.
    func lift(across leaves: [HomeLeaf]) -> CGFloat {
        guard !leaves.isEmpty else { return 0 }
        let place = min(max(at, 0), CGFloat(leaves.count - 1))
        let low = Int(place.rounded(.down))
        let high = min(low + 1, leaves.count - 1)
        let share = place - CGFloat(low)
        let from = lifts[leaves[low]] ?? 0
        let to = lifts[leaves[high]] ?? 0
        return from + (to - from) * share
    }
}

/// Лента комнат над полкой — барабан, а не список. Имена написаны на нём
/// одно за другим: текущее — на плоской грани, прямое, следующее — сразу за
/// ним, на скруглении: буквы уходят по дуге, сжимаются и мельчают с
/// глубиной (`Drum`), а за последней комнатой — «Новая комната». Листают —
/// барабан проворачивается: выглядывающее имя выезжает на грань и
/// распрямляется, текущее загибается влево и тает. Путь короткий — ширина
/// одного имени, а не экрана. `at` — положение листания страниц, дробное
/// посреди жеста.
///
/// Пальца лента не берёт: листают страницы под ней, и смахнуть можно прямо
/// по названию. Нажатие на выглядывающее имя листает к нему.
struct RoomStrip: View {
    let names: [String]

    let at: CGFloat

    let size: CGFloat

    /// Сколько с конца занято кнопками: поднявшись к ним, лента ужимается.
    var trail: CGFloat = 0

    let go: (Int) -> Void

    @Environment(\.layoutDirection) private var direction

    @State private var width: CGFloat = 0

    /// Комнаты и «Новая комната».
    private var count: Int { names.count + 1 }

    private var current: Int { min(max(Int(at.rounded()), 0), count - 1) }

    private var flipped: Bool { direction == .rightToLeft }

    /// Видимая часть ленты — без кнопок.
    private var span: CGFloat { max(width - trail, 1) }

    /// Шире — ужимается: имя целиком помещается в ленту.
    private var widest: CGFloat {
        max(span - Metrics.contentMargin - Metrics.roomTail, 40)
    }

    var body: some View {
        let widths = (0 ..< count).map { min(measure($0), widest) }
        // Где на развёртке барабана начинается каждое имя и докуда он
        // провёрнут сейчас: между страницами — пропорционально жесту.
        let starts = widths.indices.map { index in
            widths.prefix(index).reduce(0) { $0 + $1 + Metrics.roomGap }
        }
        let turned = spot(starts, at)
        let step = spot(widths.map { $0 + Metrics.roomGap }, at)
        // Плоская грань — под текущее имя, посреди жеста — между двумя.
        // Скругление за ней — на всё свободное место до кнопок: соседнее имя
        // целиком помещается на дугу и прячется за край у конца ленты.
        let flat = spot(widths, at)
        let ahead = max(span - Metrics.contentMargin - flat, size * 2.5)
        // Внутри ленты — слева направо, а зеркалим сами: сдвиги, изгиб и
        // края считаются числами, и справа налево они идут от правого края.
        ZStack(alignment: .leading) {
            ForEach(0 ..< count, id: \.self) { index in
                let along = starts[index] - turned
                let away = along / max(step, 1)
                // Дальше соседей не рисуем: их всё равно не видно.
                if away > -1, away < 2 {
                    title(index, bend: Drum(
                        along: along, flat: flat, ahead: ahead,
                        behind: size * Metrics.roomCurl,
                        width: widths[index], flipped: flipped))
                        .frame(width: widths[index], alignment: .leading)
                        .environment(\.layoutDirection, direction)
                        .blur(radius: haze(away))
                        .opacity(fade(away))
                        .offset(x: left(along, widths[index]))
                }
            }
        }
        .frame(width: span, alignment: .leading)
        .frame(maxHeight: .infinity)
        .mask { edges }
        .allowsHitTesting(false)
        .overlay(alignment: .leading) {
            next(widths: widths, starts: starts, turned: turned)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width }
            action: { width = $0 }
        // Для VoiceOver лента — одна регулируемая строка: вверх-вниз
        // листает комнаты.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Комната"))
        .accessibilityValue(Text(name(current)))
        .accessibilityAdjustableAction { turn in
            switch turn {
            case .increment:
                if current + 1 < count { go(current + 1) }
            case .decrement:
                if current > 0 { go(current - 1) }
            @unknown default:
                break
            }
        }
    }

    /// Значение между страницами — по доле жеста.
    private func spot(_ values: [CGFloat], _ at: CGFloat) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        let place = min(max(at, 0), CGFloat(values.count - 1))
        let low = Int(place.rounded(.down))
        let high = min(low + 1, values.count - 1)
        let share = place - CGFloat(low)
        return values[low] + (values[high] - values[low]) * share
    }

    /// Левый край имени в ленте. Справа налево — то же от правого края.
    private func left(_ along: CGFloat, _ wide: CGFloat) -> CGFloat {
        let from = Metrics.contentMargin + along
        return flipped ? span - from - wide : from
    }

    /// Ширина имени по шрифту, а не по вёрстке: вёрстку каждый кадр жеста
    /// ждать нельзя.
    private func measure(_ index: Int) -> CGFloat {
        let font = UIFont.systemFont(ofSize: size, weight: .semibold)
        let text = name(index) as NSString
        let wide = text.size(withAttributes: [.font: font]).width
        // У «Новой комнаты» впереди плюс.
        return ceil(index < names.count ? wide : wide + size * 1.4)
    }

    private func name(_ index: Int) -> String {
        index < names.count ? names[index] : Lang.text("Новая комната")
    }

    /// Изгиб — у самого текста: плюс «Новой комнаты» стоит у ближнего края,
    /// там дуга едва начинается, и ему гнуться незачем.
    @ViewBuilder
    private func title(_ index: Int, bend: Drum) -> some View {
        Group {
            if index < names.count {
                Text(names[index])
                    .textRenderer(bend)
            } else {
                Label {
                    Text("Новая комната")
                        .textRenderer(bend.led(by: size * 1.4))
                } icon: {
                    Image(systemName: "plus")
                }
            }
        }
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(Palette.accent)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// Текущее — резкое; соседи размыты тем сильнее, чем дальше повёрнуты.
    /// В пунктах от кегля: доросшая подпись размывается так же.
    private func haze(_ away: CGFloat) -> CGFloat {
        size * Metrics.roomBlur * min(abs(away), 1.3)
    }

    /// Следующее — вполсилы, дальше — гаснет; уходящее гаснет быстрее, чем
    /// уезжает.
    private func fade(_ away: CGFloat) -> Double {
        guard away >= 0 else {
            return Double(max(1 + away * Metrics.roomLeave, 0))
        }
        let near = 1 - Metrics.roomDim * min(away, 1)
        let far = min(max((1.9 - away) / 0.7, 0), 1)
        return Double(near * far)
    }

    /// Края: у начала уходящее имя тает в поле, у конца длинное следующее
    /// гаснет к краю экрана, а не обрывается.
    private var edges: some View {
        let enter = min(Metrics.contentMargin / span, 0.5)
        let leave = max(1 - Metrics.roomTail / span, enter)
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: enter),
                .init(color: .black, location: leave),
                .init(color: .clear, location: 1),
            ],
            startPoint: flipped ? .trailing : .leading,
            endPoint: flipped ? .leading : .trailing)
    }

    /// Выглядывающее имя нажимается — листаем к нему.
    @ViewBuilder
    private func next(widths: [CGFloat], starts: [CGFloat],
                      turned: CGFloat) -> some View {
        let index = current + 1
        if index < count {
            let wide = min(widths[index], max(span - Metrics.contentMargin
                                              - (starts[index] - turned), 0))
            Button { go(index) } label: {
                Color.clear
                    .frame(width: max(wide, 1))
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: left(starts[index] - turned, max(wide, 1)))
            .accessibilityHidden(true)
        }
    }
}

/// Имя на барабане ленты комнат. Плоская грань — там, где стоит текущая
/// комната: на ней буквы прямые. За гранью барабан скругляется, и буква
/// уходит по дуге: чем дальше, тем круче повёрнута к нам боком — уже, мельче
/// с глубиной и бледнее, а за четверть оборота прячется совсем. Листают —
/// имя переезжает с дуги на грань и распрямляется. Сдвигается и сжимается
/// каждая буква своя, поэтому слово гнётся, а не поворачивается дощечкой.
struct Drum: TextRenderer {
    /// Начало подписи на развёртке барабана — от начала грани.
    var along: CGFloat
    /// Ширина грани.
    var flat: CGFloat
    /// Радиус скругления за гранью и перед ней.
    var ahead: CGFloat
    var behind: CGFloat
    /// Ширина подписи: справа налево развёртка идёт от её правого края.
    var width: CGFloat = 0
    var flipped = false
    /// Сколько от начала подписи до текста: у «Новой комнаты» впереди плюс.
    var lead: CGFloat = 0

    /// Глаз далеко от барабана — во столько радиусов: мельчают буквы
    /// мягко, а не проваливаются.
    static let eye: CGFloat = 2.5

    func led(by lead: CGFloat) -> Drum {
        var copy = self
        copy.lead = lead
        copy.width -= lead
        return copy
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                for slice in run {
                    let box = slice.typographicBounds.rect
                    let local = flipped ? width - box.midX : box.midX
                    let at = along + lead + local
                    guard let spot = place(at) else { continue }
                    var glyph = context
                    glyph.opacity = Double(spot.near * spot.near)
                    let shift = (spot.x - at) * (flipped ? -1 : 1)
                    glyph.translateBy(x: box.midX + shift, y: box.midY)
                    glyph.scaleBy(x: spot.squeeze * spot.near, y: spot.near)
                    glyph.translateBy(x: -box.midX, y: -box.midY)
                    glyph.draw(slice)
                }
            }
        }
    }

    /// Где буква на экране по ленте, насколько сжата поперёк и насколько
    /// близко (1 — на грани). За четвертью оборота её не видно.
    func place(_ at: CGFloat) -> (x: CGFloat, squeeze: CGFloat, near: CGFloat)? {
        if at > flat {
            guard let bent = Self.arc(at - flat, radius: ahead) else {
                return nil
            }
            return (flat + bent.x, bent.squeeze, bent.near)
        }
        if at < 0 {
            guard let bent = Self.arc(-at, radius: behind) else { return nil }
            return (-bent.x, bent.squeeze, bent.near)
        }
        return (at, 1, 1)
    }

    /// Путь по дуге — в сдвиг на экране, сжатие и близость.
    static func arc(_ run: CGFloat, radius: CGFloat)
        -> (x: CGFloat, squeeze: CGFloat, near: CGFloat)? {
        let angle = run / max(radius, 1)
        guard angle < .pi / 2 else { return nil }
        let depth = 1 - cos(angle)
        let near = 1 / (1 + depth / eye)
        return (radius * sin(angle) * near, cos(angle), near)
    }
}
