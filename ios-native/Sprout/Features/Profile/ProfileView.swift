import PhotosUI
import SwiftUI

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

    @State private var grower = Gardener(experience: 0)

    @State private var renaming = false
    @State private var draft = ""

    @State private var opening = false
    @State private var erasing = false

    /// Фото хозяина, выбранное в медиатеке.
    @State private var picking: PhotosPickerItem?

    @State private var trouble: String?

    @State private var welcomed: Rival?

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
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        SproutHead("Профиль", walk: .profile)
                        VStack(alignment: .leading, spacing: Metrics.groupGap) {
                            person
                                .hintSpot(.profilePerson)
                            gardener
                            plot
                                .hintSpot(.profilePlot)
                            awards
                            rivals
                                .hintSpot(.profileRivals)
                            more
                                .hintSpot(.profileMore)
                        }
                        .padding(.horizontal, Metrics.contentMargin)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                    // Ровно в ширину экрана: системная кнопка вставки
                    // просила места больше, чем есть, и весь экран ездил
                    // вбок.
                    .containerRelativeFrame(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .background { SproutBackground() }
                .sproutNotchCover()
                .toolbar(.hidden, for: .navigationBar)
                .walk(.profile, scroll: reader)
            }
        }
        .onAppear { recount() }
        .onChange(of: picking) { _, item in
            Task { await portrait(item) }
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

    private func recount() {
        score = garden.score()
        grower = Gardener.of(log: garden.log, quests: QuestBook.shared.done,
                             medals: Cabinet.shared.total)
    }

    // MARK: - Хозяин

    /// Кружок с фото хозяина — или с буквой, пока фото нет. Нажатие на
    /// кружок открывает медиатеку.
    private var person: some View {
        SproutGroup("Хозяин") {
            HStack(spacing: 14) {
                PhotosPicker(selection: $picking, matching: .images,
                             photoLibrary: .shared()) {
                    avatar
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Circle().fill(Palette.accent))
                                .overlay {
                                    Circle().strokeBorder(Palette.background,
                                                          lineWidth: 1.5)
                                }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Фото")
                .contextMenu {
                    if settings.avatarShot != nil {
                        Button(role: .destructive) { unportrait() } label: {
                            Label("Убрать фото", systemImage: "trash")
                        }
                    }
                }
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

            // Цвет — кружку без фото; с фото выбирать нечего.
            if settings.avatarShot == nil {
                SproutDivider()

                SproutBlock("Цвет") {
                    // Волны отсюда нет нарочно: кружок хозяина не красит ни
                    // узор, ни всплеск.
                    SproutTints(current: settings.avatarTint,
                                spots: swatches) { tint, _ in
                        settings.avatarTint = tint
                        Feel.pick()
                    }
                }
                .transition(.blurReplace)
            }
        }
        .animation(Motion.appear, value: settings.avatarShot)
        .sproutRide()
    }

    /// Фото — кругом во весь кружок; без фото — буква или человечек.
    @ViewBuilder
    private var avatar: some View {
        if let name = settings.avatarShot, let image = Snapshot.image(name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: Metrics.avatar, height: Metrics.avatar)
                .clipShape(Circle())
                .transition(.blurReplace)
        } else {
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
                .transition(.blurReplace)
        }
    }

    /// Квадрат из середины снимка, ужатый, — в папку снимков; прежнее фото
    /// уходит с диска.
    @MainActor
    private func portrait(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        let width = Double(image.size.width)
        let height = Double(image.size.height)
        let side = min(width, height)
        let square = Snapshot.cut(image, to: Crop(x: (width - side) / 2,
                                                  y: (height - side) / 2,
                                                  side: side))
        guard let name = Snapshot.keep(square) else { return }
        let old = settings.avatarShot
        settings.avatarShot = name
        if let old { Shots.drop(old) }
        picking = nil
        Feel.done()
    }

    private func unportrait() {
        guard let old = settings.avatarShot else { return }
        settings.avatarShot = nil
        Shots.drop(old)
        Feel.toss()
    }

    private var letter: String {
        String(garden.owner.trimmingCharacters(in: .whitespaces)
            .prefix(1)).uppercased(with: Locale.current)
    }

    // MARK: - Садовник

    /// Титул и уровень с оранжереей; подробности — на своём экране.
    private var gardener: some View {
        SproutGroup("Садовник") {
            NavigationLink { GardenerView() } label: {
                HStack(spacing: 12) {
                    GlasshouseView(house: grower.glasshouse)
                        .frame(width: 70)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(grower.title)
                            .font(Typography.settingRow.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(Lang.format("Уровень %lld", grower.level))
                            .font(Typography.settingNote)
                            .foregroundStyle(.secondary)
                        ProgressView(value: grower.progress)
                            .tint(Palette.green)
                    }
                    Image(systemName: "chevron.right")
                        .font(Typography.settingNote)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sproutRide()
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

    // MARK: - Награды

    /// Последние медали рядком и ссылка на полку — как сводка в «Фитнесе».
    private var awards: some View {
        SproutGroup("Награды") {
            NavigationLink { AwardsView() } label: {
                HStack(spacing: 10) {
                    if latest.isEmpty {
                        MedalBadge(rank: Rank(.drops, 1), earned: false)
                            .frame(width: 44, height: 44)
                        Text("Первая — за первый полив")
                            .font(Typography.settingNote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(latest) { rank in
                            MedalBadge(rank: rank, earned: true)
                                .frame(width: 44, height: 44)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(Lang.format("%1$lld из %2$lld",
                                     Cabinet.shared.total, Award.total))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(Typography.settingNote)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sproutRide()
    }

    /// Четыре последние — больше в строку не встанет.
    private var latest: [Rank] {
        Array(Cabinet.shared.latest.prefix(4))
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
                .fixedSize()
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
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 16, alignment: .trailing)
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
    }
}
