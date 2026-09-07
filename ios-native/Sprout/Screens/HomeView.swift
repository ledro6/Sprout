import SwiftUI

/// Главная: заголовок раздела, выбор комнаты и сетка растений.
struct HomeView: View {
    @Environment(Garden.self) private var garden

    @State private var roomIndex = 0

    /// Карточки, которые в этой комнате уже всплыли. Журнал лежит здесь,
    /// а не в самой карточке: сетка ленивая, уехавшие за край карточки
    /// она выбрасывает вместе с их памятью, а сетка остаётся.
    @State private var revealed = RevealLog()

    /// Пространство для перехода на растение: карточка не исчезает, а
    /// разворачивается в экран.
    @Namespace private var cardZoom

    /// Открытая комната. Номер придерживаем в границах: комнат может
    /// стать меньше, а выбор остаётся прежним.
    private var room: Room {
        garden.rooms[min(roomIndex, garden.rooms.count - 1)]
    }

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
                    Section {
                        grid
                    } header: {
                        roomBar
                    }
                }
            }
            .background { SproutBackground(topWash: false) }
            // Панель сверху не нужна: заголовок раздела живёт в самом
            // содержимом. У экрана растения панель своя.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Plant.ID.self) { id in
                PlantView(plantID: id)
                    .navigationTransition(.zoom(sourceID: id, in: cardZoom))
            }
        }
    }

    private var roomBar: some View {
        RoomPicker(rooms: garden.rooms.map(\.name), selection: $roomIndex)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.contentMargin)
            .background(alignment: .top) { headerWash }
    }

    /// Растяжка под строкой комнаты. В макете такая гасит узор у края
    /// экрана; здесь она едет вместе со строкой и гасит всё, что под неё
    /// заезжает, — заголовок раздела и верхние карточки.
    ///
    /// Вверх уходит с запасом, за край экрана: прилипнув, строка встаёт
    /// под строку состояния, и содержимое проезжает ещё и там. Сход
    /// прицеплен к низу строки, а не задан абсолютной высотой, — так он
    /// не поедет, если подпись комнаты займёт другую высоту.
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
        .padding(.top, -Metrics.headerWashRise)
        .padding(.bottom, -Metrics.headerWashDrop)
        .allowsHitTesting(false)
    }

    /// Стекло всех карточек рисуется одним проходом, а не по проходу на
    /// карточку: ради этого контейнер и существует. Нулевой шаг — чтобы
    /// соседние карточки не сливались краями: слияние тут не задумано.
    private var grid: some View {
        GlassEffectContainer(spacing: 0) {
            cards
        }
    }

    private var cards: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Metrics.gutterH),
                GridItem(.flexible(), spacing: Metrics.gutterH),
            ],
            spacing: Metrics.gutterV
        ) {
            ForEach(Array(room.plants.enumerated()), id: \.element.id) { item in
                NavigationLink(value: item.element.id) {
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
        .onChange(of: roomIndex) { _, _ in revealed.reset() }
    }
}
