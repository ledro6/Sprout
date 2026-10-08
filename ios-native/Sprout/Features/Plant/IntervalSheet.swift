import SwiftUI

/// Срок полива одним листом: степпер «−/+», «Обычно для вида: раз в 7 дней»
/// и «Применить рекомендацию». Рекомендация применяется сразу и закрывает
/// лист — смена срока в два нажатия: чип, рекомендация. Правка степпером —
/// «Готово»; «Отмена» ничего не меняет.
struct IntervalSheet: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var days: Double = 7

    private var plant: Plant? { garden.plant(id: plantID) }

    /// Обычный срок вида, если он в таблице и отличается от нынешнего.
    private var usual: Double? {
        guard let plant, let days = Species.usual(for: plant.species)
        else { return nil }
        return days
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                PeriodStepper(days: $days)
                if let usual {
                    Text(Lang.format("Обычно для вида: %@",
                                     Species.periodPhrase(usual)))
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                    Button {
                        apply(usual)
                    } label: {
                        Label("Применить рекомендацию", systemImage: "sparkles")
                            .font(Typography.settingRow)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 8)
            .navigationTitle("Срок полива")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { apply(days) }
                }
            }
        }
        .presentationDetents([.height(300)])
        .onAppear { days = plant?.dryingDays ?? days }
    }

    private func apply(_ value: Double) {
        guard let plant else { return dismiss() }
        garden.tune(plantID, name: plant.name, species: plant.species,
                    dryingDays: value)
        Feel.done()
        dismiss()
    }
}
