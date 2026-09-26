import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// Виджеты Sprout: «Кого полить» на экран «Домой» — с кнопкой «Полить» у
// каждого растения, — сводка на экран блокировки и «Сад на тумбочке» для
// режима ожидания. Сад читается из общей папки (`Store`), полив идёт через
// `WaterFromWidget` — ту же команду знает и приложение. Живые действия — в
// `LiveViews.swift`.

@main
struct SproutWidgets: WidgetBundle {
    var body: some Widget {
        ThirstWidget()
        ThirstGlance()
        NightstandWidget()
        RoundLive()
        TripLive()
    }
}

/// Растение в виджете — только то, что показать.
struct Sprig: Identifiable, Hashable {
    let id: String
    let name: String
    let room: String
    let moisture: Double
    let label: String
    let thumb: URL?

    var percent: String { Lang.format("%lld%%", Int((moisture * 100).rounded())) }

    var thirst: Thirst { Thirst(moisture: moisture) }
}

struct Glance: TimelineEntry {
    let date: Date
    /// От самого сухого.
    let sprigs: [Sprig]
    /// Сад на диске есть — приложение хоть раз открывали.
    let ready: Bool
    /// Тот же сад в порядке комнат — для грядки на тумбочке: горшки стоят на
    /// своих местах, а не перебегают, когда один обгонит другого.
    var garden: [Sprig] = []

    var thirsty: [Sprig] { sprigs.filter { $0.thirst != .calm } }

    static func now() -> Glance { ahead(from: .now, steps: 1)[0] }

    /// Сад сейчас и дальше, шаг за шагом: пока приложение закрыто, земля
    /// сохнет, и виджет проживает ночь сам — без приложения и без сети.
    static func ahead(from start: Date, steps: Int,
                      every step: TimeInterval = 1_800) -> [Glance] {
        guard let state = Store.read() else {
            return [Glance(date: start, sprigs: [], ready: false)]
        }
        // Сроки — с теми же поправками на время года и погоду, что в
        // приложении.
        Season.stretch = state.season ?? 1
        return (0 ..< max(steps, 1)).map { index in
            let date = start.addingTimeInterval(Double(index) * step)
            Climate.settle(state.climate, on: true, now: date)
            let garden = state.rooms(at: date).flatMap { room in
                room.plants.map { plant in
                    Sprig(id: plant.id, name: plant.name, room: room.name,
                          moisture: plant.moisture, label: plant.wateringLabel,
                          thumb: Store.thumb(for: plant))
                }
            }
            return Glance(date: date,
                          sprigs: garden.sorted { $0.moisture < $1.moisture },
                          ready: true, garden: garden)
        }
    }

    /// Для галереи виджетов: сада ещё может не быть, а показать виджет
    /// надо живым.
    static var sample: Glance {
        let sprigs = [
            Sprig(id: "a", name: Lang.text("Спатифиллум"), room: "",
                  moisture: 0.08, label: Plant.wateringLabel(days: 0),
                  thumb: nil),
            Sprig(id: "b", name: Lang.text("Фиалка"), room: "",
                  moisture: 0.21, label: Plant.wateringLabel(days: 1),
                  thumb: nil),
            Sprig(id: "c", name: Lang.text("Монстера"), room: "",
                  moisture: 0.64, label: Plant.wateringLabel(days: 6),
                  thumb: nil),
            Sprig(id: "d", name: Lang.text("Кактус"), room: "",
                  moisture: 0.9, label: Plant.wateringLabel(days: 40),
                  thumb: nil),
            Sprig(id: "e", name: Lang.text("Фикус"), room: "",
                  moisture: 0.47, label: Plant.wateringLabel(days: 4),
                  thumb: nil),
        ]
        return Glance(date: .now, sprigs: sprigs.sorted { $0.moisture < $1.moisture },
                      ready: true, garden: sprigs)
    }
}

/// Земля сохнет и при закрытом приложении: на двенадцать часов вперёд,
/// каждые полчаса — свой кадр, потом виджет просит новые. Сад поменялся —
/// перерисовку зовёт само приложение, когда пишет сад, и полив из виджета.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Glance { .sample }

    func getSnapshot(in context: Context,
                     completion: @escaping (Glance) -> Void) {
        let now = Glance.now()
        completion(context.isPreview && now.sprigs.isEmpty ? .sample : now)
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<Glance>) -> Void) {
        completion(Timeline(entries: Glance.ahead(from: .now, steps: 24),
                            policy: .atEnd))
    }
}

// MARK: - «Домой»

