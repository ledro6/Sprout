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
///
/// Смена вкладки тоже системная. Своя пружина здесь была и убрана: она
/// не добавлялась к штатному переходу, а закрывала его собой — вкладка
/// сначала доигрывала системную анимацию, а поверх шла моя. Раз штатная
/// одинакова для всех вкладок, ничего для этого делать и не нужно.
struct RootView: View {
    /// Сад живёт здесь и виден всем вкладкам.
    @State private var garden = Garden()

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
        .environment(garden)
        .task { await runClock() }
        // Уходим с экрана — записываем сад. Приложение могут выгрузить в
        // любой момент и разрешения не спросят.
        .onChange(of: phase) { _, now in
            if now != .active { garden.save() }
        }
        // Панель уезжает вниз при прокрутке — штатное поведение iOS 26.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        // Тему не навязываем: обе половины палитры живут в Palette, и
        // приложение идёт за системой. Выбор в настройках появится
        // позже — он ляжет сюда же, отдельным preferredColorScheme.
        .overlay(alignment: .top) { badge }
    }

    /// Часы сада: раз в секунду отдаём ему прошедшее время, и почва
    /// подсыхает. Раз в секунду, а не чаще: проценты меняются медленнее,
    /// а будить экран ради невидимого — только тратить батарею.
    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            garden.advance()
        }
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

    private var results: [Plant] { garden.search(query) }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Стекло найденных карточек — одним проходом, как на
                // главной.
                GlassEffectContainer(spacing: 0) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Metrics.gutterH),
                            GridItem(.flexible(), spacing: Metrics.gutterH),
                        ],
                        spacing: Metrics.gutterV
                    ) {
                        ForEach(results) { plant in
                            NavigationLink(value: plant.id) {
                                PlantCard(plant: plant)
                            }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(id: plant.id, in: cardZoom)
                        }
                    }
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 14)
            }
            .background { SproutBackground() }
            .navigationDestination(for: Plant.ID.self) { id in
                PlantView(plantID: id)
                    .navigationTransition(.zoom(sourceID: id, in: cardZoom))
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
