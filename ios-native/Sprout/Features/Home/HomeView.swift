import SwiftUI
import UniformTypeIdentifiers

/// Главная. Комнаты — страницами: листаются пальцем вбок, у каждой своя
/// прокрутка, а за последней — «Новая комната». Шапка общая: заголовок
/// «Главная» и лента комнат, идущая за листанием, — см. `RoomStrip`.
struct HomeView: View {
    @Environment(Garden.self) private var garden

    @Environment(\.layoutDirection) private var direction

    /// Какая страница на экране. Её же листает лента: привязка к прокрутке
    /// страниц, `scrollPosition`.
    @State private var target: HomeLeaf?

    /// Листание и прокрутка страниц — каждый кадр, поэтому в стороне: см.
    /// `Glide`.
    @State private var glide = Glide()

    /// Карточки, которые уже всплыли. Журнал здесь, а не в карточке: ленивая
    /// сетка выбрасывает карточки вместе с их памятью. Один на все комнаты:
    /// комната, в которую вернулись, не всплывает заново.
    ///
    /// Именно `@State`, а не класс в стороне: класс не будил тело, флаг «уже
    /// показывали» застывал, и появление играло на каждой прокрутке.
    @State private var revealed: Set<String> = []

    @Namespace private var cardZoom

    /// Путь держим сами: переход можно начинать только после того, как
    /// погашен ореол.
    @State private var path: [Plant.ID] = []

    /// Чья карточка разворачивается в экран — гасим ореол только у неё.
    /// Отдельным состоянием и проходом раньше перехода: иначе ореол попадал в
    /// кадр разворачивания и уезжал за карточкой хвостом.
    @State private var opening: Plant.ID?

    @State private var settings = false

    @State private var roomsOpen = false

    @State private var tripping = false

    /// Сад комнаты в дополненной реальности — из меню или кнопкой действия
    /// на корпусе, см. `OpenGardenAR`.
    @State private var staging = false
    /// Сад в AR — список на миг открытия, от самого сухого: телефон тянет
    /// не всех, и пусть встанут те, кому пора.
    @State private var staged: [Plant.ID] = []

    /// Полка качается, как значки «Домой» в правке. Входят в неё, повёв
    /// карточку из меню или продержав палец дольше меню.
    @State private var editing = false

    /// Меню по долгому нажатию. Снимается не сразу со входом в правку, а
    /// когда карточку отпустили: снятое посреди перетаскивания, оно
    /// пересобрало бы тащимую карточку.
    @State private var menus = true

    /// Кого подняли долгим нажатием: меню открыто или карточку уже ведут.
    @State private var held: Plant.ID?

    /// Кого тащат — один на всю полку.
    @State private var dragged: Plant.ID?

    /// «Новая комната»: имя, поле с клавиатурой и сколько раз имя не
    /// подошло.
    @State private var draft = ""
    @FocusState private var naming: Bool
    @State private var misses = 0

    /// Путь заголовка до верха. Не числом: заголовок растёт с размером
    /// текста.
    @State private var titleHeight: CGFloat = 1

    /// Ширина кнопок справа: лента, поднявшись к ним, ужимается.
    @State private var cornerWidth: CGFloat = 0

    /// Сколько снизу занято панелью вкладок: страницы уходят под неё, и
    /// последние карточки должны из-под неё выезжать. До первого замера —
    /// на глаз, с запасом.
    @State private var floor: CGFloat = 90

    @ScaledMetric(relativeTo: .title2)
    private var roomSize = Typography.roomSize
    @ScaledMetric(relativeTo: .largeTitle)
    private var roomGrown = Typography.roomGrown

    /// Строка ленты в покое и доросшая до заголовка — с запасом на кегль.
    private var row: CGFloat {
        max(Metrics.roomRow, (roomSize * 1.3).rounded(.up))
    }
    private var grownRow: CGFloat {
        max(Metrics.roomRow, (roomGrown * 1.25).rounded(.up))
    }

    private var look: Settings.Look { Settings.shared.look }

    /// Комнаты и «Новая комната» за ними.
    private var leaves: [HomeLeaf] {
        garden.rooms.map { HomeLeaf.room($0.name) } + [HomeLeaf.fresh]
    }

