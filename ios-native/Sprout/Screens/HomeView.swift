import SwiftUI

/// Главная: заголовок раздела, выбор комнаты и сетка растений.
struct HomeView: View {
    @State private var roomIndex = 0

    /// Карточки, которые в этой комнате уже всплыли. Журнал лежит здесь,
    /// а не в самой карточке: сетка ленивая, уехавшие за край карточки
    /// она выбрасывает вместе с их памятью, а сетка остаётся.
    ///
    /// Именно состояние, а не ссылочный тип рядом с ним. Здесь была
    /// оптимизация: журнал переехал в класс, за которым SwiftUI не
    /// следит, чтобы отметка «всплыла» не перерисовывала экран восемь раз
    /// за волну. Она и не перерисовывала — и в этом была поломка. Флаг
    /// «эту уже показывали» считается ниже, в теле экрана; не
    /// пересобравшись, тело так и отдавало сетке «нет, не показывали» —
    /// для каждой карточки и навсегда. Сетка ленивая, уехавшую за край
    /// карточку она создаёт заново, брала этот застывший ответ и играла
    /// появление снова.
    ///
    /// Восемь пересборок тела за полсекунды — цена правильного ответа, и
    /// она невелика: фон при них не перерисовывается, его вью не
    /// меняется.
    @State private var revealed: Set<String> = []

    /// Пространство для перехода на растение: карточка не исчезает, а
    /// разворачивается в экран.
    @Namespace private var cardZoom

    /// Насколько экран прокручен от верха.
    @State private var scrolled: CGFloat = 0

    /// Высота заголовка раздела — путь, который он проходит, прежде чем
    /// уйти под вырез. Не задана числом: заголовок крупный и растёт
    /// вместе с настройкой размера текста.
    @State private var titleHeight: CGFloat = 1

    /// Размеры кнопки комнаты: в покое и доросшей до заголовка. Оба идут
    /// за настройкой размера текста, каждый — за своим стилем, поэтому и
    /// растут по-разному.
    @ScaledMetric(relativeTo: .headline)
    private var roomSize = Typography.roomSize
    @ScaledMetric(relativeTo: .largeTitle)
    private var roomGrown = Typography.roomGrown

    /// Доля пути, пройденного заголовком: 0 — экран в покое, 1 — заголовок
    /// ушёл целиком и строка комнаты встала на его место.
    private var grown: CGFloat {
        min(max(scrolled / titleHeight, 0), 1)
    }

    private var room: Room { Garden.rooms[roomIndex] }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Заголовок уезжает с содержимым, строка комнаты
                // прилипает к верху, дойдя до него, — как список в
                // Музыке. Даёт это закреплённая шапка секции: своей
                // возни с наложением слоёв здесь не нужно.
                LazyVStack(alignment: .leading, spacing: 0,
                           pinnedViews: [.sectionHeaders]) {
                    SectionTitle("Главная")
                        .onGeometryChange(for: CGFloat.self) { $0.size.height }
                            action: { titleHeight = max($0, 1) }
                    Section {
                        grid
                    } header: {
                        roomBar
                    }
                }
            }
            // Сколько уехало содержимое. Вставка сверху прибавлена,
            // чтобы в покое выходил ноль: у прокрутки под безопасной
            // зоной смещение стартует отрицательным.
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { _, offset in
                scrolled = offset
            }
            .background { SproutBackground() }
            // Панель сверху не нужна: заголовок раздела живёт в самом
            // содержимом. У экрана растения панель своя.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Plant.self) { plant in
                PlantView(plant: plant)
                    .navigationTransition(.zoom(sourceID: plant.id, in: cardZoom))
            }
        }
    }

    /// Строка комнаты. Пока заголовок уезжает, подпись комнаты растёт
    /// ему навстречу и к концу пути становится ровно его размера: место
    /// заголовка занимает не пустота, а название комнаты.
    private var roomBar: some View {
        RoomPicker(rooms: Garden.rooms.map(\.name), selection: $roomIndex,
                   size: roomSize + (roomGrown - roomSize) * grown)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.contentMargin)
            .background(alignment: .top) { headerWash }
    }

    /// Растяжка под строкой комнаты: гасит карточки, которые заезжают
    /// под строку снизу.
    ///
    /// Только под строку и только вниз. Вверх она не уходит: там стоит
    /// заголовок раздела, и поднятая растяжка забеливала его. Полосу над
    /// строкой держит подложка в корне приложения, и держит независимо от
    /// того, куда доехала прокрутка.
    ///
    /// Сход прицеплен к низу строки, а не задан абсолютной высотой, — так
    /// он не поедет, если подпись комнаты займёт другую высоту.
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
        .padding(.bottom, -Metrics.headerWashDrop)
        .allowsHitTesting(false)
    }

    /// Сетка без общего стеклянного контейнера.
    ///
    /// Контейнер сводил стекло всех карточек в один проход рисования —
    /// экономия настоящая, но платить за неё пришлось тем, ради чего
    /// экран и делался. Он собирает содержимое в один слой, и обе
    /// анимации карточки шли через него: разворачивание в экран теряло
    /// источник, а волна появления играла не по карточкам, а по всей
    /// сетке разом. Карточки к тому же намеренно не сливаются краями —
    /// то есть от контейнера здесь и не нужно ничего, кроме прохода.
    private var grid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Metrics.gutterH),
                GridItem(.flexible(), spacing: Metrics.gutterH),
            ],
            spacing: Metrics.gutterV
        ) {
            ForEach(Array(room.plants.enumerated()), id: \.element.id) { item in
                NavigationLink(value: item.element) {
                    PlantCard(plant: item.element)
                }
                .buttonStyle(.plain)
                // Появление ведёт сама карточка — от номера комнаты, а не
                // от появления вью: вернувшись в уже открытую комнату,
                // SwiftUI переиспользует карточку вместе с состоянием.
                // Играет один раз: кто показался, тот при обратной
                // прокрутке стоит на месте.
                .modifier(CardAppear(
                    index: item.offset,
                    room: roomIndex,
                    animates: !revealed.contains(item.element.id),
                    onShown: { revealed.insert(item.element.id) }))
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
                // Отсюда карточка разворачивается в экран растения.
                // Замер снимается с готовой геометрии, поэтому источник
                // навешен последним.
                .matchedTransitionSource(id: item.element.id, in: cardZoom)
            }
        }
        // Ровно на свес растяжки: в покое сход до карточек не
        // дотягивается, а уезжающим наверх есть где раствориться.
        .padding(.top, Metrics.headerWashDrop)
        .padding(.horizontal, Metrics.contentMargin)
        .padding(.bottom, 24)
        // Затухание уходящим карточкам. Без этого их нечем анимировать:
        // переход у них описан, но анимации в области видимости нет, и
        // старая комната просто пропадала кадром.
        .animation(Motion.leave, value: roomIndex)
        // Сменили комнату — растения другие, и всплыть должны все.
        .onChange(of: roomIndex) { _, _ in revealed.removeAll() }
    }
}
