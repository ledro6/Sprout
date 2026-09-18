import PhotosUI
import SwiftUI
import UIKit

/// Добавить растение: снимок, кличка, вид, комната и как часто поливать.
///
/// Снимок разглядывает сам телефон — классификатор Apple из Vision, — и по
/// увиденному подсказывает вид и срок полива. Подсказывает, а не решает:
/// оба поля правятся руками. Если на телефоне есть Apple Intelligence,
/// здесь же появляется языковая модель: она придумывает кличку и пишет
/// совет по уходу. Обе считают прямо на телефоне и ничего никуда не
/// отправляют — иначе им здесь было бы не место, см. политику
/// конфиденциальности.
///
/// Собран из тех же плашек, что настройки, статистика и профиль, лежит на
/// том же узоре и подпрыгивает на той же волне полива.
struct AddView: View {
    @Environment(Garden.self) private var garden

    /// Выбранный снимок и то, чем его выбирали.
    @State private var item: PhotosPickerItem?
    @State private var shot: UIImage?
    @State private var shooting = false

    /// Что система разглядела на снимке. Пусто — не разглядела ничего
    /// знакомого, и подсказывать нечего.
    @State private var guess: Guess?
    @State private var looking = false

    @State private var name = ""
    @State private var species = ""
    @State private var room = ""
    @State private var period: Double = 7

    /// Заводят новую комнату.
    @State private var naming = false
    @State private var newRoom = ""

    /// Совет от языковой модели и то, что она сейчас думает.
    @State private var care: String?
    @State private var thinking = false

    /// Кого только что посадили — чтобы сказать об этом.
    ///
    /// Вместе с готовой строкой, а не одной кличкой: поля к тому времени
    /// уже очищены под следующее растение, и собирать строку из них было
    /// бы поздно — она рассказала бы про пустую форму.
    @State private var planted: Planted?

    /// Что сказать о только что посаженном.
    private struct Planted {
        var name: String
        var note: String
    }

    /// Где кнопка «Посадить»: оттуда по узору идёт волна.
    @State private var button = Spot()

    @FocusState private var typing: Bool

