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

    /// Подкормка: напоминать ли и раз в сколько дней; пересадка — в месяцах,
    /// пусто — не напоминать.
    @State private var feeds = true
    @State private var feedEvery: Double = 21
    @State private var repotMonths: Int?

    @State private var naming = false
    @State private var newRoom = ""

    @FocusState private var typing: Bool

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.groupGap) {
                        about
                            .hintSpot(.tuningAbout)
                        habits
                            .hintSpot(.tuningHabits)
                        tending
                            .hintSpot(.tuningTending)
                    }
                    .padding(.horizontal, Metrics.contentMargin)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .background { SproutBackground() }
                .walk(.tuning, scroll: reader)
            }
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

            SproutBlock("Полив", term: .period) {
                PeriodWheel(days: $period)

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

    // MARK: - Подкормка и пересадка

    private var tending: some View {
        SproutGroup("Подкормка и пересадка") {
            HStack(spacing: 12) {
                Text("Напоминать о подкормке")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                TermHint(.feeding)
                Spacer(minLength: 0)
                Toggle("Напоминать о подкормке", isOn: $feeds.animation(Motion.enter))
                    .labelsHidden()
            }
            if feeds {
                PeriodWheel(days: $feedEvery)
                    .transition(.blurReplace)
            }

            SproutDivider()

            SproutBlock("Пересадка", term: .repotting) {
                Menu {
                    Picker("Пересадка", selection: $repotMonths) {
                        Text("Не напоминать").tag(Int?.none)
                        ForEach(Care.repotMonths, id: \.self) { months in
                            Text(Lang.format("Раз в %lld месяцев", months))
                                .tag(Int?.some(months))
                        }
                    }
                } label: {
                    field(repotMonths.map { Lang.format("Раз в %lld месяцев", $0) }
                          ?? Lang.text("Не напоминать"))
                }
            }
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

    /// Обычный срок вписанного вида, если он не тот, что выбран.
    private var suggestion: Double? {
        guard let usual = Species.usual(for: species), usual != period
        else { return nil }
        return usual
    }

    private func usualLine(_ days: Double) -> String {
        Lang.format("Обычно для вида: %@", Species.periodPhrase(days))
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
            || feedDraft != plant.tending.feedEvery
            || repotDraft != plant.tending.repotEvery
    }

    private var feedDraft: Double? { feeds ? feedEvery : nil }

    /// Прежний срок в днях остаётся как был, если месяцы не трогали: иначе
    /// округление до месяцев считалось бы правкой.
    private var repotDraft: Double? {
        guard let months = repotMonths else { return nil }
        if let old = plant?.tending.repotEvery, Care.months(days: old) == months {
            return old
        }
        return Care.days(months: months)
    }

    private func load() {
        guard let plant else { return }
        name = plant.name
        species = plant.species
        room = garden.roomName(of: plantID) ?? ""
        period = plant.dryingDays
        let tending = plant.tending
        feeds = tending.feedEvery != nil
        feedEvery = tending.feedEvery ?? 21
        repotMonths = tending.repotEvery.map { Care.months(days: $0) }
    }

    private func save() {
        guard valid else { return }
        typing = false
        let edited = changed
        withAnimation(Motion.number) {
            garden.tune(plantID, name: name, species: species,
                        dryingDays: period)
            garden.tend(plantID, feedEvery: feedDraft, repotEvery: repotDraft)
            garden.relocate(plantID, to: room)
        }
        // Сменился вид — у своей модели по снимку сменился и чертёж:
        // пересобираем её, раз хозяин её заказывал. Не сменился — мастерская
        // скажет, что модель уже есть. У готовой модели вида собирать нечего.
        if let tuned = garden.plant(id: plantID), tuned.plan != nil {
            Workshop.order(tuned)
        }
        if edited { Feel.done() }
        dismiss()
    }
}
