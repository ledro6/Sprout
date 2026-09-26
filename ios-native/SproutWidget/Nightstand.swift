import SwiftUI
import WidgetKit

// «Сад на тумбочке» — для режима ожидания: телефон заряжается боком, и
// виджет видно через комнату. Крупно — сколько растений ждут воды и кто
// первый; ниже грядка: в каждом горшке вода до своей влажности, а лист над
// ним никнет, когда земля сохнет. Кадры на ночь вперёд уже посчитаны —
// горшки пустеют сами, без приложения. Ночью система красит виджет в
// красный, и тогда цвета нет — хватает яркости.

struct NightstandWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Nightstand", provider: Provider()) { entry in
            NightstandView(entry: entry)
                .containerBackground(for: .widget) { Leafy() }
        }
        .configurationDisplayName("Сад на тумбочке")
        .description("Крупно, чтобы было видно через комнату: кто ждёт воды и как сохнет земля. Для режима ожидания.")
        .supportedFamilies([.systemSmall])
    }
}

struct NightstandView: View {
    let entry: Glance

    @Environment(\.widgetRenderingMode) private var mode

    /// В маленький виджет встаёт шесть горшков: самые сухие, но в порядке
    /// сада — чтобы за ночь горшки не менялись местами.
    private var bed: [Sprig] {
        let driest = Set(entry.sprigs.prefix(Self.pots).map(\.id))
        return entry.garden.filter { driest.contains($0.id) }
    }

    static let pots = 6

    private var colored: Bool { mode == .fullColor }

    var body: some View {
        if !entry.ready {
            Blank(icon: "leaf", line: "Откройте Sprout — и сад появится здесь.")
        } else if entry.sprigs.isEmpty {
            Blank(icon: "leaf", line: "В саду пока пусто.")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                headline
                Spacer(minLength: 4)
                StandRow(sprigs: bed, colored: colored)
            }
        }
    }

    @ViewBuilder
    private var headline: some View {
        let waiting = entry.thirsty.count
        if waiting == 0 {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(colored ? Tone.leaf : .primary)
                    .widgetAccentable()
                Text("Все политы")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(waiting.formatted())
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Image(systemName: "drop.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(colored ? Tone.water : .primary)
                        .widgetAccentable()
                }
                if let first = entry.thirsty.first {
                    Text(Lang.format("%1$@ · %2$@", first.name, first.percent))
                        .font(.system(.footnote, design: .rounded,
                                      weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Lang.format("Просят воды: %lld", waiting))
        }
    }
}

/// Грядка: горшок на растение, вода в нём — до влажности, над ним лист.
private struct StandRow: View {
    let sprigs: [Sprig]
    let colored: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(sprigs) { sprig in
                VStack(spacing: 0) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colored ? Tone.leaf : .primary)
                        .rotationEffect(.degrees(droop(sprig.moisture)),
                                        anchor: .bottomLeading)
                        .offset(x: 3)
                        .frame(height: 15, alignment: .bottom)
                    WaterPot(level: sprig.moisture, water: water(sprig))
                        .frame(width: 18, height: 24)
                }
                .frame(maxWidth: 26)
                .accessibilityElement()
                .accessibilityLabel(Lang.format("%1$@ · %2$@", sprig.name,
                                                sprig.percent))
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Мокрый лист смотрит вверх, сухой ложится набок.
    private func droop(_ moisture: Double) -> Double {
        -15 + (1 - min(max(moisture, 0), 1)) * 80
    }

    private func water(_ sprig: Sprig) -> Color {
        guard colored else { return .primary }
        return sprig.thirst == .calm ? Tone.water : Tone.of(sprig.thirst)
    }
}

/// Горшок с водой до `level`: бортик сверху, стенки сужаются к донцу.
private struct WaterPot: View {
    let level: Double
    let water: Color

    var body: some View {
        GeometryReader { box in
            let height = box.size.height
            ZStack(alignment: .bottom) {
                PotShape().fill(.primary.opacity(0.14))
                Rectangle()
                    .fill(water)
                    .frame(height: height * (1 - PotShape.rim)
                           * min(max(level, 0), 1))
                    .widgetAccentable()
            }
            .clipShape(PotShape())
            .overlay(PotShape().stroke(.primary.opacity(0.4), lineWidth: 1))
        }
        .accessibilityHidden(true)
    }
}

private struct PotShape: Shape {
    /// Доля бортика по высоте.
    static let rim = 0.2

    func path(in rect: CGRect) -> Path {
        let lip = rect.height * Self.rim
        let taper = rect.width * 0.16
        let round = min(lip * 0.4, 2)
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: rect.minX, y: rect.minY, width: rect.width,
                       height: lip),
            cornerSize: CGSize(width: round, height: round))
        path.move(to: CGPoint(x: rect.minX + taper * 0.3, y: rect.minY + lip))
        path.addLine(to: CGPoint(x: rect.maxX - taper * 0.3,
                                 y: rect.minY + lip))
        path.addLine(to: CGPoint(x: rect.maxX - taper, y: rect.maxY - round))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - taper - round,
                                      y: rect.maxY),
                          control: CGPoint(x: rect.maxX - taper, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + taper + round, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + taper,
                                      y: rect.maxY - round),
                          control: CGPoint(x: rect.minX + taper, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview(as: .systemSmall) {
    NightstandWidget()
} timeline: {
    Glance.sample
}