    /// Комната на экране. До первого листания привязка пуста — это первая.
    private var room: Room? {
        switch target {
        case .room(let name)?:
            garden.rooms.first { $0.name == name } ?? garden.rooms.first
        case .fresh?:
            nil
        case nil:
            garden.rooms.first
        }
    }

    private var plants: [Plant] {
        Settings.shared.order.arrange(room?.plants ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            pager
                // Шапка поверх страниц и общая на все: заголовок, лента
                // комнат. Кнопки — отдельным слоем: шапка перерисовывается
                // каждый кадр листания, а им незачем.
                .overlay(alignment: .top) { head }
                .overlay(alignment: .topTrailing) { corner }
                .onDrop(of: [.text],
                        delegate: Rest(held: $held, fly: fly, drop: land))
                // Нажатие мимо карточек заканчивает правку, как на «Домой».
                // Кнопки и карточки своё нажатие забирают первыми.
                .gesture(TapGesture().onEnded { finish() },
                         including: editing ? .all : .subviews)
                // Страницы уходят под панель вкладок — её высота нужна им
                // отступом. Ноль приходит, пока поднята клавиатура: его
                // пропускаем.
                .onGeometryChange(for: CGFloat.self) {
                    $0.safeAreaInsets.bottom
                } action: { bottom in
                    if bottom > 0 { floor = bottom }
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .background { SproutBackground() }
                .toolbar(.hidden, for: .navigationBar)
                // Панель вкладок — последняя ступень входа. Её видимость
                // задаёт содержимое вкладки, а не корень.
                .toolbar(Launch.shared.step >= Launch.last ? .visible : .hidden,
                         for: .tabBar)
                // По номеру, а не копией: экран растения показывает живое
                // состояние.
                .navigationDestination(for: Plant.ID.self) { id in
                    PlantView(plantID: id)
                        .navigationTransition(.zoom(sourceID: id, in: cardZoom))
                }
        }
        // Вернулись — ореолы проявляются, но не раньше, чем карточка
        // сложится. Открыли снова до срока — ожидание отменяется само.
        .task(id: path.isEmpty) {
            guard path.isEmpty, opening != nil else { return }
            await Motion.haloBack { opening = nil }
        }
        // Вход спрятался под замком — после ключа карточки всплывут заново.
        .onChange(of: Launch.shared.step) { _, now in
            if now == 0 { revealed.removeAll() }
        }
        // Страница держится на той же комнате, а не на том же номере.
        .onChange(of: garden.rooms.map(\.name)) { old, new in
            follow(from: old, to: new)
        }
        // Ушедшее растение уходит и из журнала показанных: вернут — всплывёт,
        // а не появится щелчком.
        .onChange(of: garden.rooms.flatMap { $0.plants.map(\.id) }) { old, new in
            revealed.subtract(Set(old).subtracting(new))
        }
        // Ушли с «Новой комнаты» — клавиатура ей больше не нужна.
        .onChange(of: target) { _, now in
            if now != .fresh { naming = false }
        }
        .onDisappear(perform: finish)
        .sheet(isPresented: $settings) { SettingsView() }
        // Сад передаём явно: без него лист упал бы, а на наследование
        // окружения полагаться незачем.
        .sheet(isPresented: $roomsOpen) { RoomsView().environment(garden) }
        .sheet(isPresented: $tripping) { TripView().environment(garden) }
        .fullScreenCover(isPresented: $staging) {
            PlantAR(ids: staged).environment(garden)
        }
        // Кнопка действия или Siri попросили сад в AR — модели видов в
        // приложении, открываем сразу.
        .onChange(of: Summon.shared.garden) { _, asked in
            guard asked else { return }
            Summon.shared.garden = false
            guard PlantAR.available, !plants.isEmpty else { return }
            stage()
        }
        // Визуальный интеллект попросил растение. Приложение могло для этого
        // и запуститься — тогда после входа.
        .onChange(of: Summon.shared.plant, initial: true) { _, _ in reach() }
        .onChange(of: Launch.shared.step) { _, _ in reach() }
    }

    /// К растению: на его комнату и сразу на его экран.
    private func reach() {
        guard let id = Summon.shared.plant, Launch.shared.step >= Launch.last
        else { return }
        Summon.shared.plant = nil
        guard let room = garden.roomName(of: id) else { return }
        target = .room(room)
        path = []
        show(id)
    }

    /// Страницы комнат — системное листание (`.paging`): отскок у краёв,
    /// бросок пальцем и доводка до страницы — как у экранов «Домой». Каждая
    /// страница сообщает, где стоит, — отсюда лента комнат знает положение
    /// листания и посреди жеста.
    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(leaves.enumerated()), id: \.element) { item in
                    page(item.element, index: item.offset)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .onGeometryChange(for: CGRect.self) {
                            $0.frame(in: .scrollView(axis: .horizontal))
                        } action: { frame in
                            let before = glide.at
                            glide.track(page: item.offset, frame: frame,
                                        flipped: direction == .rightToLeft)
                            feel(from: before, to: glide.at)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        // По середине: страница сменяется, когда соседняя заняла больше
        // половины экрана, а не с первым её пикселем.
        .scrollPosition(id: $target, anchor: .center)
        .scrollDismissesKeyboard(.immediately)
        .onScrollPhaseChange { _, phase in
            if phase == .idle { settle() }
        }
    }

    /// Страница: своя прокрутка под общей шапкой. Сверху — место под
    /// заголовок и ленту. Полоса, где лента встаёт, прокрутке объявлена
    /// панелью (`safeAreaBar`): уезжающие под неё карточки система размывает
    /// сама, мягким краем, как под панелями iOS.
    private func scroller<Content: View>(
        _ leaf: HomeLeaf, @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(.vertical) {
            content()
        }
        .contentMargins(.top, titleHeight + row + Metrics.shelfDrop - grownRow,
                        for: .scrollContent)
        .contentMargins(.bottom, floor + Metrics.shelfTail, for: .scrollContent)
        .contentMargins(.bottom, floor, for: .scrollIndicators)
        .safeAreaBar(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: grownRow)
                .allowsHitTesting(false)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollDismissesKeyboard(.interactively)
        // Плюс вставка сверху: под шапкой смещение стартует отрицательным.
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.y + $0.contentInsets.top
        } action: { _, lift in
            glide.track(leaf, lift: lift)
        }
    }

