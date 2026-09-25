import PhotosUI
import SwiftUI
import UIKit

/// Добавить растение. Вид и срок полива подсказывает классификатор Vision,
/// кличку — языковая модель, если есть Apple Intelligence; всё прямо на
/// телефоне, и оба поля правятся руками.
struct AddView: View {
    @Environment(Garden.self) private var garden

    @State private var item: PhotosPickerItem?
    @State private var shooting = false

    /// Снимок целиком: кадр можно перевыбрать, а резать заново из обрезанного
    /// — терять на каждом заходе.
    @State private var raw: UIImage?

    /// Лист кадра поднимается после закрытия камеры — см. `snapped`.
    @State private var fresh: UIImage?

    @State private var trimming = false

    @State private var shot: UIImage?

    @State private var guess: Guess?
    @State private var looking = false

    @State private var name = ""
    @State private var species = ""
    @State private var room = ""
    @State private var period: Double = 7

    @State private var naming = false
    @State private var newRoom = ""

    @State private var thinking = false

    /// Строка готова заранее: к моменту показа поля уже очищены под следующее
    /// растение.
    @State private var planted: Planted?

    private struct Planted {
        var name: String
        var note: String
    }

    @State private var button = Spot()

    @FocusState private var typing: Bool

    private var rooms: [String] { garden.rooms.map(\.name) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SproutHead("Добавить", walk: .add)
                        VStack(alignment: .leading, spacing: Metrics.groupGap) {
                            picture
                                .hintSpot(.addPicture)
                            about
                                .hintSpot(.addAbout)
                            habits
                                .hintSpot(.addHabits)
                            plantButton
                                .hintSpot(.addPlant)
                        }
                        .padding(.horizontal, Metrics.contentMargin)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                }
                // Иначе до кнопки «Посадить» из последнего поля не добраться.
                .scrollDismissesKeyboard(.interactively)
                .background { SproutBackground() }
                .sproutNotchCover()
                .toolbar(.hidden, for: .navigationBar)
                .walk(.add, scroll: reader)
            }
        }
        .onAppear {
            if room.isEmpty { room = rooms.first ?? Lang.text("Дом") }
        }
        // `onDismiss` объявлен до содержимого — вторым замыканием его не
        // переставить.
        .fullScreenCover(isPresented: $shooting, onDismiss: { snapped() }) {
            Camera { image in fresh = image }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $trimming) {
            if let raw {
                Trim(image: raw) { cut in Task { await take(cut) } }
            }
        }
        .alert("Новая комната", isPresented: $naming) {
            TextField("Название", text: $newRoom)
            Button("Отмена", role: .cancel) {}
            Button("Завести") {
                let trimmed = newRoom
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { room = trimmed }
                newRoom = ""
            }
        }
        .alert(planted?.name ?? "", isPresented: Binding(
            get: { planted != nil },
            set: { if !$0 { planted = nil } }
        )) {
            Button("Хорошо", role: .cancel) {}
        } message: {
            Text(planted?.note ?? "")
        }
    }

    // MARK: - Снимок

    private var picture: some View {
        SproutGroup("Снимок") {
            well

            // У третьей кнопки подписи нет: три подписи в ряд на узком
            // телефоне переносились по слогам.
            HStack(spacing: 10) {
                PhotosPicker(selection: $item, matching: .images,
                             photoLibrary: .shared()) {
                    Label("Фото", systemImage: "photo.on.rectangle")
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.glass)

                if Camera.exists {
                    Button { shooting = true } label: {
                        Label("Снять", systemImage: "camera")
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.glass)
                }

                if shot != nil {
                    Button(role: .destructive) { forget() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Убрать снимок")
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let sighting {
                Text(sighting)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(sighting)
                    .transition(.blurReplace)
            }

        }
        .sproutRide()
        .onChange(of: item) { _, chosen in
            Task { await pick(chosen) }
        }
    }

    /// Пока снимка нет — росток на том же месте.
    private var well: some View {
        // Наложениями на пустой цвет, а не стопкой: `scaledToFill` растянул
        // бы окно.
        Color.clear
            .overlay {
                if let shot {
                    Image(uiImage: shot)
                        .resizable()
                        .scaledToFill()
                } else {
                    SproutPiece(index: 0)
                        .fill(Palette.ink.opacity(Metrics.pieceOff))
                        .frame(width: 64, height: 64)
                }
            }
            .overlay {
                if looking {
                    ProgressView()
                        .controlSize(.large)
                        .padding(14)
                        .sproutPlate(in: Circle())
                }
            }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                    style: .continuous))
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .contentShape(Rectangle())
        // Перевыбрать кадр — из непорезанного оригинала.
        .onTapGesture { if raw != nil { trimming = true } }
        .accessibilityLabel(shot == nil ? "Снимка нет" : "Снимок растения")
        .accessibilityHint(shot == nil ? "" : "Нажмите, чтобы выбрать кадр")
    }

    /// С долей уверенности: классификатор ошибается, и выдавать догадку за
    /// ответ — врать.
    private var sighting: String? {
        guard shot != nil, !looking else { return nil }
        guard let guess else {
            return Lang.text("""
                Растения на снимке телефон не узнал — впишите вид сами.
                """)
        }
        let sure = Int((guess.confidence * 100).rounded())
        return Lang.format("""
            Телефон узнал: %1$@ — уверен на %2$lld%%. Поправьте, если не так.
            """, guess.species, sure)
    }

    // MARK: - Растение

    private var about: some View {
        SproutGroup("Растение") {
            SproutBlock("Кличка") {
                HStack(spacing: 10) {
                    TextField("Баксик", text: $name)
                        .textFieldStyle(.plain)
                        .font(Typography.settingRow)
                        .focused($typing)
                        .submitLabel(.done)
                    if Muse.ready {
                        Button { Task { await invent() } } label: {
                            Label("Придумать", systemImage: "sparkles")
                        }
                        .buttonStyle(.glass)
                        .font(Typography.settingNote)
                        .disabled(thinking)
                    }
                }
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
        .sproutRide()
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
                    Button("Новая комната…") { naming = true }
                } label: {
                    field(room.isEmpty ? Lang.text("Выбрать") : room)
                }
            }

            SproutDivider()

            SproutBlock("Полив", term: .period) {
                PeriodWheel(days: $period)
            }
        }
        .sproutRide()
    }

    private func field(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(Typography.settingRow)
            Image(systemName: "chevron.up.chevron.down")
                .font(Typography.settingNote)
        }
        .foregroundStyle(Palette.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Посадить

    private var plantButton: some View {
        Button { plant() } label: {
            Text("Посадить")
                .font(Typography.detail)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .tint(Palette.accent)
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
            action: { button.rect = $0 }
        .sproutRide()
    }

    // MARK: - Что происходит

    /// Вписанный вид, а если поле пустое — подсказанный классификатором.
    private var wanted: String {
        let typed = species.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? (guess?.species ?? "") : typed
    }

    /// Кадр выбирают после камеры, а не в ней: два экрана, поднятых в одном
    /// проходе, система показывает как один.
    private func snapped() {
        guard let image = fresh else { return }
        fresh = nil
        raw = image
        trimming = true
    }

    @MainActor
    private func pick(_ chosen: PhotosPickerItem?) async {
        guard let chosen,
              let data = try? await chosen.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        raw = image
        // Лист выбора фото ещё закрывается, и поднятый в тот же миг лист
        // кадра система не покажет.
        try? await Task.sleep(for: .milliseconds(350))
        trimming = true
    }

    /// Подсказка не затирает вписанный руками вид; срок подставляется только
    /// вместе с видом.
    @MainActor
    private func take(_ image: UIImage) async {
        withAnimation(Motion.appear) { shot = image }
        looking = true
        let seen = await Eye.guess(image)
        withAnimation(Motion.number) {
            guess = seen
            looking = false
            if let seen, species.trimmingCharacters(in: .whitespaces).isEmpty {
                species = seen.species
                period = max(seen.dryingDays.rounded(), 1)
            }
        }
    }

    private func forget() {
        withAnimation(Motion.appear) {
            shot = nil
            raw = nil
            fresh = nil
            item = nil
            guess = nil
        }
    }

    @MainActor
    private func invent() async {
        thinking = true
        let word = await Muse.nickname(for: wanted.isEmpty
                                       ? Lang.text("Комнатное растение") : wanted)
        thinking = false
        guard let word else { return }
        withAnimation(Motion.pill) { name = word }
    }

    /// Снимок кладётся на диск только здесь: передуманные снимки копились бы
    /// в Documents мусором.
    private func plant() {
        let nickname = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else { return }
        let kind = wanted.isEmpty ? Lang.text("Комнатное растение") : wanted
        let chosen = room.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = chosen.isEmpty ? Lang.text("Дом") : chosen
        let days = Int(period.rounded())

        let saved = shot.flatMap { Snapshot.keep($0) }
        // Модель для AR — готовая модель вида: своя, по снимку или сканом,
        // — только если хозяин попросит, на экране растения.
        let seedling = Plant.new(name: nickname, species: kind,
                                 dryingDays: period, shot: saved)
        withAnimation(Motion.appear) { garden.add(seedling, to: place) }
        Cheer.shared.now(from: button.rect)
        Feel.planted()
        typing = false
        // Две строки каталога: у второй форма числа своя.
        planted = Planted(
            name: nickname,
            note: Lang.format("Растёт в комнате «%@».", place) + "\n"
                + Lang.format("Полито, следующий полив через %lld дней.", days))
        reset()
    }

    /// Комната остаётся: сажают обычно подряд и в одно место.
    private func reset() {
        withAnimation(Motion.appear) {
            name = ""
            species = ""
            shot = nil
            raw = nil
            fresh = nil
            item = nil
            guess = nil
            period = 7
        }
    }
}
