import AppIntents
import SwiftUI
import UIKit

@main
struct SproutApp: App {
    /// Кнопка «Полил» в уведомлении должна быть известна системе до того,
    /// как придёт первое.
    init() {
        Notifier.register()
        // Записали сад — виджету пора перерисоваться.
        Garden.saved = { Task { @MainActor in Widgets.nudge() } }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Корень приложения. Панель вкладок с отдельной капсулой поиска и её
/// анимации — системные, `TabView` с `Tab(role: .search)` в iOS 26.
struct RootView: View {
    /// Сад общий — см. `Garden.shared`: с ним говорит и Siri.
    @State private var garden = Garden.shared

    @State private var notch: CGFloat = 0

    /// Не в окружении — см. `Settings`.
    private let settings = Settings.shared

    /// Не в окружении: замок нужен и корню, а до корня окружение не достаёт.
    private let lock = Lock.shared

    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            Tab("Главная", systemImage: "house.fill") {
                HomeView().sproutUndo()
            }
            Tab("Статистика", systemImage: "chart.bar.fill") {
                StatsView().sproutUndo()
            }
            Tab("Добавить", systemImage: "plus.circle.fill") {
                AddView().sproutUndo()
            }
            Tab("Профиль", systemImage: "person.fill") {
                ProfileView().sproutUndo()
            }
            Tab(role: .search) {
                SearchView().sproutUndo()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        .environment(garden)
        // Глубину выреза знает только корень: окно видно только отсюда.
        .environment(\.notch, notch)
        .task { await runClock() }
        .task { await Launch.shared.run() }
        .task { Chime.warm() }
        // Модели для сада в AR — заранее, в фоне; недостающие собираются,
        // лишние уходят.
        .task(priority: .background) {
            let plants = garden.rooms.flatMap(\.plants)
            // Модели — под силу этого телефона: на новых iPhone чётче.
            await Workshop.shared.use(Probe.rig.detail)
            await Workshop.shared.tend(plants)
        }
        // Состав сада сменился — пересказываем Siri клички.
        .onChange(of: garden.roster, initial: true) { _, _ in
            SproutShortcuts.updateAppShortcutParameters()
            // Картинки для виджета — тем же поводом: состав сада сменился.
            let rooms = garden.rooms
            Task(priority: .utility) { await Thumbs.export(rooms) }
        }
        // Время года — при запуске, при возвращении (мог смениться месяц) и
        // когда его выключают в настройках.
        .onChange(of: settings.seasons, initial: true) { _, on in
            Season.settle(on: on)
        }
        // Тема — в корне: она должна достать и до листа настроек, и до
        // заставки. Пусто — за системой.
        .preferredColorScheme(scheme)
        // Сперва заставка, плашка поверх неё: в макете плашка есть и на
        // приветственном экране.
        .overlay { welcome }
        .overlay(alignment: .top) { badge }
        // Замок поверх всего: запертый сад не должен мелькнуть даже под
        // заставкой.
        .overlay { padlock }
        // Наблюдатель касаний — тоже на окно, см. `Finger`.
        .onAppear {
            notch = Self.topInset()
            Finger.shared.watch()
        }
        // При первом появлении окна могло ещё не быть.
        .onChange(of: phase) { _, now in
            if now == .active {
                notch = Self.topInset()
                Finger.shared.watch()
                // Пока спали, сад мог полить виджет или кнопка в
                // уведомлении.
                garden.reload()
                Season.settle(on: settings.seasons)
                Task { await lock.unlock() }
            } else {
                // Запираем на «неактивно», а не на «в фоне»: снимок для
                // переключателя программ делается раньше, и на нём остался бы
                // сад.
                lock.close()
                // Выгрузить приложение могут в любой момент.
                garden.save()
            }
            // Удалённое уходит насовсем только в фоне: на «неактивно»
            // попадают шторка, «Пункт управления» и Face ID.
            if now == .background { Bin.shared.commit() }
            remind(active: now == .active)
        }
    }

    private var scheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Напоминание ставится при уходе с экрана и снимается при возвращении:
    /// пока на сад смотрят, оно было бы шумом. Слепок комнат снимается здесь,
    /// на главной очереди.
    private func remind(active: Bool) {
        guard settings.reminders, !active else {
            Notifier.clear()
            return
        }
        let rooms = garden.rooms
        let threshold = settings.threshold
        Task { await Notifier.schedule(in: rooms, threshold: threshold) }
    }

    /// Раз в секунду: даже у самого быстрого растения процент меняется за
    /// полторы.
    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            garden.advance()
        }
    }

