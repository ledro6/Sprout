import SwiftUI
import UniformTypeIdentifiers

/// Профиль: хозяин, его сад, соперники и замок.
///
/// Учётной записи у Sprout нет — ни сервера, ни регистрации, ни облака, —
/// и экран этого не изображает. «Вход» здесь один настоящий: замок на
/// приложении, который открывает система по лицу или код-паролю.
/// Соревнование с друзьями тоже настоящее, только идёт оно перепиской:
/// друг присылает свой счёт строкой, вы вставляете её, и он встаёт в
/// таблицу рядом с вами — см. `Rival`.
///
/// Собран из тех же плашек, что настройки и статистика, лежит на том же
/// узоре и подпрыгивает на той же волне полива.
struct ProfileView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.scenePhase) private var phase

    private let settings = Settings.shared
    private let friends = Friends.shared
    private let lock = Lock.shared

    /// Итог по поливам — см. `StatsView`: в теле его считать нельзя, сад
    /// сушится раз в секунду.
    @State private var score = Score()

    @State private var renaming = false
    @State private var draft = ""

    @State private var opening = false
    @State private var erasing = false
    @State private var importing = false

    /// Что пошло не так при вставке кода. Пусто — всё сошлось.
    @State private var trouble: String?

    /// Кого только что позвали в соперники — чтобы сказать об этом.
    @State private var welcomed: Rival?

    /// Файл с садом для отправки. Пересобирается при каждом появлении
    /// экрана: сад меняется, а слепок должен быть свежим.
    @State private var backup: URL?

    /// Замеры кружков цвета и кнопки вставки — оттуда расходится волна.
    @State private var swatches = Spots()
    @State private var paste = Spot()

    private var me: Rival {
        Rival.mine(owner: garden.owner, score: score,
                   plants: garden.plantCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle("Профиль")
                    VStack(alignment: .leading, spacing: Metrics.groupGap) {
                        person
                        plot
                        rivals
                        padlock
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
            // Вдруг Face ID настроили, пока приложение было открыто.
            lock.refresh()
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
            Button("Сохранить") { garden.rename(owner: draft) }
        } message: {
            Text("Имя стоит в профиле и уходит вместе со счётом друзьям.")
        }
    }

    private func recount() { score = garden.score() }

    // MARK: - Хозяин

    /// Кружок с буквой, имя и день, с которого ведётся сад.
    ///
    /// Кружок с буквой, а не фотография: фотографии хозяина у приложения
    /// нет и спрашивать её незачем — Sprout про растения, а не про людей.
    /// Буква же есть всегда, и цвет ей выбирают тут же, ниже.
    private var person: some View {
        SproutGroup("Хозяин") {
            HStack(spacing: 14) {
                Circle()
                    .fill(Palette.swatch(settings.avatarTint))
                    .frame(width: Metrics.avatar, height: Metrics.avatar)
                    .overlay {
                        Text(letter)
                            .font(Typography.avatar)
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(garden.owner)
                        .font(Typography.navTitle)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text("Сад с "
                         + garden.since.formatted(.dateTime.day().month(.wide)
                             .year()))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Изменить") {
                    draft = garden.owner
                    renaming = true
                }
                .buttonStyle(.glass)
                .font(Typography.settingNote)
            }

            SproutDivider()

            SproutBlock("Цвет") {
                // Волны отсюда не идёт, и нарочно. Волна показывает цвет
                // узора и цвет всплеска; кружок хозяина ни тем, ни другим
                // не красится, и волна в чужом цвете обещала бы не то, что
                // выбрали. Сам кружок при этом перетекает пружиной — её
                // ставит `SproutTints`.
                SproutTints(current: settings.avatarTint,
                            spots: swatches) { tint, _ in
                    settings.avatarTint = tint
                    Feel.pick()
                }
            }
        }
        .sproutRide()
    }

    /// Первая буква имени. Пустого имени сад не сохраняет, но на всякий
    /// случай у кружка есть и запасная.
    private var letter: String {
        String(garden.owner.trimmingCharacters(in: .whitespaces)
            .prefix(1)).uppercased(with: Locale.current)
    }

    // MARK: - Сад

    /// Размер сада тремя числами. Поливы сюда не идут — им отведён целый
    /// экран статистики, и повторять его тут значило бы заводить второе
    /// место, где та же правда может разойтись.
    private var plot: some View {
        SproutGroup("Сад") {
            Grid(alignment: .leading, horizontalSpacing: 12) {
                GridRow {
                    SproutFigure(garden.plantCount, "Растений")
                    SproutFigure(garden.rooms.count, "Комнат")
                    SproutFigure(age, "Дней")
                }
            }
        }
        .sproutRide()
    }

    /// Сколько суток саду. По календарю, а не делением секунд: сутки
    /// бывают в 23 и 25 часов, и на переводе часов деление ошиблось бы.
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

                // Системная кнопка вставки: она не спрашивает разрешения
                // и не показывает баннера «вставлено из…», потому что
                // нажал её человек, а не приложение. Своя кнопка, читающая
                // буфер сама, каждый раз дёргала бы предупреждение iOS.
                PasteButton(payloadType: String.self) { items in
                    guard let text = items.first else { return }
                    Task { @MainActor in invite(text) }
                }
                .buttonBorderShape(.capsule)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                    action: { paste.rect = $0 }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Paragraph("Сервера у Sprout нет, и учётной записи тоже. "
                      + "«Позвать» готовит сообщение с вашим счётом — "
                      + "отправьте его другу любым мессенджером. Друг "
                      + "пришлёт своё в ответ, вы скопируете его и "
                      + "нажмёте «Вставить»: его результат встанет в "
                      + "таблицу. Обновится он, когда друг пришлёт код "
                      + "снова.")
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
            Text("Счёт от " + stamp(welcomed)
                 + ". Обновится, когда друг пришлёт код снова.")
        }
    }

    /// День, которым помечен присланный счёт.
    private func stamp(_ rival: Rival?) -> String {
        guard let rival else { return "" }
        return rival.stamp.formatted(.dateTime.day().month(.wide))
    }

    /// Таблица: вы и все, кого позвали, от большего счёта к меньшему.
    private var table: some View {
        VStack(alignment: .leading, spacing: Metrics.rowGap) {
            ForEach(Array(standings.enumerated()), id: \.element.id) { item in
                if item.offset > 0 { SproutDivider() }
                if item.element.id == me.id {
                    row(item.offset + 1, item.element)
                } else {
                    // Меню только на чужой строке: пустое контекстное меню
                    // на своей всё равно открывалось бы по долгому нажатию,
                    // показывая пустоту.
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
                }
            }
        }
    }

    /// Вы и соперники в одном порядке. Своя строка считается заново на
    /// каждом поливе, чужие стоят такими, какими их прислали.
    private var standings: [Rival] {
        ([me] + friends.rivals.filter { $0.id != me.id })
            .sorted { ($0.total, $1.name) > ($1.total, $0.name) }
    }

    private func row(_ place: Int, _ rival: Rival) -> some View {
        HStack(spacing: 10) {
            Text("\(place)")
                .font(Typography.figureCaption)
                .foregroundStyle(.tertiary)
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
                Text("\(rival.total)")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("череда \(rival.streak)")
                    .font(Typography.figureCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Подпись под кличкой: у себя — «вы», у соперника — день, которым
    /// помечен присланный счёт. Своя строка живая, чужая настолько свежа,
    /// насколько свеж код, и умалчивать об этом нельзя.
    private func note(for rival: Rival) -> String {
        guard rival.id != me.id else { return "вы" }
        return "счёт от "
            + rival.stamp.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Разобрать вставленное и поставить в таблицу.
    ///
    /// Удалось — по узору идёт волна от кнопки вставки: новый соперник
    /// это событие, а события здесь показываются волной.
    private func invite(_ text: String) {
        guard let rival = friends.take(text, mine: garden.owner) else {
            trouble = Rival.read(text) == nil
                ? "В скопированном нет кода Sprout. Скопируйте сообщение "
                    + "друга целиком — код лежит в нём последней строкой."
                : "Это ваш собственный код: в таблице вы и так есть."
            Feel.wrong()
            return
        }
        withAnimation(Motion.pill) { welcomed = rival }
        Cheer.shared.now(from: paste.rect)
        Feel.done()
    }

    // MARK: - Замок

    private var padlock: some View {
        SproutGroup("Замок") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Запирать приложение")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    Text(lockNote)
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                // Подпись настоящая, хоть и спрятана: её читает вслух
                // VoiceOver — переключатель без неё зовётся просто
                // «переключатель».
                Toggle("Запирать приложение",
                       isOn: Binding(get: { lock.on },
                                     set: { lock.on = $0 }))
                    .labelsHidden()
                    .disabled(!lock.ready)
            }

            if lock.on {
                SproutDivider()

                Button {
                    lock.close()
                } label: {
                    SproutLink("Запереть сейчас", icon: "lock.fill")
                }
                .buttonStyle(.plain)
            }

            Paragraph("Это и есть здешние «вход» и «выход». Учётной "
                      + "записи у Sprout нет: регистрироваться негде, "
                      + "забыть нечего, а сад лежит только на этом "
                      + "телефоне.")
        }
        .sproutRide()
    }

    /// Что написано под переключателем замка.
    private var lockNote: String {
        guard lock.ready else {
            return "На этом телефоне не настроен ни Face ID, ни код-пароль "
                + "— запирать нечем."
        }
        return "Открывать по \(lock.means)."
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

            Paragraph("Файл — это весь сад целиком: растения, комнаты и "
                      + "журнал поливов. Им сад переносят на другой "
                      + "телефон.")
        }
        .sproutRide()
        .confirmationDialog("Стереть сад?", isPresented: $erasing,
                            titleVisibility: .visible) {
            Button("Стереть", role: .destructive) { garden.erase() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Исчезнут все растения и весь журнал поливов. "
                 + "Вернуть их будет нельзя.")
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.json]) { result in
            take(file: result)
        }
    }

    /// Слепок сада во временный файл — его и отдаёт «Сохранить».
    ///
    /// Во временную папку, а не рядом с самим садом: этот файл живёт
    /// ровно до отправки, и место ему там, где система сама приберёт.
    private func makeBackup() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(garden.state) else { return }
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("Сад — \(garden.owner).json")
        guard (try? data.write(to: file, options: .atomic)) != nil else {
            return
        }
        backup = file
    }

    /// Принять сад из файла.
    ///
    /// Файл приходит из чужой песочницы, и читать его можно только
    /// попросив доступ — иначе система откажет молча, а экран показал бы
    /// «файл не читается» на целом файле.
    private func take(file result: Result<URL, any Error>) {
        guard case let .success(url) = result else { return }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(GardenState.self,
                                                    from: data)
        else {
            trouble = "Это не файл сада Sprout."
            Feel.wrong()
            return
        }
        withAnimation(Motion.appear) { garden.restore(state) }
        recount()
        makeBackup()
        Feel.done()
    }
}
