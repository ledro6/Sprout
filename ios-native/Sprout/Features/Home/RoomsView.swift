import SwiftUI

/// Правка комнат. Список системный — ручки, минус, смахивание и прокрутку к
/// краю система делает лучше любого своего жеста; строки при этом свои,
/// стеклянные.
struct RoomsView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var naming = false
    @State private var draft = ""

    /// Комнату с растениями перед удалением переспрашивают.
    @State private var doomed: Room?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(garden.rooms) { room in
                        RoomRow(room: room) { shift(room, by: $0) }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: 5, leading: Metrics.contentMargin,
                                bottom: 5, trailing: Metrics.contentMargin))
                    }
                    .onMove { from, to in
                        withAnimation(Motion.arrange) {
                            garden.moveRooms(from: from, to: to)
                        }
                    }
                    .onDelete { offsets in ask(offsets) }
                } footer: {
                    if !garden.rooms.isEmpty {
                        Text(Self.hint)
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.secondaryText)
                            .padding(.horizontal, Metrics.contentMargin)
                    }
                }
                if !garden.rooms.isEmpty {
                    DachaGroup()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .hintSpot(.roomsList)
            .background { SproutBackground() }
            .environment(\.editMode, .constant(.active))
            .overlay {
                if garden.rooms.isEmpty {
                    ContentUnavailableView(
                        "Комнат нет",
                        systemImage: "house",
                        description: Text("Нажмите «+», чтобы завести первую."))
                        .transition(.blurReplace)
                }
            }
            .walk(.rooms)
            .navigationTitle("Комнаты")
            .navigationBarTitleDisplayMode(.large)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sproutSettledEdge()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        draft = ""
                        naming = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Новая комната")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .alert("Новая комната", isPresented: $naming) {
            TextField("Балкон", text: $draft)
            Button("Отмена", role: .cancel) {}
            // Без имени — неактивна, как на странице «Новая комната».
            Button("Завести") { add() }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty)
        } message: {
            Text("Растения в неё можно будет посадить или перевезти.")
        }
        .confirmationDialog(
            Lang.format("Удалить комнату «%@»?", doomed?.name ?? ""),
            isPresented: Binding(get: { doomed != nil },
                                 set: { if !$0 { doomed = nil } }),
            titleVisibility: .visible,
            presenting: doomed
        ) { room in
            Button("Удалить", role: .destructive) {
                withAnimation(Motion.arrange) { garden.deleteRoom(room.name) }
            }
            Button("Отмена", role: .cancel) {}
        } message: { room in
            Text(Self.warning(for: room))
        }
    }

    private static let hint = Lang.text("""
        Имя правится прямо в строке. Потяните за ручку справа, чтобы \
        поменять порядок, — в том же порядке комнаты листаются на главной.
        """)

    private static func warning(for room: Room) -> String {
        Lang.format("Вместе с ней уйдут %lld растений. Вернуть их будет нельзя.",
                    room.plants.count)
    }

    /// Пустую комнату удаляем сразу. С растениями — переспрашиваем и без
    /// возврата: она уносит всех, такое делают нарочно.
    private func ask(_ offsets: IndexSet) {
        for index in offsets where garden.rooms.indices.contains(index) {
            let room = garden.rooms[index]
            if room.plants.isEmpty {
                withAnimation(Motion.arrange) { garden.deleteRoom(room.name) }
            } else {
                doomed = room
            }
        }
    }

    /// «Выше» и «Ниже» для VoiceOver и Переключателей: перетаскивать ручку
    /// не у всех получается.
    private func shift(_ room: Room, by step: Int) {
        guard let index = garden.rooms.firstIndex(where: { $0.id == room.id }),
              garden.rooms.indices.contains(index + step) else { return }
        withAnimation(Motion.arrange) {
            garden.moveRooms(from: IndexSet(integer: index),
                             to: step > 0 ? index + 2 : index - 1)
        }
    }

    private func add() {
        let added = withAnimation(Motion.arrange) { garden.addRoom(draft) }
        if !added { Feel.wrong() }
    }
}

/// Строка комнаты. Имя правится прямо в поле и сохраняется, когда поле
/// отпускают; занятое или пустое возвращается к прежнему.
private struct RoomRow: View {
    let room: Room

    /// Сдвиг на строку: −1 выше, +1 ниже.
    let shift: (Int) -> Void

    @Environment(Garden.self) private var garden

    @State private var draft: String
    @FocusState private var focused: Bool

    init(room: Room, shift: @escaping (Int) -> Void) {
        self.room = room
        self.shift = shift
        _draft = State(initialValue: room.name)
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Название", text: $draft)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { commit() }
                .accessibilityAction(named: Text("Выше")) { shift(-1) }
                .accessibilityAction(named: Text("Ниже")) { shift(1) }
            if room.atDacha {
                Image(systemName: "house.lodge.fill")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.green)
                    .accessibilityLabel("На даче")
            }
            Text(count)
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Metrics.groupPadding)
        .padding(.vertical, 13)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .onChange(of: focused) { _, now in
            if !now { commit() }
        }
    }

    private var count: String {
        Lang.format("%lld растений", room.plants.count)
    }

    private func commit() {
        guard draft != room.name else { return }
        let renamed = withAnimation(Motion.number) {
            garden.renameRoom(room.name, to: draft)
        }
        if !renamed {
            draft = room.name
            Feel.wrong()
        }
    }
}
