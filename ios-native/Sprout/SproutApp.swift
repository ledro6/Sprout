import SwiftUI
import UIKit

@main
struct SproutApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Корень приложения.
///
/// Нижняя панель из макета — разделённые капсулы вкладок и отдельная
/// капсула поиска — это ровно то, что `TabView` с `Tab(role: .search)`
/// рисует сам в iOS 26. Стекло, перетекание подложки между вкладками,
/// раскрытие поиска в поле — всё системное, ничего из этого здесь не
/// написано.
///
/// Смена вкладки тоже системная. Своя пружина здесь была и убрана: она
/// не добавлялась к штатному переходу, а закрывала его собой — вкладка
/// сначала доигрывала системную анимацию, а поверх шла моя. Раз штатная
/// одинакова для всех вкладок, ничего для этого делать и не нужно.
struct RootView: View {
    /// Сад живёт здесь и виден всем вкладкам.
    @State private var garden = Garden()

    /// Глубина выреза: сколько система отводит сверху под строку
    /// состояния. Ровно на столько нужна подложка.
    @State private var notch: CGFloat = 0

    /// Настройки: тема отсюда правит всем окном. Не в окружении — см.
    /// `Settings`.
    private let settings = Settings.shared

    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            Tab("Главная", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Статистика", systemImage: "chart.bar.fill") {
                Stub(title: "Статистика")
            }
            Tab("Добавить", systemImage: "plus.circle.fill") {
                Stub(title: "Добавить")
            }
            Tab("Профиль", systemImage: "person.fill") {
                Stub(title: "Профиль")
            }
            Tab(role: .search) {
                SearchView()
            }
        }
        // Панель уезжает вниз при прокрутке — штатное поведение iOS 26.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        .environment(garden)
        // Глубину выреза знает только корень — окна из экрана не видно, —
        // а нужна она и подложке, и растяжке на главной.
        .environment(\.notch, notch)
        .task { await runClock() }
        .task { await Launch.shared.run() }
        // Тема. Пусто — идём за системой: обе половины палитры живут в
        // `Palette`, и до этой настройки приложение всегда шло за
        // телефоном. Здесь, в корне, а не на экране: настройка должна
        // достать и до листа с самими настройками, и до заставки.
        .preferredColorScheme(scheme)
        // Порядок наложений: сперва заставка — она закрывает
        // поднимающееся приложение целиком, — а плашка поверх неё. Плашка
        // есть и на приветственном экране макета, так что закрывать её
        // заставкой нельзя.
        .overlay { welcome }
        .overlay(alignment: .top) { badge }
        .onAppear { notch = Self.topInset() }
        // На случай, если при первом появлении окна ещё не было: смена
        // состояния сцены — момент, когда оно точно есть.
        .onChange(of: phase) { _, now in
            if now == .active {
                notch = Self.topInset()
            } else {
                // Уходим с экрана — записываем сад: выгрузить приложение
                // могут в любой момент и разрешения не спросят.
                garden.save()
            }
            remind(active: now == .active)
        }
    }

    /// Какую тему навязать окну. Пусто — никакой, идём за системой.
    private var scheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Расписание напоминаний о поливе.
    ///
    /// Ставится, когда приложение уходит с экрана, и снимается, когда оно
    /// возвращается. Пока на сад смотрят, напоминать не о чем: проценты
    /// подсыхают прямо на карточках, и уведомление поверх открытого
    /// приложения было бы шумом. А к возвращению срок всё равно устарел —
    /// сад успел подсохнуть, пока приложение стояло закрытым.
    ///
    /// Слепок комнат снимается здесь, на главной очереди, и уже он
    /// уходит считать: сад — наблюдаемый класс, и трогать его из другой
    /// задачи нечего.
    private func remind(active: Bool) {
        guard settings.reminders, !active else {
            Notifier.clear()
            return
        }
        let rooms = garden.rooms
        let threshold = settings.threshold
        Task { await Notifier.schedule(in: rooms, threshold: threshold) }
    }

    /// Часы сада: раз в секунду отдаём ему прошедшее время, и почва
    /// подсыхает. Раз в секунду, а не чаще: даже у самого быстрого
    /// растения процент меняется за полторы секунды, и будить экран ради
    /// невидимого — только тратить батарею.
    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            garden.advance()
        }
    }

    /// Заставка на холодном запуске. Пропадает, когда приложение
    /// поднялось, — и не появляется больше за всю его жизнь.
    @ViewBuilder
    private var welcome: some View {
        if Launch.shared.greeting {
            // Нажатия она забирает себе: под ней уже стоит собранный
            // экран, и ткнуть в карточку сквозь заставку было бы можно.
            Splash()
                .transition(.opacity)
        }
    }

    /// Глубина выреза — у окна, а не у разметки.
    ///
    /// SwiftUI это число отдавать отказывается, и обе попытки взять его
    /// оттуда кончились нулём. Сперва подложке дали нулевую высоту с
    /// разрешением выйти за безопасную зону: нулевая высота нулевой и
    /// осталась. Потом высоту спросили у `GeometryReader` — а он
    /// сообщает не глубину зоны, а сколько её осталось учесть, и стоит
    /// разрешить выход за зону, чтобы рисовать поверх неё, как он
    /// отвечает нулём. Оба раза подложка была ровно ничем, и содержимое
    /// просвечивало под строкой состояния.
    ///
    /// Окно знает точно. Приложение работает только вертикально, так что
    /// число это за сеанс не меняется.
    private static func topInset() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }

    /// Плашка с логотипом — общая для всех вкладок, как в макете.
    ///
    /// Живёт в корне и игнорирует безопасную зону: только здесь отступ
    /// отсчитывается от верха самого экрана. Внутри экрана координаты
    /// уже чужие — там сверху и панель навигации, и безопасная зона,
    /// которая срезает всё, что выше неё.
    ///
    /// Целиком уходит под вырез — на телефоне её не видно, а на
    /// скриншотах, где вырез не снимается, она на своём месте.
    private var badge: some View {
        SproutBadge()
            .padding(.top, Metrics.badgeTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// Поиск по всей квартире.
///
/// Поле ввода даёт система: у вкладки с ролью `.search` капсула сама
/// раскрывается в строку поиска.
struct SearchView: View {
    @Environment(Garden.self) private var garden

    @State private var query = ""

    /// То же разворачивание карточки в экран, что и на главной.
    @Namespace private var cardZoom

    /// И то же гашение ореола у открываемой карточки — см. главную.
    @State private var path: [Plant.ID] = []
    @State private var opening: Plant.ID?

    private var results: [Plant] { garden.search(query) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                // Без общего стеклянного контейнера — как на главной:
                // он склеивает сетку в один слой, и карточке нечем
                // разворачиваться в экран.
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Metrics.gutterH),
                        GridItem(.flexible(), spacing: Metrics.gutterH),
                    ],
                    spacing: Metrics.gutterV
                ) {
                    ForEach(results) { plant in
                        Button { show(plant.id) } label: {
                            PlantCard(plant: plant)
                        }
                        .buttonStyle(.plain)
                        .modifier(PlantMenu(id: plant.id))
                        .environment(\.sproutHalos, opening != plant.id)
                        .matchedTransitionSource(id: plant.id, in: cardZoom)
                    }
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 14)
            }
            .background { SproutBackground() }
            // Верх у поиска ничем не занят: растяжки со строкой комнаты
            // здесь нет, и содержимое под строку состояния держит
            // подложка.
            .sproutNotchCover()
            .navigationDestination(for: Plant.ID.self) { id in
                PlantView(plantID: id)
                    .navigationTransition(.zoom(sourceID: id, in: cardZoom))
            }
        }
        .searchable(text: $query, prompt: "Найти растение")
        .onChange(of: path) { _, now in
            if now.isEmpty {
                withAnimation(Motion.halo) { opening = nil }
            }
        }
    }

    /// Открыть растение: гашение и переход разными проходами — см.
    /// главную.
    private func show(_ id: Plant.ID) {
        opening = id
        Task { @MainActor in path.append(id) }
    }
}

/// Экранов для этих вкладок в макете нет — рисовать их «на глаз» значит
/// придумывать дизайн, которого никто не рисовал. Пока честная заглушка.
struct Stub: View {
    let title: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle(title)
                    Text("Этого экрана в макете нет")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 140)
                }
            }
            .background { SproutBackground() }
            .sproutNotchCover()
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