    /// До своей ступени входа полки нет вовсе: иначе волна появления
    /// отыграла бы под заставкой.
    @ViewBuilder
    private func page(_ leaf: HomeLeaf, index: Int) -> some View {
        switch leaf {
        case .room(let name):
            scroller(leaf) {
                if Launch.shared.step >= 4 {
                    shelf(garden.rooms.first { $0.name == name }, index: index)
                }
            }
        case .fresh:
            scroller(leaf) {
                if Launch.shared.step >= 4 {
                    NewRoom(draft: $draft,
                            focus: $naming,
                            bare: garden.rooms.isEmpty,
                            ideas: ideas,
                            misses: misses,
                            make: create,
                            edit: { roomsOpen = true })
                }
            }
        }
    }

    /// Шапка: заголовок и лента комнат — см. `HomeHead`.
    private var head: some View {
        HomeHead(glide: glide,
                 leaves: leaves,
                 names: garden.rooms.map(\.name),
                 size: roomSize,
                 grownSize: roomGrown,
                 row: row,
                 grownRow: grownRow,
                 corner: cornerWidth,
                 titleHeight: $titleHeight,
                 go: go)
    }

    /// Листнуть к странице нажатием — на выглядывающую комнату или из
    /// VoiceOver.
    private func go(_ index: Int) {
        guard leaves.indices.contains(index) else { return }
        withAnimation(Motion.page) { target = leaves[index] }
    }

    /// Листание встало — гул оттяжки стихает. Клавиатуру «Новая комната»
    /// сама не поднимает: имя пишут, нажав на поле.
    private func settle() {
        Feel.pull(0)
    }

    /// Отклик листания: на границе комнат — мягкий глубокий толчок, как у
    /// барабана; к «Новой комнате» тянут — тихий гул растёт вместе с
    /// оттяжкой, а на ней самой — едва заметный толчок: это не комната, а
    /// приглашение.
    private func feel(from old: CGFloat, to new: CGFloat) {
        guard old != new else { return }
        let last = leaves.count - 1
        let was = Int(old.rounded())
        let now = Int(new.rounded())
        if was != now, (0 ... last).contains(now) {
            Feel.turn(now == last && !garden.rooms.isEmpty
                      ? Metrics.freshThud : Metrics.roomThud)
        }
        guard !garden.rooms.isEmpty else { return }
        let pulled = new - CGFloat(last - 1)
        Feel.pull(pulled > 0 && new < CGFloat(last) + 0.3
                  ? Double(min(pulled, 1)) * Metrics.freshHum : 0)
    }

