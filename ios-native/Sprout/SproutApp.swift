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
        .task { await runClock() }
        // Тему не навязываем: обе половины палитры живут в Palette, и
        // приложение идёт за системой. Выбор в настройках появится
        // позже — он ляжет сюда же, отдельным preferredColorScheme.
        //
        // Порядок наложений важен: подложка первой, плашка второй, — так
        // плашка лежит поверх неё.
        .overlay(alignment: .top) { cover }
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
        }
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

    /// Подложка под вырезом: закрывает содержимое, которое уезжает под
    /// строку состояния.
    ///
    /// Живёт в корне, а не на экранах. Нужна она всем вкладкам одинаково,
    /// а главное — плашка с логотипом должна лежать поверх неё, и это
    /// возможно, только пока обе в одном месте и в известном порядке.
    ///
    /// Высота — ровно глубина выреза. Числом её не задать: у разных
    /// телефонов вырез разной глубины, а лишние пункты срезали бы верх
    /// заголовка. Откуда берётся число — см. `topInset`.
    private var cover: some View {
        Palette.background
            .frame(height: notch)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
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

    /// И то же гашение ореолов на время перехода — см. главную.
    @State private var open: [Plant.ID] = []

    private var results: [Plant] { garden.search(query) }

    var body: some View {
        NavigationStack(path: $open) {
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
                        NavigationLink(value: plant.id) {
                            PlantCard(plant: plant)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: plant.id, in: cardZoom)
                    }
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 14)
                .environment(\.sproutHalos, open.isEmpty)
                .animation(open.isEmpty ? Motion.halo : nil, value: open.isEmpty)
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
