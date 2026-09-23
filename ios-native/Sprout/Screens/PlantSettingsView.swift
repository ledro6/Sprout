import SwiftUI

/// Настройки растения: кличка, вид, комната и срок полива. Правки копятся в
/// черновике и ложатся в сад по «Готово», отмена ничего не трогает. Пока в
/// листе есть правки, смахнуть его нельзя: они пропали бы молча.
struct PlantSettingsView: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var species = ""
    @State private var room = ""
    @State private var period: Double = 7

    @State private var naming = false
    @State private var newRoom = ""

    @FocusState private var typing: Bool

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    about
                    habits
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { SproutBackground() }
            .navigationTitle("Настройки растения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { save() }
                        .disabled(!valid)
                }
            }
        }
        .interactiveDismissDisabled(changed)
        .onAppear(perform: load)
        .onChange(of: plant == nil) { _, gone in
            if gone { dismiss() }
        }
        .alert("Новая комната", isPresented: $naming) {
            TextField("Балкон", text: $newRoom)
            Button("Отмена", role: .cancel) {}
            Button("Выбрать") {
                let trimmed = newRoom
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { room = trimmed }
            }
        } message: {
            Text("Комната появится, когда вы нажмёте «Готово».")
        }
    }

    // MARK: - Растение

    private var about: some View {
        SproutGroup("Растение") {
            SproutBlock("Кличка") {
                TextField("Баксик", text: $name)
                    .textFieldStyle(.plain)
                    .font(Typography.settingRow)
                    .focused($typing)
                    .submitLabel(.done)
            }

            SproutDivider()

            SproutBlock("Вид") {
                TextField("Монстера", text: $species)
                    .textFieldStyle(.plain)
                    .font(Typography.settingRow)
                    .focused($typing)
                    .submitLabel(.done)
            }
        }
    }

    // MARK: - Уход

    private var habits: some View {
        SproutGroup("Уход") {
            SproutBlock("Комната") {
                Menu {
                    Picker("Комната", selection: $room) {
                        ForEach(rooms, id: \.self) { Text($0).tag($0) }
                    }
                    Divider()
                    Button("Новая комната…") {
                        newRoom = ""
                        naming = true
                    }
                } label: {
                    field(room)
                }
            }

            SproutDivider()

            SproutBlock(
                "Полив",
                note: "За этот срок земля высыхает досуха. Новый срок "
                    + "считается от последнего полива."
            ) {
                Picker("Полив", selection: $period) {
                    ForEach(options, id: \.self) { days in
                        Text(Species.periodLabel(days)).tag(days)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(forecast)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                if let usual = suggestion {
                    Button {
                        withAnimation(Motion.number) { period = usual }
                        Feel.pick()
                    } label: {
                        Label(usualLine(usual), systemImage: "sparkles")
                            .font(Typography.settingNote)
                    }
                    .buttonStyle(.glass)
                    .transition(.blurReplace)
                }
            }
            .animation(Motion.number, value: period)
            .animation(Motion.enter, value: suggestion)
        }
    }

    private func field(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(Typography.settingRow)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(Typography.settingNote)
        }
        .foregroundStyle(Palette.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Черновик

    /// Новая комната из окошка — в списке сразу, хотя в саду её ещё нет.
    private var rooms: [String] {
        let names = garden.rooms.map(\.name)
        return names.contains(room) || room.isEmpty ? names : names + [room]
    }

    private var options: [Double] {
        Species.choices(with: [plant?.dryingDays ?? 0, period,
                               suggestion ?? 0])
    }

    /// Обычный срок вписанного вида, если он не тот, что выбран.
    private var suggestion: Double? {
        guard let usual = Species.usual(for: species), usual != period
        else { return nil }
        return usual
    }

    private func usualLine(_ days: Double) -> String {
        "Обычно для вида: " + Species.periodLabel(days).lowercased()
    }

    /// Как новый срок ляжет на карточку — тем же счётом, что `tune`.
    private var forecast: String {
        guard var preview = plant else { return "" }
        preview.retime(period)
        return preview.wateringLabel
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var valid: Bool { !trimmedName.isEmpty }

    private var changed: Bool {
        guard let plant else { return false }
        return trimmedName != plant.name
            || species.trimmingCharacters(in: .whitespacesAndNewlines)
                != plant.species
            || period != plant.dryingDays
            || room != (garden.roomName(of: plantID) ?? "")
    }

    private func load() {
        guard let plant else { return }
        name = plant.name
        species = plant.species
        room = garden.roomName(of: plantID) ?? ""
        period = plant.dryingDays
    }

    private func save() {
        guard valid else { return }
        typing = false
        let edited = changed
        withAnimation(Motion.number) {
            garden.tune(plantID, name: name, species: species,
                        dryingDays: period)
            garden.relocate(plantID, to: room)
        }
        // Сменился вид — сменилась и модель: собираем её заранее.
        if let tuned = garden.plant(id: plantID) {
            Task(priority: .utility) { await Workshop.shared.prepare(tuned) }
        }
        if edited { Feel.done() }
        dismiss()
    }
}
