import PhotosUI
import SwiftUI

/// «Фото и заметки» на экране растения: лента снимков по датам, новые
/// первыми, и заметки с датами. Снимок добавляют в два касания — «+» и выбор
/// «Снять» или «Из галереи», как в «Что с ним?». Старая заметка идёт первой,
/// см. `Plant.legacyJot`.
struct PlantJournal: View {
    let plant: Plant
    var writing: FocusState<Bool>.Binding

    @Environment(Garden.self) private var garden

    @State private var choosing = false
    @State private var wantsCamera = false
    @State private var shooting = false
    @State private var fresh: UIImage?
    @State private var item: PhotosPickerItem?
    @State private var viewing = false
    @State private var start = 0
    @State private var draft = ""

    private var newestFirst: [Snap] {
        Array(plant.snaps.reversed())
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Файлы для просмотра: снимки ленты, новые первыми, потом портрет и своё
    /// фото. Без картинки на диске — мимо, как и в экране растения.
    private var viewerNames: [String] {
        var names: [String] = []
        let extra = [plant.portrait, plant.shot].compactMap { $0 }
        for name in newestFirst.map(\.file) + extra {
            if !names.contains(name), Snapshot.image(name) != nil {
                names.append(name)
            }
        }
        return names
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.diaryGap) {
            Text("Фото и заметки")
                .font(Typography.groupTitle)
                .foregroundStyle(Palette.secondaryText)
            strip
            notes
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .sproutRide()
        .sheet(isPresented: $choosing, onDismiss: { showCamera() }) {
            choice
        }
        .fullScreenCover(isPresented: $shooting, onDismiss: { keepShot() }) {
            Camera { image in fresh = image }
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $viewing) {
            PhotoViewer(names: viewerNames, start: start)
        }
        .onChange(of: item) { _, chosen in
            if chosen != nil { choosing = false }
            Task { await pick(chosen) }
        }
    }

    // MARK: - Лента

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                addTile
                ForEach(newestFirst, id: \.self) { snap in
                    snapTile(snap)
                }
            }
        }
    }

    private var addTile: some View {
        Button { choosing = true } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                Text("Добавить")
                    .font(Typography.settingNote)
            }
            .foregroundStyle(Palette.accentFill)
            .frame(width: 112, height: 112)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.secondaryText, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Добавить фото")
    }

    private func snapTile(_ snap: Snap) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { open(snap.file) } label: {
                thumb(snap.file)
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 16,
                                                style: .continuous))
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    withAnimation(Motion.appear) {
                        garden.removeSnap(plant.id, file: snap.file)
                    }
                    Feel.toss()
                } label: {
                    Label("Удалить фото", systemImage: "trash")
                }
            }
            Text(snap.date.formatted(date: .abbreviated, time: .omitted))
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
        }
    }

    @ViewBuilder
    private func thumb(_ file: String) -> some View {
        if let image = Snapshot.image(file) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .font(.system(size: 26))
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private func open(_ file: String) {
        guard let index = viewerNames.firstIndex(of: file) else { return }
        start = index
        viewing = true
    }

    // MARK: - Выбор и добавление снимка

    private var choice: some View {
        VStack(spacing: 12) {
            if Camera.exists {
                Button {
                    wantsCamera = true
                    choosing = false
                } label: {
                    Label("Снять", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            PhotosPicker(selection: $item, matching: .images) {
                Label("Из галереи", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .font(Typography.settingNote)
        .padding(Metrics.margin)
        .presentationDetents([.height(180)])
    }

    /// Камеру открываем, когда лист выбора закрылся: два листа разом SwiftUI
    /// не покажет.
    private func showCamera() {
        guard wantsCamera else { return }
        wantsCamera = false
        shooting = true
    }

    private func keepShot() {
        guard let image = fresh else { return }
        fresh = nil
        keep(image)
    }

    @MainActor
    private func pick(_ chosen: PhotosPickerItem?) async {
        guard let chosen,
              let data = try? await chosen.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        item = nil
        keep(image)
    }

    private func keep(_ image: UIImage) {
        guard let name = Snapshot.keep(image) else { return }
        withAnimation(Motion.enter) {
            garden.addSnap(plant.id, file: name)
        }
        Feel.done()
    }

    // MARK: - Заметки

    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(plant.journal, id: \.self) { jot in
                noteRow(jot)
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Новая заметка", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1 ... 6)
                    .focused(writing)
                Button("Добавить") { addJot() }
                    .font(Typography.settingNote)
                    .disabled(trimmedDraft.isEmpty)
            }
        }
    }

    private func noteRow(_ jot: Jot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(jot.date.formatted(date: .abbreviated, time: .omitted))
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
            Text(jot.text)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contextMenu {
            Button(role: .destructive) {
                remove(jot)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func addJot() {
        let text = trimmedDraft
        guard !text.isEmpty else { return }
        garden.addJot(plant.id, text: text)
        draft = ""
        Feel.done()
    }

    /// Старая заметка живёт в `note`: её удаление очищает поле.
    private func remove(_ jot: Jot) {
        withAnimation(Motion.appear) {
            if jot == plant.legacyJot {
                garden.note(plant.id, "")
            } else {
                garden.removeJot(plant.id, jot)
            }
        }
        Feel.toss()
    }
}