    /// Готовые имена — те, которых в саду ещё нет; «кухня» и «Кухня» —
    /// одно.
    private var ideas: [String] {
        let all = [Lang.text("Гостиная"), Lang.text("Спальня"),
                   Lang.text("Кухня"), Lang.text("Балкон"),
                   Lang.text("Кабинет"), Lang.text("Детская"),
                   Lang.text("Ванная"), Lang.text("Прихожая")]
        return all.filter { idea in
            !garden.rooms.contains {
                $0.name.compare(idea, options: .caseInsensitive) == .orderedSame
            }
        }
    }

    /// Завели комнату со страницы «Новая комната» — на экране остаётся она
    /// же: страница становится новой комнатой, «Новая комната» отъезжает
    /// правее. Пустое или занятое имя — поле вздрагивает.
    private func create(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let added = withAnimation(Motion.arrange) { () -> Bool in
            guard garden.addRoom(trimmed) else { return false }
            target = .room(trimmed)
            return true
        }
        guard added else {
            misses += 1
            Feel.wrong()
            return
        }
        draft = ""
        naming = false
        Feel.done()
    }

    private func stage() {
        staged = plants.sorted { $0.moisture < $1.moisture }.map(\.id)
        staging = true
    }

    /// Страница держится на комнате, а не на номере: переставили — едет с
    /// ней. Не нашлась при том же числе комнат — переименовали, встаём на
    /// новое имя; комнат меньше — на соседнюю.
    private func follow(from old: [String], to new: [String]) {
        glide.keep(leaves)
        guard case .room(let name)? = target, !new.contains(name) else {
            return
        }
        guard let index = old.firstIndex(of: name), !new.isEmpty else {
            target = new.first.map { HomeLeaf.room($0) } ?? HomeLeaf.fresh
            return
        }
        let place = old.count == new.count ? index : min(index, new.count - 1)
        target = .room(new[place])
    }

    /// Гашение ореола и переход — разными проходами: в одном SwiftUI снимает
    /// кадр разворачивания с ещё горящим ореолом.
    private func show(_ id: Plant.ID) {
        opening = id
        Task { @MainActor in path.append(id) }
    }

    /// Кнопки справа сверху: порядок, «ещё» и вид, «Готово» в правке и
    /// настройки. Стоят на месте и в покое, и на прокрутке: в покое — вровень
    /// с заголовком, на прокрутке к ним поднимается лента комнат. Стекло
    /// системное (`.glass`): с ним приходят продавливание, отскок, блик,
    /// меню, вырастающее из кнопки, и «Уменьшение прозрачности».
    private var corner: some View {
        HStack(spacing: Metrics.cornerGap) {
            orderMenu
            moreMenu
            lookButton
            doneButton
            SproutGear { settings = true }
        }
        .sproutRide()
        .frame(height: row)
        .padding(.trailing, Metrics.contentMargin)
        .onGeometryChange(for: CGFloat.self) { $0.size.width }
            action: { cornerWidth = $0 }
        .modifier(Enter(step: 3))
    }

