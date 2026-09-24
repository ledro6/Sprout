import SwiftUI
import UniformTypeIdentifiers

/// Профиль: хозяин, сад и соперники. Учётной записи нет, и экран её не
/// изображает: «вход» — это замок на приложении, он в настройках, а соперники
/// приходят перепиской, см. `Rival`.
struct ProfileView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.scenePhase) private var phase

    private let settings = Settings.shared
    private let friends = Friends.shared

    /// Итог по поливам — не в теле: сад сушится раз в секунду.
    @State private var score = Score()

    @State private var renaming = false
    @State private var draft = ""

    @State private var opening = false
    @State private var erasing = false
    @State private var importing = false

    @State private var trouble: String?

    @State private var welcomed: Rival?

    /// Пересобирается при каждом появлении экрана, чтобы слепок был свежим.
    @State private var backup: URL?

    @State private var swatches = Spots()
    @State private var paste = Spot()

    private var me: Rival {
        // Подписью, а не именем: неназвавшийся тоже должен попасть в таблицу
        // и в код.
        Rival.mine(owner: garden.signed, score: score,
                   plants: garden.plantCount)
    }

    private var named: Bool { !garden.owner.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SproutHead("Профиль")
                    VStack(alignment: .leading, spacing: Metrics.groupGap) {
                        person
                        plot
                        rivals
                        more
                    }
                    .padding(.horizontal, Metrics.contentMargin)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .background { SproutBackground() }
            .sproutNotchCover()
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            recount()
            makeBackup()
        }
        .onChange(of: garden.log.count) { _, _ in
            withAnimation(Motion.number) { recount() }
        }
        .onChange(of: phase) { _, now in
            if now == .active { recount() }
        }
        .sheet(isPresented: $opening) { SettingsView() }
        .alert("Как вас зовут?", isPresented: $renaming) {
            TextField("Имя", text: $draft)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить") {
                garden.rename(owner: draft)
                Feel.done()
            }
        } message: {
            Text("Имя стоит в профиле и уходит вместе со счётом друзьям.")
        }
    }

    private func recount() { score = garden.score() }

    // MARK: - Хозяин

    /// Кружок с буквой, а не фото: Sprout про растения, а не про людей.
    private var person: some View {
        SproutGroup("Хозяин") {
            HStack(spacing: 14) {
                Circle()
                    .fill(Palette.swatch(settings.avatarTint))
                    .frame(width: Metrics.avatar, height: Metrics.avatar)
                    .overlay {
                        // Неназвавшемуся — значок человека: пустой кружок
                        // читался бы недогрузившейся картинкой.
                        if named {
                            Text(letter)
                                .font(Typography.avatar)
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .font(Typography.avatar)
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(named ? garden.owner : Lang.text("Имя не задано"))
                        .font(Typography.navTitle)
                        .foregroundStyle(named ? Palette.ink : .secondary)
                        .lineLimit(1)
                    Text(named
                         ? Lang.format("Сад с %@", garden.since.formatted(
                             .dateTime.day().month(.wide).year()))
                         : Lang.text("Назовитесь — имя встретит вас при запуске"))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(named ? "Изменить" : "Назвать") {
                    draft = garden.owner
                    renaming = true
                }
                .buttonStyle(.glass)
                .font(Typography.settingNote)
            }

            SproutDivider()

            SproutBlock("Цвет") {
                // Волны отсюда нет нарочно: кружок хозяина не красит ни узор,
                // ни всплеск.
                SproutTints(current: settings.avatarTint,
                            spots: swatches) { tint, _ in
                    settings.avatarTint = tint
                    Feel.pick()
                }
            }
        }
        .sproutRide()
    }

    private var letter: String {
        String(garden.owner.trimmingCharacters(in: .whitespaces)
            .prefix(1)).uppercased(with: Locale.current)
    }

    // MARK: - Сад

    /// Размер сада. Поливы — только на экране статистики, чтобы одна и та же
    /// правда не жила в двух местах.
    private var plot: some View {
        SproutGroup("Сад") {
            Grid(alignment: .leading, horizontalSpacing: 12) {
                GridRow {
                    SproutFigure("Растений", garden.plantCount)
                    SproutFigure("Комнат", garden.rooms.count)
                    SproutFigure("Дней", age)
                }
            }
        }
        .sproutRide()
    }

    /// По календарю, а не делением секунд: сутки бывают в 23 и 25 часов.
    private var age: Int {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: garden.since)
        let to = calendar.startOfDay(for: Date())
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    // MARK: - Друзья

    private var rivals: some View {
        SproutGroup("Друзья") {
            table

            SproutDivider()

            HStack(spacing: 10) {
                ShareLink(item: me.card) {
                    Label("Позвать", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glass)

                // Системная кнопка вставки не показывает баннера «вставлено
                // из…»; своя, читающая буфер сама, дёргала бы предупреждение
                // iOS.
                PasteButton(payloadType: String.self) { items in
                    guard let text = items.first else { return }
                    Task { @MainActor in invite(text) }
                }
                .buttonBorderShape(.capsule)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                    action: { paste.rect = $0 }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sproutRide()
        .alert("Не вышло", isPresented: Binding(
            get: { trouble != nil },
            set: { if !$0 { trouble = nil } }
        )) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(trouble ?? "")
        }
        .alert(welcomed?.name ?? "", isPresented: Binding(
            get: { welcomed != nil },
            set: { if !$0 { welcomed = nil } }
        )) {
            Button("Хорошо", role: .cancel) {}
        } message: {
            Text(Lang.format("Счёт от %@. Обновится, когда друг пришлёт код снова.",
                             stamp(welcomed)))
        }
    }

    private func stamp(_ rival: Rival?) -> String {
        guard let rival else { return "" }
        return rival.stamp.formatted(.dateTime.day().month(.wide))
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: Metrics.rowGap) {
            ForEach(Array(standings.enumerated()), id: \.element.id) { item in
                if item.offset > 0 { SproutDivider() }
                if item.element.id == me.id {
                    row(item.offset + 1, item.element)
                        .transition(.blurReplace)
                } else {
                    // Меню только на чужой строке: пустое на своей всё равно
                    // открывалось бы.
                    row(item.offset + 1, item.element)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation(Motion.pill) {
                                    friends.remove(item.element.id)
                                }
                            } label: {
                                Label("Убрать из таблицы",
                                      systemImage: "person.slash")
                            }
                        }
                        .transition(.blurReplace)
                }
            }
        }
    }

    /// Своя строка пересчитывается на каждом поливе, чужие — какими их
    /// прислали.
    private var standings: [Rival] {
        ([me] + friends.rivals.filter { $0.id != me.id })
            .sorted { ($0.total, $1.name) > ($1.total, $0.name) }
    }

    private func row(_ place: Int, _ rival: Rival) -> some View {
        HStack(spacing: 10) {
            Text(place.formatted())
                .font(Typography.figureCaption)
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
                .frame(width: 16, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                Text(rival.name)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(note(for: rival))
                    .font(Typography.figureCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(rival.total.formatted())
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(Lang.format("череда %lld", rival.streak))
                    .font(Typography.figureCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Чужая строка свежа настолько, насколько свеж код, — об этом говорит
    /// дата под кличкой.
    private func note(for rival: Rival) -> String {
        guard rival.id != me.id else { return Lang.text("вы") }
        return Lang.format("счёт от %@", rival.stamp.formatted(
            .dateTime.day().month(.abbreviated)))
    }

    /// Удалось — от кнопки вставки идёт волна.
    private func invite(_ text: String) {
        guard let rival = friends.take(text, mine: garden.owner) else {
            trouble = Rival.read(text) == nil
                ? Lang.text("""
                    В скопированном нет кода Sprout. Скопируйте сообщение \
                    друга целиком — код лежит в нём последней строкой.
                    """)
                : Lang.text("Это ваш собственный код: в таблице вы и так есть.")
            Feel.wrong()
            return
        }
        withAnimation(Motion.pill) { welcomed = rival }
        Cheer.shared.now(from: paste.rect)
        Feel.done()
    }

    // MARK: - Ещё

    private var more: some View {
        SproutGroup("Ещё") {
            Button { opening = true } label: {
                SproutLink("Настройки", icon: "gearshape")
            }
            .buttonStyle(.plain)

            SproutDivider()

            if let backup {
                ShareLink(item: backup) {
                    SproutLink("Сохранить сад в файл",
                               icon: "square.and.arrow.down")
                }
                .buttonStyle(.plain)

                SproutDivider()
            }

            Button { importing = true } label: {
                SproutLink("Перенести сад из файла", icon: "tray.and.arrow.up")
            }
            .buttonStyle(.plain)

            SproutDivider()

            Button(role: .destructive) { erasing = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(Typography.settingRow)
                        .frame(width: 24)
                    Text("Стереть сад")
                        .font(Typography.settingRow)
                    Spacer(minLength: 8)
                }
                .foregroundStyle(.red)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sproutRide()
        .confirmationDialog("Стереть сад?", isPresented: $erasing,
                            titleVisibility: .visible) {
            Button("Стереть", role: .destructive) { garden.erase() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Исчезнут все растения и весь журнал поливов. Вернуть их будет нельзя.")
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.json]) { result in
            take(file: result)
        }
    }

    /// Во временную папку: файл живёт до отправки, и прибирает его система.
    private func makeBackup() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(garden.state) else { return }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(Lang.format("Сад — %@", garden.owner) + ".json")
        guard (try? data.write(to: file, options: .atomic)) != nil else {
            return
        }
        backup = file
    }

    /// Файл из чужой песочницы читается только с запросом доступа, иначе
    /// система откажет молча.
    private func take(file result: Result<URL, any Error>) {
        guard case let .success(url) = result else { return }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(GardenState.self,
                                                    from: data)
        else {
            trouble = Lang.text("Это не файл сада Sprout.")
            Feel.wrong()
            return
        }
        withAnimation(Motion.appear) { garden.restore(state) }
        recount()
        makeBackup()
        Feel.done()
    }
}
