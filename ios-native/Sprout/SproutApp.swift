import AppIntents
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
    /// Сад виден всем вкладкам. Сам он общий — см. `Garden.shared`: с ним
    /// говорит и Siri, и говорить они должны с одним и тем же садом.
    @State private var garden = Garden.shared

    /// Глубина выреза: сколько система отводит сверху под строку
    /// состояния. Ровно на столько нужна подложка.
    @State private var notch: CGFloat = 0

    /// Настройки: тема отсюда правит всем окном. Не в окружении — см.
    /// `Settings`.
    private let settings = Settings.shared

    /// Замок. Не в окружении — см. `Settings`: он нужен и корню, и
    /// профилю, а через окружение до корня не достать.
    private let lock = Lock.shared

    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            // Плашка отмены — на каждой вкладке: см. `sproutUndo`.
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
        // Панель уезжает вниз при прокрутке — штатное поведение iOS 26.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        .environment(garden)
        // Глубину выреза знает только корень — окна из экрана не видно, —
        // а нужна она и подложке, и растяжке на главной.
        .environment(\.notch, notch)
        .task { await runClock() }
        .task { await Launch.shared.run() }
        // Siri знает растения по кличкам — и узнаёт о новых, когда состав
        // сада меняется: посадили, переименовали, удалили, вернули.
        .onChange(of: garden.roster, initial: true) { _, _ in
            SproutShortcuts.updateAppShortcutParameters()
        }
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
        // Замок поверх всего, заставки в том числе: запертый сад не
        // должен мелькнуть даже на время приветствия.
        .overlay { padlock }
        .onAppear { notch = Self.topInset() }
        // На случай, если при первом появлении окна ещё не было: смена
        // состояния сцены — момент, когда оно точно есть.
        .onChange(of: phase) { _, now in
            if now == .active {
                notch = Self.topInset()
                // Вернулись к запертому саду — сразу спрашиваем ключ.
                // Открытый сад этот вызов не трогает, см. `Lock.unlock`.
                Task { await lock.unlock() }
            } else {
                // Запираем на «неактивно», а не на «в фоне»: снимок для
                // переключателя программ система делает раньше, чем
                // приложение уходит в фон, и на нём остался бы весь сад.
                lock.close()
                // Уходим с экрана — записываем сад: выгрузить приложение
                // могут в любой момент и разрешения не спросят.
                garden.save()
            }
            // Ушли в фон — удалённое уходит насовсем. Не на «неактивно»:
            // туда попадают и шторка, и «Пункт управления», и спросить
            // Face ID, а отсчёт ради них обрывать незачем.
            if now == .background { Bin.shared.commit() }
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

    /// Запертый сад — поверх всего, что есть на экране.
    @ViewBuilder
    private var padlock: some View {
        if lock.on, !lock.open {
            LockView()
                .transition(.opacity)
        }
    }

    /// Заставка на холодном запуске. Пропадает, когда приложение
    /// поднялось, — и не появляется больше за всю его жизнь.
    @ViewBuilder
    private var welcome: some View {
        if Launch.shared.greeting {
            // Нажатия она забирает себе: под ней уже стоит собранный
            // экран, и ткнуть в карточку сквозь заставку было бы можно.
            Splash(owner: garden.owner)
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
    /// Прыжка на волне у неё нет, и намеренно. Плашка — знак приложения,
    /// а не элемент экрана: она стоит на одном месте поверх всех вкладок,
    /// наполовину уйдя под вырез, и подпрыгивающий логотип читался бы
    /// поломкой, а не откликом на полив.
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
/// раскрывается в строку поиска. В iOS 26 строка эта живёт внизу, у
/// панели вкладок, а не под заголовком сверху — там же, где палец. Ради
/// этого `searchable` и висит на содержимом внутри стека навигации, а не
/// снаружи: снаружи система относит поле к самой вкладке и ставит его
/// по-старому, сверху.
///
/// Крестик в поле, отмена, раскрытие и сворачивание — всё системное.
/// Здешнего тут только то, чего система знать не может: что искали
/// раньше и что делать, когда не нашлось ничего.
struct SearchView: View {
    @Environment(Garden.self) private var garden

    @State private var query = ""

    /// Что искали раньше — см. `Recents`. Не в окружении: список один на
    /// приложение, как настройки.
    private let recents = Recents.shared

    /// То же разворачивание карточки в экран, что и на главной.
    @Namespace private var cardZoom

    /// И то же гашение ореола у открываемой карточки — см. главную.
    @State private var path: [Plant.ID] = []
    @State private var opening: Plant.ID?

    private var asked: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Находки — в том же порядке, что выбран на главной.
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
            // Верх у поиска ничем не занят: растяжки со строкой комнаты
            // здесь нет, и содержимое под строку состояния держит
            // подложка.
            .sproutNotchCover()
            .navigationDestination(for: Plant.ID.self) { id in
                PlantView(plantID: id)
                    .navigationTransition(.zoom(sourceID: id, in: cardZoom))
            }
            .searchable(text: $query, prompt: "Найти растение")
            // Поле сворачивается в кнопку у панели вкладок и
            // раскрывается по нажатию — как в iOS 26 везде.
            .searchToolbarBehavior(.minimize)
            // Прежние запросы — системной подсказкой под полем. Нажатие
            // подставляет запрос целиком: за это отвечает
            // `searchCompletion`, и своего кода тут нет вовсе.
            .searchSuggestions {
                ForEach(recents.queries, id: \.self) { past in
                    Label(past, systemImage: "clock.arrow.circlepath")
                        .searchCompletion(past)
                }
            }
            // Нажали «Найти» — запрос был нужен, запоминаем.
            .onSubmit(of: .search) { recents.remember(asked) }
        }
        .onChange(of: path) { _, now in
            if now.isEmpty {
                withAnimation(Motion.halo) { opening = nil }
            }
        }
    }

    /// Что искали раньше — плашкой на самом экране, а не только
    /// подсказкой под полем.
    ///
    /// Подсказка показывается, когда поле раскрыто; а до того экран
    /// поиска пуст, и место на нём простаивает зря. Здесь список виден
    /// сразу, не трогая поля.
    @ViewBuilder
    private var history: some View {
        if recents.queries.isEmpty {
            hint("Найдётся по кличке или по виду — «Баксик», «Монстера».",
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
                        // Забытая строка уходит системным размытием, как и
                        // весь текст приложения, а не просто гаснет.
                        .transition(.blurReplace)
                        // Забыть одну строку — долгим нажатием на неё, как
                        // и всё остальное, что убирают в этом приложении.
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

    /// Искали, но не нашли.
    private var nothing: some View {
        hint("По запросу «\(asked)» в квартире ничего не растёт.",
             icon: "leaf")
    }

    /// Строка посреди пустого экрана — общая на обе подсказки.
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

    /// Находки — тем же видом, что и на главной: плиткой или списком.
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

    /// Повторить прежний запрос.
    private func again(_ past: String) {
        query = past
        recents.remember(past)
    }

    /// Открыть растение: гашение и переход разными проходами — см.
    /// главную. Заодно запоминаем запрос: нашли и открыли — значит, он
    /// был нужен.
    private func show(_ id: Plant.ID) {
        recents.remember(asked)
        opening = id
        Task { @MainActor in path.append(id) }
    }
}