    @ViewBuilder
    private var padlock: some View {
        if lock.on, !lock.open {
            LockView()
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var welcome: some View {
        if Launch.shared.greeting {
            // Нажатия забирает себе, иначе сквозь заставку можно ткнуть в
            // карточку.
            Splash(owner: garden.owner)
                .transition(.opacity)
        }
    }

    /// Глубина выреза — у окна: SwiftUI её не отдаёт (и нулевая рамка, и
    /// `GeometryReader` отвечали нулём). Приложение только вертикальное, так
    /// что за сеанс число не меняется.
    private static func topInset() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }

    /// Плашка с логотипом — общая для всех вкладок, от верха самого экрана,
    /// поэтому в корне. Без прыжка на волне: это знак приложения, а не
    /// элемент экрана.
    private var badge: some View {
        SproutBadge()
            .padding(.top, Metrics.badgeTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// Поиск. Поле — системное: `searchable` висит внутри стека навигации, иначе
/// система ставит поле по-старому, сверху, а не внизу у панели.
struct SearchView: View {
    @Environment(Garden.self) private var garden

    @State private var query = ""

    private let recents = Recents.shared

    @Namespace private var cardZoom

    @State private var path: [Plant.ID] = []
    @State private var opening: Plant.ID?

    private var asked: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Plant] {
        Settings.shared.order.arrange(garden.search(query))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SproutHead("Поиск")
                    if asked.isEmpty {
                        history
                    } else if results.isEmpty {
                        nothing
                    } else {
                        grid
                    }
                }
            }
            .background { SproutBackground() }
            // Строки комнаты здесь нет — верх держит подложка под вырезом.
            .sproutNotchCover()
            .navigationDestination(for: Plant.ID.self) { id in
                PlantView(plantID: id)
                    .navigationTransition(.zoom(sourceID: id, in: cardZoom))
            }
            .searchable(text: $query, prompt: "Найти растение")
            .searchToolbarBehavior(.minimize)
            // Подстановку запроса делает `searchCompletion`.
            .searchSuggestions {
                ForEach(recents.queries, id: \.self) { past in
                    Label(past, systemImage: "clock.arrow.circlepath")
                        .searchCompletion(past)
                }
            }
            .onSubmit(of: .search) { recents.remember(asked) }
        }
        .onChange(of: path) { _, now in
            if now.isEmpty {
                withAnimation(Motion.halo) { opening = nil }
            }
        }
    }

    /// Прежние запросы — и плашкой на самом экране: подсказка под полем
    /// видна, только пока оно раскрыто.
    @ViewBuilder
    private var history: some View {
        if recents.queries.isEmpty {
            hint(Lang.text("Найдётся по кличке или по виду — «Баксик», «Монстера»."),
                 icon: "magnifyingglass")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                SproutGroup("Недавно искали") {
                    ForEach(Array(recents.queries.enumerated()),
                            id: \.element) { item in
                        if item.offset > 0 { SproutDivider() }
                        Button { again(item.element) } label: {
                            SproutLink(item.element,
                                       icon: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.plain)
                        .transition(.blurReplace)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation(Motion.pill) {
                                    recents.forget(item.element)
                                }
                            } label: {
                                Label("Забыть", systemImage: "xmark")
                            }
                        }
                    }
                }
                .sproutRide()

                Button("Очистить") {
                    withAnimation(Motion.pill) { recents.clear() }
                }
                .buttonStyle(.glass)
                .font(Typography.settingNote)
            }
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private var nothing: some View {
        hint(Lang.format("По запросу «%@» в квартире ничего не растёт.", asked),
             icon: "leaf")
    }

    private func hint(_ text: String, icon: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 48)
        .padding(.top, 140)
    }

    private var grid: some View {
        Shelf(Settings.shared.look) {
            ForEach(results) { plant in
                PlantTile(plant: plant, look: Settings.shared.look,
                          opening: opening, zoom: cardZoom, open: show)
                    .id(plant.id)
            }
        }
        .padding(.horizontal, Metrics.contentMargin)
        .padding(.top, 14)
        .padding(.bottom, 28)
    }

    private func again(_ past: String) {
        query = past
        recents.remember(past)
    }

    /// Гашение ореола и переход — разными проходами, см. главную. Нашли и
    /// открыли — запрос был нужен.
    private func show(_ id: Plant.ID) {
        recents.remember(asked)
        opening = id
        Task { @MainActor in path.append(id) }
    }
}
