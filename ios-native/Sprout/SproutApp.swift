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
        // Тему не навязываем: обе половины палитры живут в Palette, и
        // приложение идёт за системой. Выбор в настройках появится
        // позже — он ляжет сюда же, отдельным preferredColorScheme.
        // Порядок важен: подложка первым наложением, плашка вторым, —
        // так плашка лежит поверх неё.
        .overlay(alignment: .top) { cover }
        .overlay(alignment: .top) { badge }
    }

    /// Подложка под вырезом: закрывает содержимое, которое уезжает под
    /// строку состояния.
    ///
    /// Живёт в корне, а не на экранах. Нужна она всем вкладкам одинаково,
    /// а главное — плашка с логотипом должна лежать поверх неё, и это
    /// возможно, только пока обе в одном месте и в известном порядке.
    ///
    /// Высота — ровно безопасная зона сверху. Числом её не задать: вырез у
    /// разных телефонов разной глубины, а лишние пункты срезали бы верх
    /// заголовка. Прошлая попытка обходилась нулевой высотой с выходом за
    /// зону — расчёт был, что зона вью и растянет. Не растянула: нулевая
    /// высота остаётся нулевой, и рисовать было нечего. Отсюда и
    /// содержимое, просвечивавшее под строкой состояния.
    private var cover: some View {
        GeometryReader { proxy in
            Palette.background
                .frame(height: proxy.safeAreaInsets.top)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
    @State private var query = ""

    /// То же разворачивание карточки в экран, что и на главной.
    @Namespace private var cardZoom

    private var results: [Plant] { Garden.search(query) }

    var body: some View {
        NavigationStack {
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