    /// Значок угловой кнопки — то, что выбрано сейчас; сменился — меняется
    /// системным переходом значка.
    private func cornerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: Metrics.cornerGlyph, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(width: Metrics.gearBox, height: Metrics.gearBox)
            .contentTransition(.symbolEffect(.replace))
    }

    /// Порядок карточек; на кнопке — значок того, что выбран. Смена порядка
    /// перекладывает карточки пружиной.
    private var orderMenu: some View {
        Menu {
            Picker("Порядок", selection: Binding(
                get: { Settings.shared.order },
                set: { sort($0) }
            )) {
                ForEach(Settings.Order.allCases) { item in
                    Label(item.title, systemImage: item.icon).tag(item)
                }
            }
        } label: {
            cornerIcon(Settings.shared.order.icon)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Порядок")
        .accessibilityValue(Settings.shared.order.title)
    }

    /// Всё, что делают с садом целиком: AR, обход, отъезд, комнаты. Идёт
    /// обход или отсчёт до отъезда — на кнопке его значок, а не точки.
    private var moreMenu: some View {
        Menu {
            if PlantAR.available, !plants.isEmpty {
                Button(action: stage) {
                    Label("Сад в AR", systemImage: "arkit")
                }
            }
            round
            Button { tripping = true } label: {
                Label("Уезжаю…", systemImage: "airplane.departure")
            }
            Button { roomsOpen = true } label: {
                Label("Изменить комнаты…", systemImage: "pencil")
            }
        } label: {
            cornerIcon(moreIcon)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Ещё")
    }

    private var moreIcon: String {
        if Live.shared.rounding { return "figure.walk" }
        if Live.shared.counting { return "airplane.departure" }
        return "ellipsis"
    }

    /// Плиткой или списком — переключатель: нажатие меняет вид и заново
    /// играет волну появления. На кнопке — вид, что на экране.
    private var lookButton: some View {
        Button {
            withAnimation(Motion.arrange) {
                revealed.removeAll()
                Settings.shared.look = look == .grid ? .list : .grid
            }
            Feel.pick()
        } label: {
            cornerIcon(look.icon)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Вид")
        .accessibilityValue(look.title)
    }

    /// «Обход сада» — живое действие на экране блокировки: кто просит воды,
    /// по одному, с кнопкой «Полил». Идёт — его можно закончить; просить
    /// воды некому — и начинать нечего.
    @ViewBuilder
    private var round: some View {
        let live = Live.shared
        if live.enabled {
            if live.rounding {
                Button {
                    Task { await live.endRound() }
                } label: {
                    Label("Закончить обход", systemImage: "stop.circle")
                }
            } else if garden.rooms.contains(where: {
                $0.plants.contains { $0.thirst != .calm }
            }) {
                Button {
                    Task { await live.startRound() }
                    Feel.done()
                } label: {
                    Label("Обход сада", systemImage: "figure.walk")
                }
            }
        }
    }

    /// Не ручной порядок заканчивает правку: пересортированная сетка не дала
    /// бы положить карточку туда, куда опустили.
    private func sort(_ order: Settings.Order) {
        withAnimation(Motion.arrange) {
            Settings.shared.order = order
        }
        if order != .manual { finish() }
    }

    /// «Готово» — только у качающейся полки: галочкой в синем стекле, как
    /// подтверждение в iOS 26. Круг того же размера, что соседние кнопки, —
    /// подписи нечего обрезать.
    @ViewBuilder
    private var doneButton: some View {
        if editing {
            Button(action: finish) {
                Image(systemName: "checkmark")
                    .font(.system(size: Metrics.cornerGlyph, weight: .semibold))
                    .frame(width: Metrics.gearBox, height: Metrics.gearBox)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Готово")
            .transition(.scale.combined(with: .opacity))
        }
    }

    /// Карточку подняли долгим нажатием — открылось меню, полка стоит.
    /// Держат дальше — меню уходит, и полка качается, как значки «Домой».
    /// Повели — см. `fly`.
    private func lift(_ who: Plant.ID) {
        held = who
        // Наблюдатель не встал при запуске — встанет сейчас: это нажатие
        // он уже не увидит, следующее — да.
        Finger.shared.watch()
        // В правке меню нет — поднятую карточку сразу ведут.
        guard !editing else { return }
        let press = Finger.shared.press
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.holdToArrange))
            guard held == who, dragged == nil, !editing,
                  Finger.shared.holds(press) else { return }
            Finger.shared.closeMenu()
            arrange()
        }
    }

    /// Поднятую карточку повели: меню ушло, карточка бледнеет на своём
    /// месте, полка качается.
    private func fly() {
        guard dragged == nil, let held else { return }
        withAnimation(Motion.arrange) { dragged = held }
        begin()
    }

    /// Вход в правку. Порядок — тот, что на экране: взявшись тащить в
    /// сортировке, двигают то, что видят, и ручной порядок начинается с
    /// него.
    private func begin() {
        guard !editing else { return }
        garden.line(plants.map(\.id))
        withAnimation(Motion.arrange) {
            Settings.shared.order = .manual
            editing = true
        }
    }

    /// Палец продержали дольше меню: меню снимаем следующим проходом, когда
    /// оно уже закрывается.
    private func arrange() {
        begin()
        Feel.pick()
        Task { @MainActor in menus = !editing }
    }

    private func finish() {
        guard editing || dragged != nil else { return }
        withAnimation(Motion.arrange) {
            editing = false
            dragged = nil
        }
        held = nil
        menus = true
    }

    /// Растения комнаты — см. `Shelf`. Номер страницы ведёт появление
    /// карточек, см. `CardAppear`.
    @ViewBuilder
    private func shelf(_ room: Room?, index: Int) -> some View {
        let plants = Settings.shared.order.arrange(room?.plants ?? [])
        if plants.isEmpty {
            empty
        } else {
            Shelf(look) {
                ForEach(Array(plants.enumerated()), id: \.element.id) { item in
                    PlantTile(plant: item.element,
                              look: look,
                              opening: opening,
                              zoom: cardZoom,
                              open: show,
                              index: item.offset,
                              room: index,
                              appears: !revealed.contains(item.element.id),
                              onShown: { revealed.insert(item.element.id) },
                              arranges: true,
                              editing: editing,
                              menus: menus,
                              held: $held,
                              dragged: dragged,
                              move: shift,
                              drop: land,
                              lift: lift,
                              fly: fly,
                              waters: true)
                        // Явная личность: без неё ленивая сетка подсовывала
                        // меню чужой узел — см. `PlantTile`.
                        .id(item.element.id)
                }
            }
            .padding(.horizontal, Metrics.contentMargin)
        }
    }

    /// Пустая комната — строка о том, что делать. Пустой сад встречает
    /// «Новая комната».
    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "leaf")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(Lang.text("""
                В этой комнате пока ничего не растёт. Посадите сюда растение \
                во вкладке «Добавить» или перевезите из другой комнаты.
                """))
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 48)
        .padding(.top, 100)
        .transition(.blurReplace)
    }

    private func shift(_ who: Plant.ID, _ spot: Plant.ID) {
        withAnimation(Motion.reflow) { garden.move(who, to: spot) }
    }

    /// Отпустили — полка качается дальше, но меню уже нет: следующая
    /// карточка поднимается сразу.
    private func land() {
        withAnimation(Motion.arrange) { dragged = nil }
        held = nil
        menus = !editing
    }
}


