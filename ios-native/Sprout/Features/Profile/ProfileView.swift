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

    /// Остальное о саде для кода и сравнения — тоже не в теле.
    @State private var kinds = 0
    @State private var aim: Int?

    /// Сад друга рядом со своим.
    @State private var comparing: Rival?
    /// Вставили челлендж — сказать, во что вступили.
    @State private var joined: Race?

    @State private var editing = false

    /// Открытка «Моя оранжерея» — см. `PosterSheet`.
    @State private var posting = false

    @State private var opening = false
    @State private var erasing = false


    @State private var trouble: String?

    @State private var welcomed: Rival?

    @State private var paste = Spot()

    private var me: Rival {
        // Подписью, а не именем: неназвавшийся тоже должен попасть в таблицу
        // и в код.
        Rival.mine(owner: garden.signed, score: score,
                   plants: garden.plantCount, level: grower.level,
                   medals: Cabinet.shared.total, kinds: kinds, aim: aim,
                   weeks: QuestBook.shared.full,
                   race: friends.current().map { $0.score(garden.log) })
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
                            // Общий сад — только когда iCloud в сборке
                            // включён, см. `Kinship.enabled`.
                            if Kinship.enabled {
                                FamilyGroup()
                            }
                            awards
                            // Погибшие растения — с «Вернуть из архива».
                            if !garden.archive.isEmpty {
                                ArchiveGroup()
                            }
                            rivals
                                .hintSpot(.profileRivals)
                            more
                                .hintSpot(.profileMore)
                        }
                        .padding(.horizontal, Metrics.contentMargin)
                        .padding(.top, 8)
                        .padding(.bottom, Metrics.barGap)
                    }
                    // Ровно в ширину экрана: системная кнопка вставки
                    // просила места больше, чем есть, и весь экран ездил
                    // вбок.
                    .containerRelativeFrame(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                // Вход во вкладку — плавно; фон стоит.
                .modifier(TabEntrance())
                .background { SproutBackground() }
                .sproutSoftTop()
                .toolbar(.hidden, for: .navigationBar)
                .walk(.profile, scroll: reader)
            }
        }
        .onAppear { recount() }
        .onChange(of: garden.log.count) { _, _ in
            withAnimation(Motion.number) { recount() }
        }
        .onChange(of: phase) { _, now in
            if now == .active { recount() }
        }
        .sheet(isPresented: $opening) { SettingsView() }
        .sheet(isPresented: $editing) {
            ProfileEditor()
                .environment(garden)
        }
    }

    private func recount() {
        score = garden.score()
        grower = Gardener.of(log: garden.log, quests: QuestBook.shared.done,
                             medals: Cabinet.shared.total)
        kinds = Set(garden.rooms.flatMap(\.plants).compactMap {
            Preset.known($0.species)
        }).count
        aim = Rival.aim(garden.log)
    }

    // MARK: - Хозяин

    /// Кружок с фото хозяина — или с буквой, пока фото нет. Нажатие на
    /// кружок, как и «Изменить», открывает лист `ProfileEditor`: фото, имя
    /// и цвет кружка.
    private var person: some View {
        SproutGroup("Вы") {
            HStack(spacing: 14) {
                Button { editing = true } label: {
                    AvatarCircle(size: Metrics.avatar)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Изменить профиль")
                VStack(alignment: .leading, spacing: 3) {
                    Text(named ? garden.owner : Lang.text("Имя не задано"))
                        .font(Typography.navTitle)
                        .foregroundStyle(named ? Palette.ink : Palette.secondaryText)
                        .lineLimit(1)
                    Text(named
                         ? Lang.format("Садовод с %@", garden.since.formatted(
                             .dateTime.day().month(.wide).year()))
                         : Lang.text("Назовитесь — имя встретит вас при запуске"))
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 8)
                Button(named ? "Изменить" : "Назвать") { editing = true }
                .buttonStyle(.glass)
                .font(Typography.settingNote)
            }
        }
        .animation(Motion.appear, value: settings.avatarShot)
        .sproutRide()
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
                            .foregroundStyle(Palette.secondaryText)
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

            SproutDivider()

            Button { posting = true } label: {
                SproutLink("Моя оранжерея — открыткой",
                           icon: "photo.on.rectangle")
            }
            .buttonStyle(.plain)
        }
        .sproutRide()
        .sheet(isPresented: $posting) {
            PosterSheet(poster: .garden).environment(garden)
        }
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
                            .foregroundStyle(Palette.secondaryText)
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
                        .foregroundStyle(Palette.secondaryText)
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

            if let race = friends.current() {
                SproutDivider()
                RaceCard(race: race, places: friends.standings(race, mine: me),
                         mine: me.card) {
                    withAnimation(Motion.pill) { friends.leave(race.id) }
                    Feel.toss()
                }
                .transition(.blurReplace)
            }

            SproutDivider()

            HStack(spacing: 10) {
                // Значком: подписи «Позвать» и «Испытание» рядом с
                // «Вставить» в строку не помещались. Счёт испытания в этом
                // коде не едет — его шлёт «Отправить счёт» в карточке
                // испытания: чужим он по умолчанию не виден.
                ShareLink(item: plainCard) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)

                Menu {
                    ForEach(Race.kinds) { quest in
                        Button(Race.title(quest)) { challenge(quest) }
                    }
                } label: {
                    Label("Испытание", systemImage: "flag.checkered")
                        .lineLimit(1)
                }
                .buttonStyle(.glass)
                .fixedSize()

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
        .alert(joined?.title ?? "", isPresented: Binding(
            get: { joined != nil },
            set: { if !$0 { joined = nil } }
        )) {
            Button("Хорошо", role: .cancel) {}
        } message: {
            Text(Lang.format("Вы в испытании от %@. Свой счёт отправляйте кнопкой «Отправить счёт».",
                             joined?.host ?? ""))
        }
        .sheet(item: $comparing) { friend in
            GardenCompare(me: me, friend: friend)
        }
        .animation(Motion.pill, value: friends.races)
    }

    /// Своя карточка без счёта испытания — для «Поделиться».
    private var plainCard: String {
        var bare = me
        bare.race = nil
        return bare.card
    }

    /// Новое испытание — только по нажатию самого хозяина, сразу с собой;
    /// друзей зовёт кнопка в карточке.
    private func challenge(_ quest: Quest) {
        let race = Race.new(quest, host: garden.signed)
        withAnimation(Motion.pill) { friends.join(race) }
        Feel.done()
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
                    // открывалось бы. Нажатие — сады рядом.
                    Button { comparing = item.element } label: {
                        row(item.offset + 1, item.element)
                    }
                    .buttonStyle(.plain)
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
    /// прислали. Места — по «Вовремя, %», см. `Friends.ranked`.
    private var standings: [Rival] {
        Friends.ranked([me] + friends.rivals.filter { $0.id != me.id })
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
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 8)
            // Главное — доля поливов вовремя; число поливов — справкой.
            VStack(alignment: .trailing, spacing: 1) {
                Text(rival.aim.map { Lang.format("вовремя %@",
                                                 Lang.format("%lld%%", $0)) }
                     ?? Lang.text("вовремя —"))
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(Lang.format("%lld поливов", rival.total))
                    .font(Typography.figureCaption)
                    .foregroundStyle(Palette.secondaryText)
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

    /// Удалось — от кнопки вставки идёт волна. Вставить можно и
    /// челлендж; черенок сажается на вкладке «Добавить».
    private func invite(_ text: String) {
        if let race = Race.read(text) {
            withAnimation(Motion.pill) {
                friends.join(race)
                joined = race
            }
            Cheer.shared.now(from: paste.rect)
            Feel.done()
            return
        }
        if Cutting.read(text) != nil {
            trouble = Lang.text("Это растение от друга, а не его счёт. Добавьте растение на вкладке «Добавить» — кнопкой «Вставить» в строке «Растение от друга».")
            Feel.wrong()
            return
        }
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

            // Стереть общий сад может только хозяин: у гостя пункта нет вовсе,
            // ему — «Выйти из общего сада» в группе «Семья».
            if !kin.guest {
                SproutDivider()

                eraseRow
            }
        }
        .sproutRide()
        .sheet(isPresented: $erasing) {
            TypedConfirm(
                title: Lang.text("Стереть сад?"),
                message: shared
                    ? Lang.text("Исчезнут все растения и весь журнал поливов — у всех, кто в общем саду. Вернуть их будет нельзя.")
                    : Lang.text("Исчезнут все растения и весь журнал поливов. Вернуть их будет нельзя."),
                prompt: Lang.format("Введите %lld, чтобы стереть",
                                    garden.plantCount),
                answer: String(garden.plantCount),
                done: Lang.text("Стереть"),
                numeric: true) {
                _ = garden.erase(guest: kin.guest)
            }
        }
    }

    private var kin: Kinship { Kinship.shared }

    /// В общем саду стирается сад у всех, кто в нём.
    private var shared: Bool { Kinship.enabled && kin.sharing }

    private var eraseRow: some View {
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
}
