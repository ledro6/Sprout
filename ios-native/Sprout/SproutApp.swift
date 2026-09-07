import SwiftUI

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
struct RootView: View {
    @State private var tab: RootTab = .home

    var body: some View {
        TabView(selection: $tab) {
            Tab("Главная", systemImage: "house.fill", value: RootTab.home) {
                HomeView().modifier(ScreenAppear(active: tab == .home))
            }
            Tab("Статистика", systemImage: "chart.bar.fill",
                value: RootTab.stats) {
                Stub(title: "Статистика")
                    .modifier(ScreenAppear(active: tab == .stats))
            }
            Tab("Добавить", systemImage: "plus.circle.fill",
                value: RootTab.add) {
                Stub(title: "Добавить")
                    .modifier(ScreenAppear(active: tab == .add))
            }
            Tab("Профиль", systemImage: "person.fill", value: RootTab.profile) {
                Stub(title: "Профиль")
                    .modifier(ScreenAppear(active: tab == .profile))
            }
            Tab(value: RootTab.search, role: .search) {
                SearchView().modifier(ScreenAppear(active: tab == .search))
            }
        }
        // Панель уезжает вниз при прокрутке — штатное поведение iOS 26.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        // Тёмной темы у макета нет: фон в нём белый, текст чёрный. Без
        // этой строки в тёмной теме стекло уходит в тёмный материал, а
        // фон остаётся белым — и приложение выглядит сломанным.
        .preferredColorScheme(.light)
        .overlay(alignment: .top) { badge }
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

/// Вкладки. Нужны значениями, а не порядком: без них `TabView` не отдаёт
/// выбранную вкладку, а экран должен знать, что стал видимым.
enum RootTab {
    case home, stats, add, profile, search
}

/// Появление экрана при смене вкладки: содержимое подаётся чуть вперёд и
/// встаёт пружиной.
///
/// Играет от того, выбрана ли вкладка, а не от появления вью. Вкладки в
/// `TabView` остаются живыми после первого захода, и `onAppear` во второй
/// раз уже не придёт.
struct ScreenAppear: ViewModifier {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.97)
            .onChange(of: active, initial: true) { _, isActive in
                guard isActive else {
                    // Сброс, чтобы в следующий заход было что играть.
                    // Вкладка в этот момент уже уступила экран.
                    shown = false
                    return
                }
                guard !reduceMotion else {
                    shown = true
                    return
                }
                // Сброс и подъём в одном проходе SwiftUI схлопнёт:
                // значение вернётся к прежнему, и анимировать станет
                // нечего. Поэтому подъём уходит следующим проходом.
                Task { @MainActor in
                    withAnimation(.spring(duration: 0.42, bounce: 0.3)) {
                        shown = true
                    }
                }
            }
    }
}

/// Поиск по всей квартире.
///
/// Поле ввода даёт система: у вкладки с ролью `.search` капсула сама
/// раскрывается в строку поиска.
struct SearchView: View {
    @State private var query = ""

    /// То же разворачивание карточки в экран, что и на главной.
    @Namespace private var cardZoom

    private var results: [Plant] { Garden.search(query) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Metrics.gutterH),
                        GridItem(.flexible(), spacing: Metrics.gutterH),
                    ],
                    spacing: Metrics.gutterV
                ) {
                    ForEach(results) { plant in
                        NavigationLink(value: plant) {
                            PlantCard(plant: plant)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: plant.id, in: cardZoom)
                    }
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 14)
            }
            .background { SproutBackground() }
            .navigationDestination(for: Plant.self) { plant in
                PlantView(plant: plant)
                    .navigationTransition(.zoom(sourceID: plant.id, in: cardZoom))
            }
        }
        .searchable(text: $query, prompt: "Найти растение")
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
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
