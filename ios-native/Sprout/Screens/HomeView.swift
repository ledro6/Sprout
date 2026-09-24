import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(Garden.self) private var garden

    /// На столько растяжка под строкой комнаты уходит вверх, чтобы дотянуться
    /// до края экрана.
    @Environment(\.notch) private var notch

    @State private var roomIndex = 0

    /// Карточки, которые в этой комнате уже всплыли. Журнал здесь, а не в
    /// карточке: ленивая сетка выбрасывает карточки вместе с их памятью.
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

    /// Полка качается, как значки «Домой» в правке. Входят в неё, повёв
    /// карточку из меню или пунктом «Расставить».
    @State private var editing = false

    /// Меню по долгому нажатию. Снимается не сразу со входом в правку, а
    /// когда карточку отпустили: снятое посреди перетаскивания, оно
    /// пересобрало бы тащимую карточку.
    @State private var menus = true

    /// Кого тащат — один на всю полку.
    @State private var dragged: Plant.ID?

    @State private var scrolled: CGFloat = 0

    /// Путь заголовка до выреза. Не числом: заголовок растёт с размером
    /// текста.
    @State private var titleHeight: CGFloat = 1

    @ScaledMetric(relativeTo: .headline)
    private var roomSize = Typography.roomSize
    @ScaledMetric(relativeTo: .largeTitle)
    private var roomGrown = Typography.roomGrown

    /// 0 — экран в покое, 1 — заголовок ушёл, и строка комнаты встала на его
    /// место.
    private var grown: CGFloat {
        min(max(scrolled / titleHeight, 0), 1)
    }

    private var look: Settings.Look { Settings.shared.look }

    /// Номер придерживаем в границах. Комнат может не быть вовсе — тогда
    /// пусто.
    private var room: Room? {
        guard !garden.rooms.isEmpty else { return nil }
        return garden.rooms[min(roomIndex, garden.rooms.count - 1)]
    }

    private var plants: [Plant] {
        Settings.shared.order.arrange(room?.plants ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                // Заголовок уезжает, строка комнаты прилипает к верху —
                // закреплённая шапка секции, как в Музыке.
                LazyVStack(alignment: .leading, spacing: 0,
                           pinnedViews: [.sectionHeaders]) {
                    // Ступени входа — см. `Launch`.
                    SectionTitle("Главная")
                        .modifier(Enter(step: 2))
                        .onGeometryChange(for: CGFloat.self) { $0.size.height }
                            action: { titleHeight = max($0, 1) }
                    Section {
                        // До своей ступени сетки нет вовсе: иначе волна
                        // появления отыграла бы под заставкой.
                        if Launch.shared.step >= 4 {
                            shelf
                        }
                    } header: {
                        roomBar
                            .modifier(Enter(step: 3))
                    }
                }
            }
            // Плюс вставка сверху: под безопасной зоной смещение стартует
            // отрицательным.
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { _, offset in
                scrolled = offset
            }
            .onDrop(of: [.text], delegate: Rest(dragged: $dragged, drop: land))
            // Нажатие мимо карточек заканчивает правку, как на «Домой».
            // Кнопки и карточки своё нажатие забирают первыми.
            .gesture(TapGesture().onEnded { finish() },
                     including: editing ? .all : .subviews)
            .background { SproutBackground() }
            .toolbar(.hidden, for: .navigationBar)
            // Панель вкладок — последняя ступень входа. Её видимость задаёт
            // содержимое вкладки, а не корень.
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
        // сложится.
        .onChange(of: path) { _, now in
            if now.isEmpty {
                withAnimation(Motion.halo) { opening = nil }
            }
        }
        .onChange(of: roomIndex) { _, _ in revealed.removeAll() }
        // Выбор держится на той же комнате, а не на том же номере.
        .onChange(of: garden.rooms.map(\.name)) { old, new in
            follow(from: old, to: new)
        }
        // Ушедшее растение уходит и из журнала показанных: вернут — всплывёт,
        // а не появится щелчком.
        .onChange(of: room?.plants.map(\.id) ?? []) { old, new in
            revealed.subtract(Set(old).subtracting(new))
        }
        .onDisappear(perform: finish)
        .sheet(isPresented: $settings) { SettingsView() }
        // Сад передаём явно: без него лист упал бы, а на наследование
        // окружения полагаться незачем.
        .sheet(isPresented: $roomsOpen) { RoomsView().environment(garden) }
        .sheet(isPresented: $tripping) { TripView().environment(garden) }
        .fullScreenCover(isPresented: $staging) {
            PlantAR(ids: plants.map(\.id)).environment(garden)
        }
        // Кнопка действия или Siri попросили сад в AR.
        .onChange(of: Summon.shared.garden) { _, asked in
            guard asked else { return }
            Summon.shared.garden = false
            if PlantAR.available, !plants.isEmpty { staging = true }
        }
    }

    /// Нашлась по имени — её новый номер; не нашлась при том же числе комнат
    /// — переименовали; комнат меньше — встаём на соседнюю.
    private func follow(from old: [String], to new: [String]) {
        guard old.indices.contains(roomIndex) else {
            roomIndex = min(roomIndex, max(new.count - 1, 0))
            return
        }
        if let index = new.firstIndex(of: old[roomIndex]) {
            roomIndex = index
        } else if old.count != new.count {
            roomIndex = min(roomIndex, max(new.count - 1, 0))
        }
    }

    /// Гашение ореола и переход — разными проходами: в одном SwiftUI снимает
    /// кадр разворачивания с ещё горящим ореолом.
    private func show(_ id: Plant.ID) {
        opening = id
        Task { @MainActor in path.append(id) }
    }

    /// Строка комнаты: подпись растёт навстречу уезжающему заголовку и
    /// занимает его место.
    private var roomBar: some View {
        HStack(alignment: .center, spacing: 12) {
            if garden.rooms.isEmpty {
                // Место под строкой остаётся — на нём держатся кнопки справа.
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                RoomPicker(rooms: garden.rooms.map(\.name),
                           selection: $roomIndex,
                           size: roomSize + (roomGrown - roomSize) * grown,
                           onEdit: { roomsOpen = true })
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sproutRide()
            }
            corner
        }
        .padding(.horizontal, Metrics.contentMargin)
        .background(alignment: .top) { headerWash }
    }

    /// Кнопки справа сверху: вид, «Готово» в правке и настройки.
    ///
    /// Живут в закреплённой строке комнаты и смещаются вверх на высоту
    /// заголовка — тем меньше, чем дальше уехал экран. В сумме они стоят на
    /// одном месте и в покое, и на прокрутке. Стекло системное (`.glass`): с
    /// ним приходят продавливание, отскок, блик и «Уменьшение прозрачности».
    private var corner: some View {
        HStack(spacing: Metrics.cornerGap) {
            viewMenu
            doneButton
            SproutGear { settings = true }
        }
        .sproutRide()
        .offset(y: -titleHeight * (1 - grown))
    }

    /// Вид и порядок — одним меню, как в «Файлах»; значок — того вида, что на
    /// экране. Смена вида заново играет волну появления, смена порядка
    /// перекладывает карточки пружиной.
    private var viewMenu: some View {
        Menu {
            Section("Вид") {
                Picker("Вид", selection: Binding(
                    get: { look },
                    set: { chosen in
                        withAnimation(Motion.arrange) {
                            revealed.removeAll()
                            Settings.shared.look = chosen
                        }
                    }
                )) {
                    ForEach(Settings.Look.allCases) { item in
                        Label(item.title, systemImage: item.icon).tag(item)
                    }
                }
            }
            Section("Порядок") {
                Picker("Порядок", selection: Binding(
                    get: { Settings.shared.order },
                    set: { sort($0) }
                )) {
                    ForEach(Settings.Order.allCases) { item in
                        Label(item.title, systemImage: item.icon).tag(item)
                    }
                }
            }
            Section {
                if PlantAR.available, !plants.isEmpty {
                    Button { staging = true } label: {
                        Label("Сад в AR", systemImage: "arkit")
                    }
                }
                Button { tripping = true } label: {
                    Label("Уезжаю…", systemImage: "airplane.departure")
                }
            }
        } label: {
            Image(systemName: look.icon)
                .font(.system(size: Metrics.cornerGlyph, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: Metrics.gearBox, height: Metrics.gearBox)
                .contentTransition(.symbolEffect(.replace))
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Вид и порядок")
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

    /// Карточку повели. Порядок — тот, что на экране: взявшись тащить в
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

    /// «Расставить» из меню: меню снимаем следующим проходом, когда оно уже
    /// закрывается.
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
        menus = true
    }

    /// Растяжка под строкой комнаты гасит уезжающие под неё карточки.
    /// Верхнего края у неё нет — он уведён за край экрана: видимый край шёл
    /// бы поперёк экрана чертой. Поэтому подложки под вырезом на главной нет.
    private var headerWash: some View {
        VStack(spacing: 0) {
            Palette.background.opacity(Metrics.headerWashOpacity)
            LinearGradient(
                colors: [
                    Palette.background.opacity(Metrics.headerWashOpacity),
                    Palette.background.opacity(0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Metrics.headerWashFade)
        }
        .padding(.top, -(notch + titleHeight))
        .padding(.bottom, -Metrics.headerWashDrop)
        // Проступает по мере прокрутки: в покое она накрыла бы заголовок.
        .opacity(Double(grown))
        .allowsHitTesting(false)
    }

    /// Растения комнаты — см. `Shelf`.
    @ViewBuilder
    private var shelf: some View {
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
                              room: roomIndex,
                              appears: !revealed.contains(item.element.id),
                              onShown: { revealed.insert(item.element.id) },
                              arranges: true,
                              editing: editing,
                              menus: menus,
                              dragged: $dragged,
                              move: shift,
                              drop: land,
                              begin: begin,
                              arrange: arrange)
                        // Явная личность: без неё ленивая сетка подсовывала
                        // меню чужой узел — см. `PlantTile`.
                        .id(item.element.id)
                }
            }
            // Ровно на свес растяжки: в покое сход до карточек не
            // дотягивается.
            .padding(.top, Metrics.headerWashDrop)
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.bottom, 24)
            // Без анимации в области видимости уходящие карточки пропадали
            // кадром.
            .animation(Motion.leave, value: roomIndex)
        }
    }

    /// Пустая комната или пустой сад — строка о том, что делать.
    private var empty: some View {
        // Строкой заранее: собранная прямо в `Text`, она заставила бы
        // компилятор перебирать перегрузки.
        let note: String = garden.rooms.isEmpty
            ? "В саду пока ничего не растёт. Посадите первое растение во вкладке «Добавить»."
            : "В этой комнате пока ничего не растёт. Посадите сюда растение во вкладке «Добавить» или перевезите из другой комнаты."
        return VStack(spacing: 14) {
            Image(systemName: "leaf")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(note)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if garden.rooms.isEmpty {
                Button("Завести комнату") { roomsOpen = true }
                    .buttonStyle(.glass)
                    .font(Typography.settingNote)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 48)
        .padding(.top, 120)
        .transition(.blurReplace)
    }

    private func shift(_ who: Plant.ID, _ spot: Plant.ID) {
        withAnimation(Motion.arrange) { garden.move(who, to: spot) }
    }

    /// Отпустили — полка качается дальше, но меню уже нет: следующая
    /// карточка поднимается сразу.
    private func land() {
        withAnimation(Motion.arrange) { dragged = nil }
        menus = !editing
    }
}
