import SwiftUI
import WidgetKit

// Sprout на циферблате: сколько растений просят воды и кто первый. Сад —
// тот, что часам прислал телефон (`Wrist`); перерисовку зовёт приложение
// на часах, когда получает сад или поливает.

@main
struct SproutWatchWidgets: WidgetBundle {
    var body: some Widget {
        ThirstComplication()
    }
}

struct WristEntry: TimelineEntry {
    let date: Date
    let wrist: Wrist?

    var thirsty: [Wrist.Pot] { wrist?.thirsty ?? [] }

    /// Самый сухой — его влажность на шкале.
    var driest: Wrist.Pot? { wrist?.pots.first }

    static func now() -> WristEntry {
        WristEntry(date: .now, wrist: Wrist.read())
    }

    /// Для галереи циферблатов: сада ещё может не быть.
    static var sample: WristEntry {
        WristEntry(date: .now, wrist: Wrist(pots: [
            Wrist.Pot(id: "a", name: Lang.text("Спатифиллум"), room: "",
                      moisture: 0.12, period: 7),
            Wrist.Pot(id: "b", name: Lang.text("Фиалка"), room: "",
                      moisture: 0.31, period: 4),
            Wrist.Pot(id: "c", name: Lang.text("Монстера"), room: "",
                      moisture: 0.7, period: 9),
        ], sent: .now))
    }
}

struct WristProvider: TimelineProvider {
    func placeholder(in context: Context) -> WristEntry { .sample }

    func getSnapshot(in context: Context,
                     completion: @escaping (WristEntry) -> Void) {
        let now = WristEntry.now()
        completion(context.isPreview && now.wrist == nil ? .sample : now)
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<WristEntry>) -> Void) {
        completion(Timeline(entries: [WristEntry.now()], policy: .never))
    }
}

struct ThirstComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WristThirst", provider: WristProvider()) {
            entry in
            ComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Кто хочет пить")
        .description("Сколько растений просят воды и кто первый.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner,
                            .accessoryRectangular, .accessoryInline])
    }
}

struct ComplicationView: View {
    let entry: WristEntry

    @Environment(\.widgetFamily) private var family

    private static let water = Color(red: 0.25, green: 0.62, blue: 1)

    /// «Просят воды: 3» или «Все политы».
    private var line: String {
        entry.thirsty.isEmpty ? Lang.text("Все политы")
            : Lang.format("Просят воды: %lld", entry.thirsty.count)
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner: corner
        case .accessoryInline: inline
        default: rectangular
        }
    }

    /// Шкала — влажность самого сухого, число — сколько просят воды.
    private var circular: some View {
        Gauge(value: entry.driest?.moisture ?? 1) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(entry.thirsty.count.formatted())
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Self.water)
        .accessibilityLabel(line)
    }

    private var corner: some View {
        Image(systemName: "drop.fill")
            .font(.title2)
            .foregroundStyle(Self.water)
            .widgetAccentable()
            .widgetLabel {
                Text(line)
            }
    }

    private var inline: some View {
        Label(line, systemImage: "drop.fill")
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Кого полить", systemImage: "drop.fill")
                .font(.headline)
                .foregroundStyle(Self.water)
                .widgetAccentable()
            if entry.wrist == nil {
                Text("Откройте Sprout — и сад появится здесь.")
                    .font(.caption2)
                    .lineLimit(2)
            } else if entry.thirsty.isEmpty {
                Text("Все политы")
                    .font(.caption)
            } else {
                ForEach(entry.thirsty.prefix(2)) { pot in
                    Text(Lang.format("%1$@ · %2$@", pot.name,
                                     Lang.format("%lld%%", pot.percent)))
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