/// Шапка главной: заголовок «Главная» и лента комнат. Своим вью: листание и
/// прокрутка двигают её каждый кадр, и будить ими всю главную незачем.
///
/// Заголовок уезжает вверх с содержимым и тает в размытие, лента поднимается
/// на его место и растёт до его размера, прижимаясь к кнопкам справа, — как
/// крупный заголовок iOS, только на его месте название комнаты. Прокрутка
/// берётся у страницы на экране, посреди листания — смесью двух соседних:
/// шапка переходит от одной к другой вместе с пальцем.
private struct HomeHead: View {
    let glide: Glide
    let leaves: [HomeLeaf]
    let names: [String]

    /// Кегль подписи комнаты в покое и доросший до заголовка.
    let size: CGFloat
    let grownSize: CGFloat

    /// Высота строки ленты в покое и доросшей.
    let row: CGFloat
    let grownRow: CGFloat

    /// Ширина кнопок справа.
    let corner: CGFloat

    @Binding var titleHeight: CGFloat

    let go: (Int) -> Void

    var body: some View {
        let lift = glide.lift(across: leaves)
        // 0 — экран в покое, 1 — заголовок ушёл, и лента встала на его место.
        let grown = min(max(lift / titleHeight, 0), 1)
        let fade = min(max(lift / (titleHeight * Metrics.titleFade), 0), 1)
        VStack(alignment: .leading, spacing: 0) {
            // Ступени входа — см. `Launch`.
            SectionTitle("Главная")
                .modifier(Enter(step: 2))
                .onGeometryChange(for: CGFloat.self) { $0.size.height }
                    action: { titleHeight = max($0, 1) }
                .opacity(1 - fade)
                .blur(radius: fade * Metrics.textBlur)
                .offset(y: -lift)
                // Сквозь заголовок листают и прокручивают страницы.
                .allowsHitTesting(false)
            RoomStrip(names: names,
                      at: glide.at,
                      size: size + (grownSize - size) * grown,
                      // Ужимается с опережением: поднимаясь, лента не
                      // заезжает под кнопки.
                      trail: (corner + Metrics.roomGap) * min(grown * 1.5, 1),
                      go: go)
                .frame(height: row + (grownRow - row) * grown)
                .sproutRide()
                .modifier(Enter(step: 3))
                .offset(y: -min(lift, titleHeight))
        }
    }
}
