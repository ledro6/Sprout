import PhotosUI
import SwiftUI
import UIKit
import UserNotifications

/// Добавить растение. Вид и срок полива подсказывает классификатор Vision,
/// кличку — языковая модель, если есть Apple Intelligence; всё прямо на
/// телефоне, и оба поля правятся руками.
struct AddView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.tabShown) private var shown

    /// Лист «Каталог видов».
    @State private var browsing = false

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
    /// «Последний полив» — от него влажность нового растения, см. `Start`.
    @State private var last = Start.Last.today
    /// «Не помню» — «Земля сухая?»; пусто — ещё не ответили.
    @State private var soil: Start.Soil?

    /// Уход, от которого отказались при посадке. Вид предлагает, а делать
    /// ли — решает хозяин: отказанного нет ни в напоминаниях, ни на экране
    /// растения. Как и комната, остаётся для следующей посадки.
    @State private var skipped: Set<ExtraCare> = []

    @State private var naming = false
    @State private var newRoom = ""

    @State private var thinking = false

    /// Форма без снимка: «Ввести вручную», вид из каталога.
    @State private var manual = false

    /// Другие виды, если классификатор не уверен: до трёх чипов.
    @State private var candidates: [Guess] = []

    /// Предложенная кличка: подставится при посадке, если поле пустое.
    @State private var suggestion: String?

    @State private var editingKind = false

    /// «Дополнительно» свёрнуто: уход вида включён сам.
    @State private var extra = false

    /// Тост после посадки: «{Имя} — в саду».
    @State private var welcome: String?

    /// «Напоминать, когда пора полить?» — после первого растения.
    @State private var reminding = false

    /// Вставленный черенок: с ним — срок и уход, как у друга.
    @State private var cutting: Cutting?
    @State private var trouble: String?

    @State private var button = Spot()

    @FocusState private var typing: Bool

    private var rooms: [String] { garden.rooms.map(\.name) }

    /// Форма — после снимка, вручную, с черенком или видом из каталога;
    /// до этого — вход: «Снять» и «Из фото».
    private var formShown: Bool { shot != nil || manual || cutting != nil }

    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SproutHead("Добавить")
                        VStack(alignment: .leading, spacing: Metrics.groupGap) {
                            if formShown {
                                form
                            } else {
                                entry
                                    .hintSpot(.addPicture)
                            }
                        }
                        .padding(.horizontal, Metrics.contentMargin)
                        .padding(.top, 8)
                        .padding(.bottom, Metrics.barGap)
                    }
                }
                // Иначе до кнопки «Посадить» из последнего поля не добраться.
                .scrollDismissesKeyboard(.interactively)
                // Вход во вкладку — плавно; фон стоит.
                .modifier(TabEntrance())
                .background { SproutBackground() }
                .sproutSoftTop()
                .toolbar(.hidden, for: .navigationBar)
                // «Посадить» закреплена над панелью вкладок; вставка — до
                // `walk`, чтобы подсказка видела кнопку.
                .safeAreaInset(edge: .bottom, spacing: 8) { pinned }
                .walk(.add, scroll: reader)
            }
        }
        .onAppear {
            if room.isEmpty { room = rooms.first ?? Lang.text("Дом") }
            Journal.shared.note(.addPlantStarted)
        }
        // Вид из каталога — с этой вкладки или из поиска: забираем, когда
        // вкладка на экране.
        .onChange(of: Sowing.shared.specimen, initial: true) { _, _ in sow() }
        .onChange(of: shown) { _, _ in sow() }
        .onChange(of: item) { _, chosen in
            Task { await pick(chosen) }
        }
        .sheet(isPresented: $browsing) { HerbariumView() }
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
        .alert("Напоминать, когда пора полить?", isPresented: $reminding) {
            Button("Напоминать") {
                Task { @MainActor in
                    if await Notifier.ask() { Settings.shared.reminders = true }
                }
            }
            Button("Не сейчас", role: .cancel) {}
        } message: {
            Text("Сообщим, когда растению нужна вода.")
        }
        .alert("Не вышло", isPresented: Binding(
            get: { trouble != nil },
            set: { if !$0 { trouble = nil } }
        )) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(trouble ?? "")
        }
    }

    /// Закреплено над панелью: тост после посадки и «Посадить».
    private var pinned: some View {
        VStack(spacing: 8) {
            if let welcome {
                Text(welcome)
                    .font(Typography.toastTitle)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .sproutGlass(in: .capsule)
                    .transition(.blurReplace)
            }
            if formShown {
                plantButton
                    .hintSpot(.addPlant)
                    .transition(.blurReplace)
            }
        }
        .padding(.horizontal, Metrics.contentMargin)
        .padding(.bottom, Metrics.barGap)
        .animation(Motion.toast, value: welcome)
    }

    // MARK: - Вход

    /// Росток поменьше 160 pt, большая «Снять», вторичная «Из фото» и мелкие
    /// ссылки. Без камеры (симулятор) «Из фото» — единственный путь.
    private var entry: some View {
        VStack(spacing: 18) {
            SproutPiece(index: 0)
                .fill(Palette.ink.opacity(Metrics.pieceOff))
                .frame(width: 128, height: 128)
                .padding(.top, 12)
                .accessibilityHidden(true)

            Text("Сфотографируйте растение — вид и срок полива подскажет телефон.")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                if Camera.exists {
                    Button { shooting = true } label: {
                        Label("Снять", systemImage: "camera.fill")
                            .font(Typography.detail)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                    .controlSize(.extraLarge)
                }
                PhotosPicker(selection: $item, matching: .images,
                             photoLibrary: .shared()) {
                    Label("Из фото", systemImage: "photo.on.rectangle")
                        .font(Typography.detail)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)
            }

            graft

            Button { withAnimation(Motion.appear) { manual = true } } label: {
                Text("Ввести вручную")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.accent)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .sproutRide()
    }

    // MARK: - Форма

    private var form: some View {
        VStack(alignment: .leading, spacing: Metrics.groupGap) {
            if cutting != nil {
                graft
            }
            about
                .hintSpot(.addAbout)
            habits
                .hintSpot(.addHabits)
        }
    }

    /// Миниатюра снимка: нажатие — выбрать кадр заново из оригинала.
    private var thumb: some View {
        Color.clear
            .overlay {
                if let shot {
                    Image(uiImage: shot)
                        .resizable()
                        .scaledToFill()
                } else {
                    SproutPiece(index: 0)
                        .fill(Palette.ink.opacity(Metrics.pieceOff))
                        .frame(width: 32, height: 32)
                }
            }
            .overlay {
                if looking {
                    ProgressView()
                        .padding(8)
                        .sproutPlate(in: Circle())
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                if raw != nil {
                    trimming = true
                } else if Camera.exists {
                    shooting = true
                }
            }
            .accessibilityLabel(shot == nil ? "Снимка нет" : "Снимок растения")
            .accessibilityHint(shot == nil ? "" : "Нажмите, чтобы выбрать кадр")
    }

    // MARK: - Растение

    private var about: some View {
        SproutGroup("Растение") {
            HStack(alignment: .center, spacing: 12) {
                thumb
                    .overlay(alignment: .topTrailing) {
                        if shot != nil {
                            Button { forget() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(Typography.navTitle)
                                    .foregroundStyle(Palette.ink.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                            .accessibilityLabel("Убрать снимок")
                        }
                    }
                HStack(spacing: 8) {
                    TextField("Как назовём?", text: $name)
                        .textFieldStyle(.plain)
                        .font(Typography.settingRow)
                        .focused($typing)
                        .submitLabel(.done)
                    if Muse.ready {
                        Button { Task { await invent() } } label: {
                            Label("Придумать", systemImage: "sparkles")
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .buttonStyle(.glass)
                        .font(Typography.settingNote)
                        .disabled(thinking)
                    }
                }
            }

            SproutDivider()

            kind
        }
        .sproutRide()
    }

    /// «Похоже на … · изменить»; не уверен — ещё до трёх видов чипами.
    private var kind: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(kindLine)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("·")
                    .foregroundStyle(Palette.secondaryText)
                Button {
                    withAnimation(Motion.appear) { editingKind.toggle() }
                } label: {
                    Text("изменить")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.accent)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
            if lowConfidence {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(candidates.prefix(3), id: \.self) { option in
                            Button {
                                withAnimation(Motion.appear) {
                                    species = option.species
                                    period = max(option.dryingDays.rounded(), 1)
                                }
                                Feel.pick()
                            } label: {
                                Text(option.species)
                                    .dataLines()
                                    .fixedSize()
                            }
                            .buttonStyle(.glass)
                            .font(Typography.settingNote)
                        }
                    }
                }
            }
            if editingKind || species.isEmpty {
                TextField("Монстера", text: $species)
                    .textFieldStyle(.plain)
                    .font(Typography.settingRow)
                    .focused($typing)
                    .submitLabel(.done)
                Button { browsing = true } label: {
                    Label("Выбрать из каталога", systemImage: "books.vertical")
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.glass)
                .font(Typography.settingNote)
            }
            PetNote(species: wanted)
        }
        .animation(Motion.appear, value: editingKind)
    }

    private var kindLine: String {
        if species.isEmpty { return Lang.text("Вид не указан") }
        if let guess, guess.species == species {
            return Lang.format("Похоже на %@", species)
        }
        return species
    }

    /// Классификатор не уверен и назвал больше одного вида.
    private var lowConfidence: Bool {
        guard shot != nil, !looking, candidates.count > 1 else { return false }
        return Sureness(guess?.confidence ?? 0) != .likely
    }

    /// Черенок от друга: вставили — кличка, вид и срок встают сами, уход —
    /// при посадке.
    @ViewBuilder
    private var graft: some View {
        if let cutting {
            HStack(spacing: 10) {
                Image(systemName: "scissors")
                    .foregroundStyle(Palette.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Lang.format("От друга: %@", cutting.from))
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("Посадится со сроками ухода, как у друга.")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button {
                    withAnimation(Motion.appear) { self.cutting = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Typography.navTitle)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Убрать растение друга")
            }
            .transition(.blurReplace)
        } else {
            HStack(spacing: 10) {
                Label("Растение от друга", systemImage: "gift")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                PasteButton(payloadType: String.self) { items in
                    guard let text = items.first else { return }
                    Task { @MainActor in accept(text) }
                }
                .buttonBorderShape(.capsule)
                .fixedSize()
            }
        }
    }

    @MainActor
    private func accept(_ text: String) {
        guard let found = Cutting.read(text) else {
            trouble = Lang.text("В скопированном нет растения из Sprout. Скопируйте сообщение друга целиком — код лежит в нём последней строкой.")
            Feel.wrong()
            return
        }
        withAnimation(Motion.appear) {
            cutting = found
            name = found.name
            species = found.species
            period = max(found.days.rounded(), 1)
        }
        Feel.done()
    }

    // MARK: - Уход

    private var habits: some View {
        SproutGroup("Уход") {
            HStack(spacing: 8) {
                Text("Комната")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Menu {
                    Picker("Комната", selection: $room) {
                        ForEach(rooms, id: \.self) { Text($0).tag($0) }
                    }
                    Divider()
                    Button("Новая комната…") { naming = true }
                } label: {
                    HStack(spacing: 6) {
                        Text(room.isEmpty ? Lang.text("Выбрать") : room)
                            .font(Typography.settingRow)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(Typography.settingNote)
                    }
                    .foregroundStyle(Palette.accent)
                }
            }

            SproutDivider()

            VStack(alignment: .leading, spacing: 4) {
                PeriodStepper(days: $period)
                if let usual = Species.usual(for: wanted),
                   Int(usual.rounded()) != Int(period.rounded()) {
                    Text(Lang.format("Обычно для вида: %@",
                                     Species.periodPhrase(usual)))
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                }
            }

            SproutDivider()

            SproutBlock("Последний полив") {
                Picker("Последний полив",
                       selection: $last.animation(Motion.appear)) {
                    ForEach(Start.Last.allCases, id: \.self) { answer in
                        Text(answer.title).tag(answer)
                    }
                }
                .pickerStyle(.segmented)
            }

            if last == .unknown {
                SproutDivider()
                    .transition(.opacity)
                SproutBlock("Земля сухая?") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Земля сухая?", selection: $soil) {
                            ForEach(Start.Soil.allCases, id: \.self) { answer in
                                Text(answer.title).tag(Optional(answer))
                            }
                        }
                        .pickerStyle(.segmented)
                        StatusLabel(status: MoistureStatus(
                            moisture: Start.moisture(last: last, soil: soil,
                                                     period: period)))
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.ink)
                    }
                }
                .transition(.blurReplace)
            }

            if !offered.isEmpty {
                SproutDivider()

                DisclosureGroup(isExpanded: $extra.animation(Motion.pill)) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(offered, id: \.self) { chore in
                            choreRow(chore)
                        }
                        Text("Выключенное не будет напоминать. Вернуть можно в настройках растения.")
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 10)
                } label: {
                    Text("Дополнительно")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                }
                .tint(Palette.accent)
                .transition(.blurReplace)
            }
        }
        .animation(Motion.appear, value: offered)
        .sproutRide()
    }

    /// Что вид просит сверх полива: подкормку, пересадку, мелкий уход.
    private var offered: [ExtraCare] {
        let usual = Care.usual(for: Preset.of(wanted))
        var out: [ExtraCare] = []
        if usual.feedEvery != nil { out.append(.feed) }
        if usual.repotEvery != nil { out.append(.repot) }
        out += Duty.allCases.filter { usual.every($0) != nil }.map(ExtraCare.duty)
        return out
    }

    private func choreRow(_ chore: ExtraCare) -> some View {
        HStack(spacing: 12) {
            Label {
                Text(chore.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } icon: {
                Image(systemName: chore.icon)
                    .foregroundStyle(Palette.accent)
            }
            .font(Typography.settingRow)
            .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Toggle(chore.title, isOn: Binding(
                get: { !skipped.contains(chore) },
                set: { on in
                    if on { skipped.remove(chore) } else { skipped.insert(chore) }
                    Feel.pick()
                }))
                .labelsHidden()
        }
    }

    // MARK: - Посадить

    private var plantButton: some View {
        Button { plant() } label: {
            Text("Посадить")
                .font(Typography.detail)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(Palette.accentFill)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
            action: { button.rect = $0 }
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
        // Без листа кадра: «Снять» → затвор → «Посадить». Кадр можно
        // выбрать заново, нажав на миниатюру.
        Task { await take(image) }
    }

    @MainActor
    private func pick(_ chosen: PhotosPickerItem?) async {
        guard let chosen,
              let data = try? await chosen.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        raw = image
        await take(image)
    }

    /// Подсказка не затирает вписанный руками вид; срок подставляется только
    /// вместе с видом.
    @MainActor
    private func take(_ image: UIImage) async {
        withAnimation(Motion.appear) { shot = image }
        looking = true
        let sightings = await Eye.look(at: image)
        let seen = Species.read(sightings)
        withAnimation(Motion.number) {
            guess = seen
            candidates = Species.candidates(sightings)
            looking = false
            if let seen, species.trimmingCharacters(in: .whitespaces).isEmpty {
                species = seen.species
                period = max(seen.dryingDays.rounded(), 1)
            }
        }
        // Кличка про запас: подставится при посадке, если поле пустое.
        if Muse.ready {
            suggestion = await Muse.nickname(for: wanted.isEmpty
                                             ? Lang.text("Комнатное растение")
                                             : wanted)
        }
    }

    /// Вид из каталога: название, срок полива, если он известен, и уход
    /// вида — переключатели «Что ещё делать» снова все включены. Черенок
    /// друга уступает: сроки теперь вида.
    private func sow() {
        guard shown, let asked = Sowing.shared.specimen else { return }
        Sowing.shared.specimen = nil
        withAnimation(Motion.appear) {
            manual = true
            cutting = nil
            species = asked.title
            if let days = asked.watering { period = max(days.rounded(), 1) }
            skipped = []
        }
        Feel.pick()
    }

    private func forget() {
        withAnimation(Motion.appear) {
            // Вид, подсказанный снимком, уходит вместе с ним.
            if let guess, guess.species == species { species = "" }
            shot = nil
            candidates = []
            suggestion = nil
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
        let kind = wanted.isEmpty ? Lang.text("Комнатное растение") : wanted
        // Кличка не обязательна: пусто — предложенная, а без неё — вид.
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = typed.isEmpty ? (suggestion ?? kind) : typed
        let chosen = room.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = chosen.isEmpty ? Lang.text("Дом") : chosen
        let start = Start.moisture(last: last, soil: soil, period: period)
            ?? Start.unsure

        let saved = shot.flatMap { Snapshot.keep($0) }
        // Модель для AR — готовая модель вида: своя, по снимку или сканом,
        // — только если хозяин попросит, на экране растения.
        let seedling = Plant.new(name: nickname, species: kind,
                                 dryingDays: period, shot: saved,
                                 moisture: start)
        withAnimation(Motion.appear) { garden.add(seedling, to: place) }
        Journal.shared.note(.addPlantCompleted)
        if let cutting {
            garden.tend(seedling.id, feedEvery: cutting.feed,
                        repotEvery: cutting.repot, duties: cutting.chores)
        }
        // Отказанный уход — выключен: сроки ноль, «не напоминать».
        if !skipped.isEmpty, let care = garden.plant(id: seedling.id)?.tending {
            var duties: [Duty: Double?] = [:]
            for duty in Duty.allCases where skipped.contains(.duty(duty)) {
                duties[duty] = 0
            }
            garden.tend(seedling.id,
                        feedEvery: skipped.contains(.feed) ? nil : care.feedEvery,
                        repotEvery: skipped.contains(.repot) ? nil : care.repotEvery,
                        duties: duties)
        }
        Cheer.shared.now(from: button.rect)
        Feel.planted()
        typing = false
        // Пола у растения в данных нет — форма нейтральная.
        welcome = Lang.format("%@ — в саду", nickname)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            welcome = nil
        }
        if garden.plantCount == 1 {
            Task { @MainActor in
                let status = await UNUserNotificationCenter.current()
                    .notificationSettings().authorizationStatus
                if status == .notDetermined { reminding = true }
            }
        }
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
            last = .today
            soil = nil
            cutting = nil
            manual = false
            candidates = []
            suggestion = nil
            editingKind = false
            extra = false
        }
    }
}

/// Дело ухода сверх полива, от которого можно отказаться при посадке.
private enum ExtraCare: Hashable {
    case feed, repot
    case duty(Duty)

    var title: String {
        switch self {
        case .feed: Lang.text("Подкормка")
        case .repot: Lang.text("Пересадка")
        case .duty(let duty): duty.title
        }
    }

    var icon: String {
        switch self {
        case .feed: "sparkles"
        case .repot: "arrow.up.bin"
        case .duty(let duty): duty.icon
        }
    }
}
