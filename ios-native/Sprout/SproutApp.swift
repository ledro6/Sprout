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

    var body: some View {
        TabView {
            Tab("Главная", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Статистика", systemImage: "chart.bar.fill") {
                StatsView()
            }
            Tab("Добавить", systemImage: "plus.circle.fill") {
                AddView()
            }
            Tab("Профиль", systemImage: "person.fill") {
                ProfileView()
            }
            Tab(role: .search) {
                SearchView()
            }
        }
        .environment(garden)
        .task { await runClock() }
        // Панель уезжает вниз при прокрутке — штатное поведение iOS 26.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        // Тёмной темы у макета нет: фон в нём белый, текст чёрный. Без
        // этой строки в тёмной теме стекло уходит в тёмный материал, а
        // фон остаётся белым — и приложение выглядит сломанным.
        .preferredColorScheme(.light)
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

