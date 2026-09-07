import SwiftUI

/// Главный экран: приветствие, выбор комнаты и сетка растений.
struct HomeView: View {
    @State private var roomIndex = 0

    /// Вставка окна сверху. До первого замера берём типичную для телефона
    /// с вырезом, чтобы шапка не дёргалась на первом кадре.
    @State private var topInset: CGFloat = 47

    private var room: Room { Garden.rooms[roomIndex] }

    var body: some View {
        NavigationStack {
            ScrollView {
                grid
            }
            .background { SproutBackground() }
            .background { insetProbe }
            // Шапка закреплена и не уезжает: приветствие и комната всегда
            // на виду, карточки проезжают под ними и гаснут в растяжке.
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .navigationDestination(for: Plant.self) { PlantView(plant: $0) }
        }
    }

    private var topBar: some View {
        header
            .background(alignment: .top) { headerWash }
            .overlay(alignment: .top) { badge }
    }

    /// Плашка стоит там же, где в макете, — в 19 pt от верха экрана, то
    /// есть наполовину за вырезом. В поток она не входит: `overlay`
    /// высоты не занимает, и шапка встаёт по макету, а не под плашкой.
    private var badge: some View {
        SproutBadge()
            .offset(y: -max(0, topInset - Metrics.badgeTop))
    }

    /// Растяжка под шапкой. Та же, что в макете гасит узор у края экрана,
    /// но лежит уже не в фоне, а в закреплённом слое: под ней проезжает
    /// содержимое, и она должна успеть увести его в белый прежде, чем оно
    /// дойдёт до текста.
    ///
    /// Сплошная часть тянется ровно на высоту шапки, а сход прицеплен к
    /// её низу — так он не зависит от того, сколько места на самом деле
    /// заняло приветствие своим шрифтом.
    private var headerWash: some View {
        VStack(spacing: 0) {
            Palette.background
            LinearGradient(
                colors: [Palette.background, Palette.background.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Metrics.headerWashFade)
        }
        // Вверх — до самого верха экрана, под плашку с логотипом; вниз —
        // на 3 pt, ровно до карточек. Отрицательные поля выпускают
        // растяжку за границы шапки, не меняя её собственной высоты.
        .padding(.top, -topInset)
        .padding(.bottom, -Metrics.headerWashOverhang)
        .allowsHitTesting(false)
    }

    /// Мерка вставок окна. Внутри безопасной зоны они читаются нулями,
    /// поэтому вью сначала выходит за неё, а уже потом спрашивает.
    private var insetProbe: some View {
        Color.clear
            .ignoresSafeArea()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.safeAreaInsets.top
            } action: { inset in
                topInset = inset
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Добро пожаловать,\n\(Garden.owner)!")
                .font(Typography.greeting)
                .foregroundStyle(.black)

            RoomPicker(rooms: Garden.rooms.map(\.name), selection: $roomIndex)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, max(0, Metrics.headerTop - topInset))
        .padding(.horizontal, Metrics.margin)
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
                // Появление ведёт сама карточка: при смене комнаты
                // растения другие, значит и вью другие, и каждое въезжает
                // со своей задержкой. Уходящим достаётся только затухание —
                // новые к этому времени уже поднимаются на их места.
                .modifier(CardAppear(index: item.offset))
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
        }
        .padding(.top, 3)
        .padding(.horizontal, Metrics.margin)
        .padding(.bottom, 24)
    }
}