    private var rooms: [String] { garden.rooms.map(\.name) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle("Добавить")
                    VStack(alignment: .leading, spacing: Metrics.groupGap) {
                        picture
                        about
                        habits
                        advice
                        plantButton
                    }
                    .padding(.horizontal, Metrics.contentMargin)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            // Клавиатура уезжает от движения пальца — иначе до кнопки
            // «Посадить» из последнего поля не добраться.
            .scrollDismissesKeyboard(.interactively)
            .background { SproutBackground() }
            .sproutNotchCover()
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { if room.isEmpty { room = rooms.first ?? "Дом" } }
        .fullScreenCover(isPresented: $shooting) {
            Camera { image in Task { await take(image) } }
                .ignoresSafeArea()
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

            // Все три в строку, и ни одна не переносится по слогам.
            //
            // Три подписи в ряд на узкий телефон не встают: «Снять»
            // разрывалось на «Сня-» и «ть». Поэтому у третьей кнопки
            // подписи нет вовсе — крестик говорит сам за себя, а вслух
            // его называет `accessibilityLabel`; у двух оставшихся подписи
            // короткие и запрет на перенос стоит явно.
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
            }
        }
        .sproutRide()
        .onChange(of: item) { _, chosen in
            Task { await pick(chosen) }
        }
    }

    /// Квадрат, в котором лежит снимок. Пока его нет — росток на стекле:
    /// то же место, та же форма, и видно, куда встанет фотография.
    private var well: some View {
        ZStack {
            if let shot {
                Image(uiImage: shot)
                    .resizable()
                    .scaledToFill()
            } else {
                SproutPiece(index: 0)
                    .fill(Palette.ink.opacity(Metrics.pieceOff))
                    .frame(width: 64, height: 64)
            }
            if looking {
                // Пока система разглядывает снимок — системный кружок
                // ожидания поверх него.
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
        .accessibilityLabel(shot == nil ? "Снимка нет" : "Снимок растения")
    }

    /// Что система разглядела — строкой под кнопками.
    ///
    /// С долей уверенности, а не просто «это кактус». Классификатор
    /// ошибается, и выдавать его догадку за ответ значит врать: он
    /// различает кактус и папоротник, но замиокулькас от сансевиерии не
    /// отличит.
    private var sighting: String? {
        guard shot != nil, !looking else { return nil }
        guard let guess else {
            return "Растения на снимке телефон не узнал — впишите вид сами."
        }
        let sure = Int((guess.confidence * 100).rounded())
        return "Телефон думает, что это \(guess.species.lowercased())"
            + " — уверен на \(sure)%. Поправьте, если не он."
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
                    field(room.isEmpty ? "Выбрать" : room)
                }
            }

            SproutDivider()

            SproutBlock(
                "Полив",
                note: "За этот срок земля высыхает досуха. Проценты на "
                    + "карточке убывают ровно с такой скоростью."
            ) {
                Picker("Полив", selection: $period) {
                    ForEach(Species.periods, id: \.self) { days in
                        Text(Species.periodLabel(days)).tag(days)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sproutRide()
    }

    /// Строка выбора под меню — тем же синим, что и остальные выборы.
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

    // MARK: - Совет

    /// Совет по уходу — от языковой модели Apple, если она на этом
    /// телефоне есть. Если её нет, здесь стоит объяснение, а не
    /// неработающая кнопка.
    @ViewBuilder
    private var advice: some View {
        if Muse.ready {
            SproutGroup("Совет") {
                Button { Task { await counsel() } } label: {
                    Label(care == nil ? "Как за ним ухаживать"
                          : "Спросить ещё раз",
                          systemImage: "sparkles")
                }
                .buttonStyle(.glass)
                .disabled(thinking || wanted.isEmpty)

                if thinking {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let care {
                    Paragraph(care)
                }

                Paragraph("Пишет языковая модель Apple прямо на телефоне, "
                          + "без сети. Она может ошибаться — сверяйтесь.")
            }
            .sproutRide()
        } else {
            SproutGroup("Совет") {
                Paragraph("Совет по уходу пишет языковая модель Apple "
                          + "Intelligence прямо на телефоне. На этом "
                          + "телефоне её нет: нужен iPhone 15 Pro или "
                          + "новее и включённый Apple Intelligence. Вид "
                          + "растения при этом узнаётся и здесь — это "
                          + "делает Vision, и ему хватает любого телефона.")
            }
            .sproutRide()
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
        .buttonStyle(.glass)
        .controlSize(.large)
        .tint(Palette.accent)
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
            action: { button.rect = $0 }
        .sproutRide()
    }

    // MARK: - Что происходит

    /// Вид, по которому спрашивают модель: вписанный руками, а если поле
    /// пустое — тот, что подсказал классификатор.
    private var wanted: String {
        let typed = species.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? (guess?.species ?? "") : typed
    }

    @MainActor
    private func pick(_ chosen: PhotosPickerItem?) async {
        guard let chosen,
              let data = try? await chosen.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        await take(image)
    }

    /// Принять снимок и дать телефону его разглядеть.
    ///
    /// Подсказка не затирает вписанное руками: если вид уже вписан, его
    /// оставляют как есть. Срок полива подставляется только вместе с
    /// видом — сам по себе он ничего не значит.
    @MainActor
    private func take(_ image: UIImage) async {
        withAnimation(Motion.appear) {
            shot = image
            care = nil
        }
        looking = true
        let seen = await Eye.guess(image)
        withAnimation(Motion.number) {
            guess = seen
            looking = false
            if let seen, species.trimmingCharacters(in: .whitespaces).isEmpty {
                species = seen.species
                period = Species.period(near: seen.dryingDays)
            }
        }
    }

    private func forget() {
        withAnimation(Motion.appear) {
            shot = nil
            item = nil
            guess = nil
        }
    }

    @MainActor
    private func invent() async {
        thinking = true
        let word = await Muse.nickname(for: wanted.isEmpty
                                       ? "комнатное растение" : wanted)
        thinking = false
        guard let word else { return }
        withAnimation(Motion.pill) { name = word }
    }

    @MainActor
    private func counsel() async {
        thinking = true
        let text = await Muse.care(for: wanted)
        thinking = false
        guard let text else { return }
        withAnimation(Motion.appear) { care = text }
    }

    /// Посадить.
    ///
    /// Снимок кладётся на диск только здесь, в последний миг: выбранных и
    /// передуманных снимков за сеанс бывает несколько, и складывать в
    /// Documents все значило бы копить мусор, который никто не уберёт.
    private func plant() {
        let nickname = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else { return }
        let kind = wanted.isEmpty ? "Комнатное растение" : wanted
        let chosen = room.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = chosen.isEmpty ? "Дом" : chosen
        let days = Int(period.rounded())

        let saved = shot.flatMap { Snapshot.keep($0) }
        let seedling = Plant.new(name: nickname, species: kind,
                                 dryingDays: period, shot: saved)
        withAnimation(Motion.appear) { garden.add(seedling, to: place) }
        // Новое растение — событие, а события здесь показываются волной.
        Cheer.shared.now(from: button.rect)
        typing = false
        planted = Planted(
            name: nickname,
            note: "Растёт в комнате «\(place)». Полито, следующий полив "
                + "через \(days) "
                + Plant.plural(days, "день", "дня", "дней") + ".")
        reset()
    }

    /// Поля под следующее растение. Комната остаётся: сажают обычно
    /// подряд и в одно место.
    private func reset() {
        withAnimation(Motion.appear) {
            name = ""
            species = ""
            shot = nil
            item = nil
            guess = nil
            care = nil
            period = 7
        }
    }
}
