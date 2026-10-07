import SwiftUI

/// Просьба посадить вид из каталога. Каталог открывают и с «Добавить», и
/// из поиска; посадка — всегда на вкладке «Добавить»: корень переключает
/// вкладку, экран забирает вид и очищает просьбу.
@MainActor
@Observable
final class Sowing {
    static let shared = Sowing()

    var specimen: Specimen?

    func ask(_ specimen: Specimen) { self.specimen = specimen }
}

/// «Каталог видов»: все виды, которые знает приложение, с поиском. Лист —
/// с экрана «Добавить»; вид открывается своей страницей.
struct HerbariumView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var found: [Specimen] { Herbarium.search(query) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    if found.isEmpty {
                        Text(Lang.format("Вида «%@» в каталоге нет.",
                                         query.trimmingCharacters(
                                             in: .whitespacesAndNewlines)))
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 60)
                    } else {
                        VStack(alignment: .leading, spacing: Metrics.rowGap) {
                            ForEach(Array(found.enumerated()),
                                    id: \.element.id) { item in
                                if item.offset > 0 { SproutDivider() }
                                NavigationLink(value: item.element) {
                                    SpecimenRow(specimen: item.element)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Metrics.groupPadding)
                        .sproutPlate(in: RoundedRectangle(
                            cornerRadius: Metrics.cardRadius,
                            style: .continuous))
                        Text("Сроки ухода — те же, что подставятся при посадке. Поправить их можно потом в настройках растения.")
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 6)
                    }
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background { SproutBackground() }
            .navigationTitle("Каталог видов")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sproutSettledEdge()
            .searchable(text: $query, prompt: "Найти вид")
            .navigationDestination(for: Specimen.self) { specimen in
                SpecimenView(specimen: specimen) { sow(specimen) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func sow(_ specimen: Specimen) {
        Sowing.shared.ask(specimen)
        dismiss()
    }
}

/// Страница вида: значок, сроки ухода, питомцы и «Посадить такое же».
struct SpecimenView: View {
    let specimen: Specimen
    let sow: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.groupGap) {
                head
                SproutGroup("Уход") {
                    ForEach(Array(facts.enumerated()), id: \.offset) { item in
                        if item.offset > 0 { SproutDivider() }
                        row(item.element)
                    }
                }
                if let danger = specimen.toxicity {
                    SproutGroup("Питомцы") {
                        Label(danger.line, systemImage: "pawprint.fill")
                            .font(Typography.settingRow)
                            .foregroundStyle(danger.harmful
                                             ? (danger == .toxic
                                                ? Palette.warn : Palette.alarm)
                                             : Palette.ink)
                    }
                }
                Button(action: sow) {
                    Label("Посадить такое же", systemImage: "plus.circle.fill")
                        .font(Typography.detail)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.accentFill)
                .controlSize(.large)
                Text("Откроется «Добавить» с этим видом и его сроками — останется дать кличку.")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .background { SproutBackground() }
        .navigationTitle(specimen.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .sproutSettledEdge()
    }

    private var head: some View {
        HStack(spacing: 16) {
            SpecimenBadge(preset: specimen.preset, side: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(specimen.title)
                    .font(Typography.figure)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(Blueprint.stock(specimen.preset).source)
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.groupPadding)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
    }

    private struct Fact {
        var icon: String
        var title: String
        var value: String
    }

    /// Только то, что есть в данных: нет срока полива — нет и строки.
    private var facts: [Fact] {
        var out: [Fact] = []
        if let days = specimen.watering {
            out.append(Fact(icon: "drop.fill", title: Lang.text("Полив"),
                            value: Species.periodLabel(days)))
        }
        let care = specimen.care
        if let days = care.feedEvery {
            out.append(Fact(icon: "sparkles", title: Lang.text("Подкормка"),
                            value: Species.periodLabel(days)))
        }
        if let days = care.repotEvery {
            out.append(Fact(icon: "arrow.up.bin", title: Lang.text("Пересадка"),
                            value: Lang.format("Раз в %lld месяцев",
                                               Care.months(days: days))))
        }
        for item in specimen.duties {
            out.append(Fact(icon: item.duty.icon, title: item.duty.title,
                            value: Species.periodLabel(item.days)))
        }
        return out
    }

    private func row(_ fact: Fact) -> some View {
        HStack(spacing: 12) {
            Image(systemName: fact.icon)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.accent)
                .frame(width: 24)
            Text(fact.title)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Text(fact.value)
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Строка вида: значок, название и срок полива, если он известен.
struct SpecimenRow: View {
    let specimen: Specimen

    var body: some View {
        HStack(spacing: 12) {
            SpecimenBadge(preset: specimen.preset, side: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(specimen.title)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if let days = specimen.watering {
                    Text(Lang.format("Полив %@", Species.periodPhrase(days)))
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(Typography.settingNote)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

/// Значок вида вместо фото: знак и оттенок из палитры узора — по складу
/// растения, а не по ботанике: суккуленты, цветущие, травы, деревца,
/// лиственные.
struct SpecimenBadge: View {
    let preset: Preset
    var side: CGFloat = 40

    var body: some View {
        let colour = Palette.raw(look.tint.vivid)
        Image(systemName: look.symbol)
            .font(.system(size: side * 0.45, weight: .semibold))
            .foregroundStyle(colour)
            .frame(width: side, height: side)
            .background(colour.opacity(0.16), in: Circle())
            .accessibilityHidden(true)
    }

    private var look: (symbol: String, tint: Tint) {
        switch preset {
        case .cactus, .aloe, .echeveria, .jade, .sansevieria, .zamioculcas,
             .haworthia, .opuntia, .kalanchoe:
            ("circle.hexagongrid.fill", .amber)
        case .orchid, .anthurium, .hoya, .violet, .begonia, .pelargonium,
             .tulip, .rose, .lily, .sunflower, .chrysanthemum, .spathiphyllum:
            ("camera.macro", .rose)
        case .herbs, .mint, .rosemary, .lavender:
            ("leaf.fill", .teal)
        case .ficus, .dracaena, .palm, .citrus, .yucca:
            ("tree.fill", .sky)
        case .monstera, .fern, .ivy, .chlorophytum, .calathea, .pilea,
             .alocasia:
            ("leaf.fill", .green)
        }
    }
}
