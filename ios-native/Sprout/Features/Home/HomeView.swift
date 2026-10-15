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

    /// Своя прокрутка комнаты — заново, когда из неё ушли: вернувшись,
    /// попадаешь в начало комнаты, а не туда, где бросил. Номер меняется —
    /// SwiftUI ставит прокрутку новую, сверху.
    @State private var fresh: [HomeLeaf: Int] = [:]

    /// Карточки, которые уже всплыли. Журнал здесь, а не в карточке: ленивая
    /// сетка выбрасывает карточки вместе с их памятью. Один на все комнаты:
    /// комната, в которую вернулись, не всплывает заново.
    ///
    /// Именно `@State`, а не класс в стороне: класс не будил тело, флаг «уже
    /// показывали» застывал, и появление играло на каждой прокрутке.
    @State private var revealed: Set<String> = []

    @Namespace private var cardZoom

    /// Плитка и список — разные контейнеры; растение перетекает из одного
    /// в другой по своему id, см. `PlantTile.morph`.
    @Namespace private var shelfMorph

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Путь держим сами: переход можно начинать только после того, как
    /// погашен ореол.
    @State private var path: [Plant.ID] = []

    /// Чья карточка разворачивается в экран — гасим ореол только у неё.
    /// Отдельным состоянием и проходом раньше перехода: иначе ореол попадал в
    /// кадр разворачивания и уезжал за карточкой хвостом.
    @State private var opening: Plant.ID?

    @State private var settings = false

    @State private var roomsOpen = false
    /// Переименование и удаление комнаты из меню ленты.
    @State private var renaming: Room?
    @State private var renameDraft = ""
    @State private var doomed: Room?

    @State private var tripping = false
    @State private var pausing = false

    /// «Спросить сад» — из «ещё».
    @State private var asking = false

    /// Полили последнего, кто ждал воды, — листопад «Все политы!».
    @State private var cheering = false

    /// Сад комнаты в дополненной реальности — из меню или кнопкой действия
    /// на корпусе, см. `OpenGardenAR`.
    @State private var staging = false
    /// Сад в AR — список на миг открытия, от самого сухого: телефон тянет
    /// не всех, и пусть встанут те, кому пора.
    @State private var staged: [Plant.ID] = []

    /// Правка: карточки переставляют, нажатие ничего не открывает. Входят в
    /// неё, повёв карточку из меню или продержав палец дольше меню.
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
    /// Строка «Сухих: n» под лентой — с запасом на кегль.
    @ScaledMetric(relativeTo: .caption)
    private var dryRow: CGFloat = 18

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
                // Вход во вкладку — плавно; фон и небо стоят.
                .modifier(TabEntrance(sky: true))
                .background {
                    SproutBackground()
                        .overlay { DaySky() }
                }
                .overlay {
                    if cheering {
                        LeafFall { cheering = false }
                            .transition(.opacity)
                    }
                }
                .modifier(GardenRecovery())
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
            rest()
        }
        // Ушедшее растение уходит и из журнала показанных: вернут — всплывёт,
        // а не появится щелчком.
        .onChange(of: garden.rooms.flatMap { $0.plants.map(\.id) }) { old, new in
            revealed.subtract(Set(old).subtracting(new))
        }
        // Ушли с «Новой комнаты» — клавиатура ей больше не нужна.
        .onChange(of: target) { _, now in
            if now != .fresh { naming = false }
            rest()
        }
        .onDisappear(perform: finish)
        .sheet(isPresented: $settings) { SettingsView() }
        // Сад передаём явно: без него лист упал бы, а на наследование
        // окружения полагаться незачем.
        .sheet(isPresented: $roomsOpen) { RoomsView().environment(garden) }
        // Переименование и удаление из меню ленты — как в «Комнатах».
        .alert("Переименовать комнату", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } })
        ) {
            TextField("Название", text: $renameDraft)
            Button("Отмена", role: .cancel) {}
            // Без имени — неактивна, как в «Комнатах».
            Button("Сохранить") { commitRename() }
                .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty)
        }
        .roomDeletion($doomed)
        .sheet(isPresented: $tripping) { TripView().environment(garden) }
        .sheet(isPresented: $pausing) { PauseSheet().environment(garden) }
        .sheet(isPresented: $asking) { AskView().environment(garden) }
        // Один раз после смены версии: см. `WhatsNew`.
        .modifier(WhatsNew())
        // Ждали воды, и полили последнего — праздник. Высохли новые —
        // просто счёт растёт.
        .onChange(of: MoistureStatus.needsWater(in: garden.rooms).count) { old, now in
            // Только после полива: убрали последнего сухого — не праздник.
            guard old > 0, now == 0, Launch.shared.step >= Launch.last,
                  path.isEmpty,
                  let poured = garden.log.map(\.when).max(),
                  Date().timeIntervalSince(poured) < 5 else { return }
            withAnimation(Motion.appear) { cheering = true }
            Feel.done()
        }
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
                            guard glide.moving else { return }
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
            glide.moving = phase != .idle
            if phase == .idle { settle() }
        }
    }

    /// Страница: своя прокрутка под общей шапкой. Сверху — место под
    /// заголовок и ленту. Полоса, где лента встаёт, и чуть ниже подписи
    /// прокрутке объявлена панелью (`safeAreaBar`): уезжающие под неё
    /// карточки система размывает сама, плавным градиентом, как под
    /// панелями iOS. Градиент гаснет на `headTail` ниже подписи — под
    /// названием комнаты карточки уже размыты и не мешают его читать.
    private func scroller<Content: View>(
        _ leaf: HomeLeaf, @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(.vertical) {
            content()
        }
        // Полки встают на ступени входа без общего проявления: иначе вся
        // страница со стеклом вставлялась бы прозрачностью поверх своей
        // волны карточек.
        .transaction(value: Launch.shared.step >= 4) { $0.animation = nil }
        .contentMargins(.top, max(titleHeight + row + Metrics.shelfDrop
                                  - grownRow - Metrics.headTail, 0)
                        + (dry(leaf) > 0 ? dryRow : 0),
                        for: .scrollContent)
        .contentMargins(.bottom, floor + Metrics.shelfTail, for: .scrollContent)
        .contentMargins(.bottom, floor, for: .scrollIndicators)
        .safeAreaBar(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: grownRow + Metrics.headTail)
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
        .id(fresh[leaf, default: 0])
    }

    /// До своей ступени входа полки нет вовсе: иначе волна появления
    /// отыграла бы под заставкой.
    @ViewBuilder
    private func page(_ leaf: HomeLeaf, index: Int) -> some View {
        switch leaf {
        case .room(let name):
            scroller(leaf) {
                if Launch.shared.step >= 4 {
                    let room = garden.rooms.first { $0.name == name }
                    VStack(spacing: Metrics.gutterV) {
                        if let room, !room.plants.isEmpty {
                            let key = "day:" + room.name
                            TodayBlock(room: room)
                                .modifier(CardAppear(
                                    index: 0, room: index,
                                    animates: !revealed.contains(key),
                                    onShown: { revealed.insert(key) }))
                                .padding(.horizontal, Metrics.contentMargin)
                        }
                        if editing {
                            ReorderHint()
                                .padding(.horizontal, Metrics.contentMargin)
                                .transition(.blurReplace)
                        }
                        shelf(room, index: index)
                    }
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
                            edit: { roomsOpen = true },
                            sample: sampler)
                }
            }
        }
    }

    /// «Показать пример» — пока в саду ни одного растения.
    private var sampler: (() -> Void)? {
        guard garden.plantCount == 0 else { return nil }
        return {
            withAnimation(Motion.arrange) {
                garden.showSample()
                if let first = garden.rooms.first {
                    target = .room(first.name)
                }
            }
            Feel.done()
        }
    }

    /// Сколько в комнате страницы ждёт воды — для «Сухих: n» под лентой.
    private func dry(_ leaf: HomeLeaf) -> Int {
        guard case .room(let name) = leaf,
              let room = garden.rooms.first(where: { $0.name == name })
        else { return 0 }
        return room.plants.filter(\.needsWaterToday).count
    }

    /// Шапка: заголовок и лента комнат — см. `HomeHead`.
    private var head: some View {
        HomeHead(glide: glide,
                 leaves: leaves,
                 names: garden.rooms.map(\.name),
                 dry: leaves.map(dry),
                 size: roomSize,
                 grownSize: roomGrown,
                 row: row,
                 grownRow: grownRow,
                 corner: cornerWidth,
                 titleHeight: $titleHeight,
                 actions: roomActions,
                 go: go)
    }

    /// Меню комнаты на ленте — те же действия, что в «Комнатах», плюс полив
    /// всей комнаты, как «Полить» у сада. Ссылки — на текущие значения: меню
    /// строится заново при каждом открытии.
    private func roomActions(_ index: Int) -> RoomActions? {
        guard garden.rooms.indices.contains(index) else { return nil }
        let room = garden.rooms[index]
        let thirsty = MoistureStatus.pourable(in: [room]).map(\.id)
        return RoomActions(
            atDacha: room.atDacha,
            canWater: !thirsty.isEmpty,
            canUp: index > 0,
            canDown: index < garden.rooms.count - 1,
            rename: {
                renameDraft = room.name
                renaming = room
            },
            water: {
                guard Bin.shared.waterNeeded(thirsty, in: garden) > 0 else { return }
                Cheer.shared.now(from: Screen.middle)
                Feel.water()
            },
            dacha: { on in
                withAnimation(Motion.enter) { garden.settle(room.name, dacha: on) }
                Feel.pick()
            },
            up: { move(index, by: -1) },
            down: { move(index, by: 1) },
            delete: {
                if room.plants.isEmpty {
                    withAnimation(Motion.arrange) { garden.deleteRoom(room.name) }
                } else {
                    doomed = room
                }
            })
    }

    /// Порядок — как в «Комнатах». Листание целевой страницы привязано к
    /// комнате по имени, поэтому после переноса лента едет за ней сама.
    private func move(_ index: Int, by step: Int) {
        // Куда встать — как в «Комнатах»: `onMove` принимает место вставки.
        let to = step > 0 ? index + 2 : index - 1
        withAnimation(Motion.arrange) {
            garden.moveRooms(from: IndexSet(integer: index), to: to)
        }
    }

    /// Имя — как в «Комнатах»: занятое или пустое возвращается с отказом.
    private func commitRename() {
        defer { renaming = nil }
        guard let room = renaming, renameDraft != room.name else { return }
        let renamed = withAnimation(Motion.number) {
            garden.renameRoom(room.name, to: renameDraft)
        }
        if !renamed { Feel.wrong() }
    }

    /// Листнуть к странице нажатием — на выглядывающую комнату или из
    /// VoiceOver.
    private func go(_ index: Int) {
        guard leaves.indices.contains(index), target != leaves[index]
        else { return }
        // Доводка — тоже листание: лента едет вместе со страницами.
        glide.moving = true
        withAnimation(Motion.page) { target = leaves[index] }
    }

    /// Листание встало — гул оттяжки стихает, лента встаёт ровно на
    /// страницу. Комнаты, из которых ушли, прокручиваются в начало.
    /// Клавиатуру «Новая комната» сама не поднимает: имя пишут, нажав на
    /// поле.
    private func settle() {
        Feel.pull(0)
        let here = min(max(Int(glide.at.rounded()), 0), leaves.count - 1)
        glide.rest(at: here)
        for (index, leaf) in leaves.enumerated()
        where index != here && glide.lifts[leaf, default: 0] > 1 {
            fresh[leaf, default: 0] += 1
            // Новая прокрутка стоит в начале, но о своём положении может не
            // сказать, пока её не тронут: старый подъём остался бы в `Glide`,
            // и, вернувшись, шапка доросла бы до него над страницей у верха,
            // а с первым касанием сама сжалась бы обратно.
            glide.track(leaf, lift: 0)
        }
    }

    /// Страницу сменили не листанием — переход по нажатию, переименование,
    /// удаление: лента встаёт на неё сразу.
    private func rest() {
        guard !glide.moving else { return }
        let here = target.flatMap { leaves.firstIndex(of: $0) } ?? 0
        glide.rest(at: here)
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

    /// Кнопки справа сверху: вид и «•••» (сад, отъезд, сортировка,
    /// настройки), «Готово» в правке. Стоят на месте и в покое, и на прокрутке:
    /// в покое — вровень с заголовком, на прокрутке к ним поднимается лента
    /// комнат. Все одного размера — `CornerCircle`; стекло — интерактивное,
    /// с ним приходят продавливание и блик.
    private var corner: some View {
        HStack(spacing: Metrics.cornerGap) {
            // В правке — только «Готово»: сортировать и менять вид посреди
            // перестановки незачем. Вне правки — вид и «•••»: сортировка и
            // настройки живут в меню.
            if !editing {
                Group {
                    lookButton
                    moreMenu
                }
                .transition(.scale.combined(with: .opacity))
            }
            doneButton
        }
        .sproutRide()
        .frame(height: row)
        .padding(.trailing, Metrics.contentMargin)
        .onGeometryChange(for: CGFloat.self) { $0.size.width }
            action: { cornerWidth = $0 }
        .modifier(Enter(step: 3, glass: true))
    }

    /// Значок угловой кнопки — то, что выбрано сейчас; сменился — меняется
    /// системным переходом значка.
    private func cornerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .contentTransition(.symbolEffect(.replace))
            .cornerGlyph()
    }

    /// Всё, что делают с садом целиком: AR, обход, вопрос модели, отъезд,
    /// комнаты. Идёт обход или отсчёт до отъезда — на кнопке его значок, а не
    /// точки.
    private var moreMenu: some View {
        Menu {
            Section {
                if PlantAR.available, !plants.isEmpty {
                    Button(action: stage) {
                        Label("Сад в AR", systemImage: "arkit")
                    }
                }
                // Телефону без Apple Intelligence вовсе входа не показываем;
                // выключенной или грузящейся — лист объяснит.
                if Muse.shown(.ask) {
                    Button { asking = true } label: {
                        Label("Спросить сад",
                              systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
                // Метка на горшке — только когда NFC в сборке включён, см.
                // `Tags.enabled`.
                if Tags.ready {
                    Button { Tags.shared.read() } label: {
                        Label("Приложить к метке",
                              systemImage: "sensor.tag.radiowaves.forward")
                    }
                }
                Button { roomsOpen = true } label: {
                    Label("Изменить комнаты…", systemImage: "pencil")
                }
            } header: {
                Text("Сад")
            }
            Section {
                Button { pausing = true } label: {
                    Label("Пауза напоминаний…", systemImage: "bell.slash")
                }
            }
            Section {
                Button { tripping = true } label: {
                    Label("Уезжаю…", systemImage: "airplane.departure")
                }
                round
            } header: {
                Text("Уехать")
            }
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
                Label("Сортировка", systemImage: Settings.shared.order.icon)
            }
            Button { settings = true } label: {
                Label("Настройки", systemImage: "gearshape")
            }
        } label: {
            cornerIcon(moreIcon)
        }
        .menuStyle(.button)
        .cornerButton()
        .accessibilityLabel("Ещё")
    }

    private var moreIcon: String {
        if Live.shared.rounding { return "figure.walk" }
        if Live.shared.counting { return "airplane.departure" }
        return "ellipsis"
    }

    /// Кривая перехода «Вид»: без отскока и длиннее `Motion.arrange`, чтобы
    /// глаз успевал проследить перетекание карточек в строки.
    private static let lookSwap = Animation.smooth(duration: 0.55)

    /// Плиткой или списком — переключатель: растения перетекают из одного
    /// вида в другой (`PlantTile.morph`), волна появления не играет. На кнопке —
    /// вид, что на экране.
    private var lookButton: some View {
        Button {
            // Одна кривая на всё перетекание: карточка и строка сходятся по
            // общему id. При «Уменьшить движение» — затухание без перемещения
            // (см. `Shelf`: `morph` и `dissolves`).
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : Self.lookSwap) {
                Settings.shared.look = look == .grid ? .list : .grid
            }
            Feel.pick()
        } label: {
            cornerIcon(look.icon)
        }
        .cornerButton()
        .accessibilityLabel("Вид")
        .accessibilityValue(look.title)
    }

    /// «Полить по очереди» — живое действие на экране блокировки: кто
    /// просит воды, по одному, с кнопкой «Полил». Подзаголовок говорит, что
    /// это, — по одному названию было непонятно. Идёт — его можно закончить;
    /// просить воды некому — и начинать нечего.
    @ViewBuilder
    private var round: some View {
        let live = Live.shared
        if live.enabled {
            if live.rounding {
                Button {
                    Task { await live.endRound() }
                } label: {
                    Label("Закончить полив по очереди", systemImage: "stop.circle")
                }
            } else if garden.rooms.contains(where: {
                $0.plants.contains(where: \.needsWaterToday)
            }) {
                Button {
                    Task { await live.startRound() }
                    Feel.done()
                } label: {
                    Label("Полить по очереди", systemImage: "drop.circle")
                    Text("Показывает на экране блокировки, какое растение поливать следующим")
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

    /// «Готово» — только в правке: галочкой в синем стекле, как
    /// подтверждение в iOS 26. Круг того же размера, что соседние кнопки, —
    /// подписи нечего обрезать.
    @ViewBuilder
    private var doneButton: some View {
        if editing {
            Button(action: finish) {
                Image(systemName: "checkmark")
                    .cornerGlyph()
            }
            .cornerButton(prominent: true)
            .accessibilityLabel("Готово")
            .transition(.scale.combined(with: .opacity))
        }
    }

    /// Карточку подняли долгим нажатием — открылось меню, правки ещё нет.
    /// Держат дальше — меню уходит, полка переходит в правку, как на «Домой».
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
    /// месте, полка переходит в правку.
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
        if plants.isEmpty, garden.plantCount == 0 {
            // Пустой сад — с чего начать, а не «в этой комнате пусто».
            // Приветствие — только здесь, в пустом саду.
            VStack(spacing: 18) {
                Text(Daypart.of(Date()).greeting(garden.owner))
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                EmptyGarden(add: { Summon.shared.add = true }, sample: sampler)
            }
            .padding(.horizontal, 48)
            .padding(.top, 100)
            .transition(.blurReplace)
        } else if plants.isEmpty {
            empty
        } else {
            Shelf(look) {
                ForEach(Array(plants.enumerated()), id: \.element.id) { item in
                    PlantTile(plant: item.element,
                              look: look,
                              opening: opening,
                              zoom: cardZoom,
                              morph: reduceMotion ? nil : shelfMorph,
                              dissolves: reduceMotion,
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
                .foregroundStyle(Palette.secondaryText)
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

    /// Отпустили — правка продолжается, но меню уже нет: следующая
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

    /// Сколько ждёт воды в комнате с тем же номером; у «Новой комнаты» — 0.
    let dry: [Int]

    /// Кегль подписи комнаты в покое и доросший до заголовка.
    let size: CGFloat
    let grownSize: CGFloat

    /// Высота строки ленты в покое и доросшей.
    let row: CGFloat
    let grownRow: CGFloat

    /// Ширина кнопок справа.
    let corner: CGFloat

    @Binding var titleHeight: CGFloat

    /// Меню комнаты под номером; у «Новой комнаты» его нет.
    let actions: (Int) -> RoomActions?

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
                      face: max(size, grownSize),
                      rest: size,
                      grown: grown,
                      corner: corner + Metrics.roomGap,
                      actions: actions,
                      go: go)
                .frame(height: row + (grownRow - row) * grown)
                .sproutRide()
                .modifier(Enter(step: 3))
                .offset(y: -min(lift, titleHeight))
            dryLine(lift: lift, grown: grown)
        }
    }

    /// «Сухих: n» под названием текущей комнаты, пока n > 0. Лента растёт и
    /// поднимается — строка уходит вместе с ней и тает.
    @ViewBuilder
    private func dryLine(lift: CGFloat, grown: CGFloat) -> some View {
        let here = min(max(Int(glide.at.rounded()), 0), dry.count - 1)
        if dry.indices.contains(here), dry[here] > 0 {
            Text(Lang.format("Сухих: %lld", dry[here]))
                .font(Typography.figureCaption.weight(.semibold))
                .foregroundStyle(Palette.alarm)
                .padding(.leading, Metrics.contentMargin)
                .opacity(1 - min(grown * 3, 1))
                .offset(y: -min(lift, titleHeight))
                .allowsHitTesting(false)
        }
    }
}

/// «Пауза напоминаний…»: до какого дня и для чего молчат напоминания.
/// Снимается сама в срок или кнопкой «Снять паузу».
private struct PauseSheet: View {
    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var until = Date()
    /// nil — весь сад, иначе — одна комната.
    @State private var room: String?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(Lang.text("До"), selection: $until,
                           in: Calendar.current.startOfDay(for: Date())...,
                           displayedComponents: .date)
                Picker(Lang.text("Что тихо"), selection: $room) {
                    Text("Весь сад").tag(String?.none)
                    ForEach(garden.rooms, id: \.name) { item in
                        Text(item.name).tag(String?.some(item.name))
                    }
                }
                Section {
                    Button(Lang.text("Поставить паузу")) { start() }
                    if Settings.shared.pause != nil {
                        Button(Lang.text("Снять паузу")) {
                            Settings.shared.pause = nil
                            Task { await Notifier.replan() }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(Lang.text("Пауза напоминаний"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Lang.text("Закрыть"), role: .close) { dismiss() }
                }
            }
        }
    }

    private func start() {
        let calendar = Calendar.current
        // Выбранный день входит целиком.
        let end = calendar.date(byAdding: .day, value: 1,
                                to: calendar.startOfDay(for: until)) ?? until
        Settings.shared.pause = Plan.Pause(
            until: end, scope: room.map { .room($0) } ?? .garden)
        Task { await Notifier.replan() }
        dismiss()
    }
}
