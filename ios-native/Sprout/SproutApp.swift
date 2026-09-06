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
        // Тёмной темы у макета нет: фон в нём белый, текст чёрный. Без
        // этой строки в тёмной теме стекло уходит в тёмный материал, а
        // фон остаётся белым — и приложение выглядит сломанным.
        .preferredColorScheme(.light)
    }
}

/// Поиск по всей квартире.
///
/// Поле ввода даёт система: у вкладки с ролью `.search` капсула сама
/// раскрывается в строку поиска.
struct SearchView: View {
    @State private var query = ""

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
                    }
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 14)
            }
            .background { SproutBackground() }
            .navigationDestination(for: Plant.self) { PlantView(plant: $0) }
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
            ZStack {
                SproutBackground()
                Text("Этого экрана в макете нет")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(title)
        }
    }
}
