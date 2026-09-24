import SwiftUI

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

/// Лента комнат над полкой — вместо меню. Текущая комната крупно у края, за
/// ней выглядывает следующая, размытая и гаснущая к краю экрана, а за
/// последней — «Новая комната». Лента идёт за пальцем: `at` — положение
/// листания страниц, дробное посреди жеста, — и выглядывающая комната на
/// ходу набирает резкость, а уходящая тает в размытие.
///
/// Пальца лента не берёт: листают страницы под ней, и смахнуть можно прямо
/// по названию. Нажатие на выглядывающую комнату листает к ней.
struct RoomStrip: View {
    let names: [String]

    let at: CGFloat

    let size: CGFloat

    /// Сколько с конца занято кнопками: поднявшись к ним, лента ужимается.
    var trail: CGFloat = 0

    /// Сколько видно от следующей комнаты.
    var peek: CGFloat = Metrics.roomPeek

    let go: (Int) -> Void

    @Environment(\.layoutDirection) private var direction

    @State private var width: CGFloat = 0

    /// Комнаты и «Новая комната».
    private var count: Int { names.count + 1 }

    private var current: Int { min(max(Int(at.rounded()), 0), count - 1) }

    private var flipped: Bool { direction == .rightToLeft }

    /// Видимая часть ленты — без кнопок.
    private var span: CGFloat { max(width - trail, 1) }

    /// Шаг между соседями: от следующей комнаты видно ровно `peek`.
    private var step: CGFloat {
        max(span - Metrics.contentMargin - peek, 1)
    }

    var body: some View {
        // Внутри ленты — слева направо, а зеркалим сами: сдвиги и края
        // считаются числами, и справа налево они должны идти от правого
        // края, а не прыгать вслед за системой.
        ZStack(alignment: .leading) {
            ForEach(0 ..< count, id: \.self) { index in
                let away = CGFloat(index) - at
                // Дальше соседей не рисуем: их всё равно не видно.
                if away > -1, away < 2 {
                    title(index)
                        // Длинное имя ужимается раньше, чем доберётся до
                        // выглядывающего соседа.
                        .frame(width: wide, alignment: .leading)
                        .environment(\.layoutDirection, direction)
                        .blur(radius: haze(away))
                        .opacity(fade(away))
                        .offset(x: place(away))
                }
            }
        }
        .frame(width: span, alignment: .leading)
        .frame(maxHeight: .infinity)
        .mask { edges }
        .allowsHitTesting(false)
        .overlay(alignment: flipped ? .leading : .trailing) { next }
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

    /// Ширина места под имя.
    private var wide: CGFloat { max(step - Metrics.roomGap, 1) }

    /// Левый край имени в ленте: текущее — у поля, следующее — на шаг
    /// дальше. Справа налево — то же от правого края.
    private func place(_ away: CGFloat) -> CGFloat {
        let from = Metrics.contentMargin + away * step
        return flipped ? span - from - wide : from
    }

    private func name(_ index: Int) -> String {
        index < names.count ? names[index] : Lang.text("Новая комната")
    }

    @ViewBuilder
    private func title(_ index: Int) -> some View {
        Group {
            if index < names.count {
                Text(names[index])
            } else {
                Label("Новая комната", systemImage: "plus")
            }
        }
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(Palette.accent)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// Текущая — резкая; соседи размыты тем сильнее, чем дальше от своего
    /// места. В пунктах от кегля: доросшая подпись размывается так же.
    private func haze(_ away: CGFloat) -> CGFloat {
        size * Metrics.roomBlur * min(abs(away), 1)
    }

    /// Выглядывающая — вполсилы; уходящая гаснет быстрее, чем уезжает.
    private func fade(_ away: CGFloat) -> Double {
        guard away >= 0 else {
            return Double(max(1 + away * Metrics.roomLeave, 0))
        }
        let near = 1 - Metrics.roomDim * min(away, 1)
        return Double(near * min(max(2 - away, 0), 1))
    }

    /// Края: у начала уходящая комната тает в поле, у конца выглядывающая
    /// гаснет к краю — видно начало имени, а не обрубок.
    private var edges: some View {
        let enter = min(Metrics.contentMargin / span, 0.5)
        let leave = max(1 - peek / span, enter)
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

    /// Выглядывающая комната нажимается — листаем к ней.
    @ViewBuilder
    private var next: some View {
        if current + 1 < count {
            Button { go(current + 1) } label: {
                Color.clear
                    .frame(width: peek + Metrics.roomGap)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }
}

/// Плашка под чёлкой: логотип и название. Размеры из макета.
struct SproutBadge: View {
    var body: some View {
        HStack(spacing: 2.5) {
            SproutLogo()
            Text("Sprout")
                .font(Typography.wordmark)
                // Чёрный в обеих темах: плашка светло-зелёная всегда — это
                // знак, а не поверхность.
                .foregroundStyle(.black)
        }
        .padding(.leading, 6.9)
        .padding(.trailing, 7.6)
        .frame(height: 28)
        .background(Palette.greenSoft, in: .capsule)
    }
}

/// Подменю «Переехать» — одно на меню карточки и экрана растения.
struct MoveMenu: View {
    let current: String?
    let rooms: [String]

    let move: (String) -> Void

    let ask: () -> Void

    var body: some View {
        Menu {
            ForEach(rooms.filter { $0 != current }, id: \.self) { name in
                Button(name) { move(name) }
            }
            Divider()
            Button { ask() } label: {
                Label("Новая комната…", systemImage: "plus")
            }
        } label: {
            Label("Переехать", systemImage: "door.left.hand.open")
        }
    }
}