struct ThirstWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Thirst", provider: Provider()) { entry in
            ThirstView(entry: entry)
                .containerBackground(for: .widget) { Leafy() }
        }
        .configurationDisplayName("Кого полить")
        .description("Самые сухие растения и кнопка «Полить».")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ThirstView: View {
    let entry: Glance

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if !entry.ready {
            Blank(icon: "leaf", line: "Откройте Sprout — и сад появится здесь.")
        } else if entry.sprigs.isEmpty {
            Blank(icon: "leaf", line: "В саду пока пусто.")
        } else {
            switch family {
            case .systemSmall: small(entry.sprigs[0])
            case .systemMedium: medium
            default: large
            }
        }
    }

    private func small(_ sprig: Sprig) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Thumb(url: sprig.thumb, side: 46)
                Spacer(minLength: 4)
                Text(sprig.percent)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Tone.of(sprig.thirst))
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 2)
            Text(sprig.name)
                .font(.headline)
                .lineLimit(1)
            Text(sprig.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            PourButton(sprig: sprig, wide: true)
                .padding(.top, 4)
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(entry.sprigs.prefix(3)) { sprig in
                VStack(spacing: 5) {
                    Thumb(url: sprig.thumb, side: 48)
                    Text(sprig.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(sprig.percent)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Tone.of(sprig.thirst))
                        .contentTransition(.numericText())
                    PourButton(sprig: sprig, wide: false)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Кого полить", systemImage: "drop.fill")
                .font(.headline)
                .foregroundStyle(Tone.water)
            ForEach(entry.sprigs.prefix(6)) { sprig in
                HStack(spacing: 10) {
                    Thumb(url: sprig.thumb, side: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sprig.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(sprig.room)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(sprig.percent)
                        .font(.headline)
                        .foregroundStyle(Tone.of(sprig.thirst))
                        .contentTransition(.numericText())
                    PourButton(sprig: sprig, wide: false)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// «Полить» — команда, а не переход: виджет поливает сам, приложение не
/// открывается.
private struct PourButton: View {
    let sprig: Sprig
    let wide: Bool

    var body: some View {
        Button(intent: WaterFromWidget(plant: sprig.id)) {
            if wide {
                Label("Полить", systemImage: "drop.fill")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "drop.fill")
                    .font(.caption.weight(.semibold))
                    .accessibilityLabel(Lang.format("Полить: %@", sprig.name))
            }
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Tone.water)
        .disabled(sprig.moisture >= 0.99)
    }
}

private struct Thumb: View {
    let url: URL?
    let side: CGFloat

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: side * 0.42))
                    .foregroundStyle(Tone.leaf)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Tone.leaf.opacity(0.15))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.28,
                                    style: .continuous))
        .accessibilityHidden(true)
    }
}

struct Blank: View {
    let icon: String
    let line: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Tone.leaf)
            Text(line)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Фон — светлая зелень сверху, как узор приложения, и системный цвет:
/// в тёмной теме и на тонированном экране «Домой» он подстраивается сам.
struct Leafy: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [Tone.leaf.opacity(0.16), .clear],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

enum Tone {
    static let water = Color(red: 0, green: 0.53, blue: 1)
    static let leaf = Color(red: 0.2, green: 0.62, blue: 0.3)

    /// Те же пороги, что тень на карточке: ниже 40% — оранжевый, ниже 20% —
    /// красный.
    static func of(_ thirst: Thirst) -> Color {
        switch thirst {
        case .calm: .primary
        case .warn: .orange
        case .alarm: .red
        }
    }
}

// MARK: - Экран блокировки

struct ThirstGlance: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThirstGlance", provider: Provider()) { entry in
            GlanceView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Кто хочет пить")
        .description("Сколько растений просят воды и кто первый.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular,
                            .accessoryInline])
    }
}

struct GlanceView: View {
    let entry: Glance

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryInline: inline
        default: rectangular
        }
    }

    /// Шкала — влажность самого сухого, число — сколько просят воды.
    private var circular: some View {
        Gauge(value: entry.sprigs.first?.moisture ?? 1) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(entry.thirsty.count.formatted())
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityLabel(Lang.format("Просят воды: %lld", entry.thirsty.count))
    }

    private var inline: some View {
        Label(entry.thirsty.isEmpty ? Lang.text("Все политы")
              : Lang.format("Просят воды: %lld", entry.thirsty.count),
              systemImage: "drop.fill")
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Кого полить", systemImage: "drop.fill")
                .font(.headline)
                .widgetAccentable()
            if entry.thirsty.isEmpty {
                Text("Все политы")
                    .font(.caption)
            } else {
                ForEach(entry.thirsty.prefix(2)) { sprig in
                    Text(Lang.format("%1$@ · %2$@", sprig.name, sprig.percent))
                        .font(.caption)
                        .lineLimit(1)
                }
                if entry.thirsty.count > 2 {
                    Text(Lang.format("и ещё %@", Lang.format("%lld растений",
                                                             entry.thirsty.count - 2)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
