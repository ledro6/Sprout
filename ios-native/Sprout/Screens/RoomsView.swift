import SwiftUI

/// Правка комнат: переименовать, переставить, удалить, завести новую.
///
/// Прежде комнату можно было только завести — и только посадив в неё
/// растение. Переименовать её, поменять порядок в меню или убрать было
/// нечем, и опустевшая комната так и висела в списке.
///
/// Список здесь системный, `List` в режиме правки, — и это исключение из
/// правила «всё на своих плашках», сделанное сознательно. Ручки
/// перестановки, красный минус, смахивание для удаления, прокрутка к
/// краю, пока тащишь, — всё это система умеет сама и умеет лучше, чем
/// повторил бы любой свой жест. А вот строки свои: стеклянные плашки
/// поверх узора, как везде в приложении, а не серые ячейки.
struct RoomsView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    /// Спрашивают ли имя новой комнаты.
    @State private var naming = false
    @State private var draft = ""

    /// Какую комнату собираются удалить вместе с растениями — её
    /// переспрашивают.
    @State private var doomed: Room?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(garden.rooms) { room in
                        RoomRow(room: room)
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
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Metrics.contentMargin)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { SproutBackground() }
            // Правка включена всегда: этот лист ради неё и открывают, и
            // лишняя кнопка «Изменить» здесь была бы шагом ни за чем.
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
            .navigationTitle("Комнаты")
            .navigationBarTitleDisplayMode(.large)
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
            Button("Завести") { add() }
        } message: {
            Text("Растения в неё можно будет посадить или перевезти.")
        }
        .confirmationDialog(
            "Удалить комнату «\(doomed?.name ?? "")»?",
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

    /// Подсказка под списком.
    private static let hint = "Имя правится прямо в строке. Потяните за "
        + "ручку справа, чтобы поменять порядок, — в том же порядке "
        + "комнаты встанут и в меню на главной."

    /// Что уйдёт вместе с комнатой.
    private static func warning(for room: Room) -> String {
        let n = room.plants.count
        return "Вместе с ней уйдут \(n) "
            + Plant.plural(n, "растение", "растения", "растений")
            + ". Вернуть их будет нельзя."
    }

    /// Удалить комнату — или переспросить.
    ///
    /// Пустую удаляем сразу: терять в ней нечего. Комнату с растениями
    /// переспрашиваем, и это не то же, что удаление растения. Растение
    /// уходит одно и пять секунд его можно вернуть; комната уносит с
    /// собой всех, кто в ней живёт, — такое делают нарочно, а не
    /// промахнувшись.
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

    private func add() {
        let added = withAnimation(Motion.arrange) { garden.addRoom(draft) }
        if !added { Feel.wrong() }
    }
}

/// Строка комнаты: имя, которое правится прямо здесь, и сколько в ней
/// растений.
///
/// Имя правится в поле, а не в отдельном окне: переименование — самое
/// частое, что с комнатой делают, и окно ради каждой буквы было бы лишним
/// шагом. Сохраняется оно, когда поле отпускают, — по «Готово» на
/// клавиатуре или просто уйдя в другое место. Занятое или пустое имя не
/// сохраняется: поле возвращается к прежнему и телефон вздрагивает.
private struct RoomRow: View {
    let room: Room

    @Environment(Garden.self) private var garden

    @State private var draft: String
    @FocusState private var focused: Bool

    init(room: Room) {
        self.room = room
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
            Text(count)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
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
        let n = room.plants.count
        return "\(n) " + Plant.plural(n, "растение", "растения", "растений")
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
