import SwiftUI

/// Главная: выбор комнаты и сетка растений.
struct HomeView: View {
    @State private var roomIndex = 0

    /// Пространство для перехода на растение: карточка не исчезает, а
    /// разворачивается в экран.
    @Namespace private var cardZoom

    private var room: Room { Garden.rooms[roomIndex] }

    var body: some View {
        NavigationStack {
            ScrollView {
                grid
            }
            .background { SproutBackground(topWash: false) }
            // Строка комнаты закреплена и не уезжает: карточки проходят
            // под ней и гаснут в растяжке.
            .safeAreaInset(edge: .top, spacing: 0) { roomBar }
            .overlay(alignment: .top) { badge }
            // Заголовок системный — тот же, что у остальных вкладок:
            // крупный, сам съезжает в строку при прокрутке, сам получает
            // стекло под собой. Своей вёрстки для него не нужно.
            .navigationTitle("Главная")
            .navigationDestination(for: Plant.self) { plant in
                PlantView(plant: plant)
                    .navigationTransition(.zoom(sourceID: plant.id, in: cardZoom))
            }
        }
    }

    private var roomBar: some View {
        RoomPicker(rooms: Garden.rooms.map(\.name), selection: $roomIndex)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.contentMargin)
            .background(alignment: .top) { headerWash }
    }

    /// Плашка стоит там же, где в макете, — в 19 pt от верха экрана, то
    /// есть наполовину за вырезом.
    ///
    /// Это отдельный слой во весь экран, безопасную зону игнорирующий.
    /// Внутри шапки её было не видно вовсе: та живёт в безопасной зоне, и
    /// всё, что вылезает выше, срезается.
    private var badge: some View {
        SproutBadge()
            .padding(.top, Metrics.badgeTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    /// Растяжка под строкой комнаты. В макете такая гасит узор у края
    /// экрана; здесь она переехала в закреплённый слой, потому что под ней
    /// проезжает содержимое и она должна успеть его увести, прежде чем
    /// оно дойдёт до текста.
    ///
    /// Вверх уходит с запасом — за панель навигации и дальше за край
    /// экрана, иначе была бы видна её верхняя кромка. Сход прицеплен к
    /// низу строки, а не задан абсолютной высотой: так он не поедет,
    /// сколько бы места ни занял системный заголовок.
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
                .modifier(CardAppear(index: item.offset, room: roomIndex))
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
    }
}
