import SwiftUI

/// Партитура месяца — ноты полосой под планетарием: слева направо дни,
/// сверху вниз орбиты, от ближней, что поёт выше, к дальней. Полоса света —
/// показанный день: при проигрывании она бежит, и ноты за ней
/// вспыхивают; ведёшь пальцем — перематываешь машину времени. Парады —
/// столбиком нот и подсветкой дня.
struct OrreryScore: View {
    let crossings: [Orrery.Crossing]
    let count: Int
    let day: Double
    /// Пусто — перемотка закрыта: месяц играет.
    let seek: ((Double) -> Void)?

    @State private var width: CGFloat = 1

    private static let inset: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let rows = max(count, 1)
            let inset = Self.inset
            let width = size.width - inset * 2
            func x(_ day: Double) -> CGFloat {
                inset + width * CGFloat(min(max(day / Orrery.reach, 0), 1))
            }
            func y(_ rank: Int) -> CGFloat {
                let step = (size.height - inset * 2) / CGFloat(rows)
                return inset + step * (CGFloat(rank) + 0.5)
            }
            // Линейки — по неделе.
            for week in stride(from: 0.0, through: Orrery.reach, by: 7) {
                var line = Path()
                line.move(to: CGPoint(x: x(week), y: 0))
                line.addLine(to: CGPoint(x: x(week), y: size.height))
                context.stroke(line, with: .color(.white.opacity(0.08)),
                               lineWidth: 1)
            }
            // Парады — столбиком света на свой день.
            let days = Dictionary(grouping: crossings) {
                Int($0.day.rounded())
            }
            for (moment, notes) in days where notes.count >= 3 {
                let column = CGRect(x: x(Double(moment)) - 5, y: 0, width: 10,
                                    height: size.height)
                context.fill(Path(roundedRect: column, cornerRadius: 5),
                             with: .color(Palette.water.opacity(0.14)))
            }
            // Ноты: сыгранные — ярче, та, что звучит сейчас, — с ореолом.
            let dot = min(max((size.height - inset * 2) / CGFloat(rows) * 0.7,
                              3), 7)
            for note in crossings where note.day <= Orrery.reach {
                let at = CGPoint(x: x(note.day), y: y(note.rank))
                let since = day - note.day
                let played = since >= 0
                if played, since < 1.2 {
                    let glow = dot * (1.2 + CGFloat(since) * 3)
                    context.fill(
                        Path(ellipseIn: CGRect(x: at.x - glow, y: at.y - glow,
                                               width: glow * 2,
                                               height: glow * 2)),
                        with: .color(Palette.water.opacity(0.35 * (1 - since / 1.2))))
                }
                context.fill(
                    Path(ellipseIn: CGRect(x: at.x - dot / 2, y: at.y - dot / 2,
                                           width: dot, height: dot)),
                    with: .color(played ? Palette.water
                                 : .white.opacity(0.35)))
            }
            // Показанный день.
            let head = x(day)
            var beam = Path()
            beam.move(to: CGPoint(x: head, y: 0))
            beam.addLine(to: CGPoint(x: head, y: size.height))
            context.stroke(beam, with: .color(.white.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(height: 96)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            width = $0
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            guard let seek else { return }
            let share = (value.location.x - Self.inset)
                / max(width - Self.inset * 2, 1)
            let day = Double(min(max(share, 0), 1)) * Orrery.reach
            seek((day * 4).rounded() / 4)
        }, including: seek == nil ? .none : .all)
        .accessibilityElement()
        .accessibilityLabel("Партитура месяца")
        .accessibilityValue(Lang.format("%lld поливов", crossings.count))
    }
}
