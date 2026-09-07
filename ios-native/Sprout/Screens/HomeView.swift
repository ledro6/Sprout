import SwiftUI

/// Главный экран: приветствие, выбор комнаты и сетка растений.
struct HomeView: View {
    @State private var roomIndex = 0
    @State private var topInset: CGFloat = 0

    private var room: Room { Garden.rooms[roomIndex] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    grid
                }
            }
            .background { SproutBackground() }
            .background { insetProbe }
            // Плашка с логотипом закреплена и не уезжает с прокруткой:
            // safeAreaInset отдаёт ей полосу сверху, содержимое проезжает
            // под ней.
            .safeAreaInset(edge: .top) {
                SproutBadge()
                    .padding(.bottom, 6)
                    // Плашка прижимается к вырезу. safeAreaInset ставит её
                    // на нижнюю границу безопасной зоны, а у телефонов с
                    // островом граница проходит на 14 pt ниже самого
                    // острова — отсюда и была пустая полоса над плашкой.
                    // Сдвиг только рисует её выше: полоса, которую плашка
                    // занимает в потоке, прежней высоты, поэтому
                    // приветствие и карточки остаются на своих местах.
                    .offset(y: -badgeLift)
            }
            .navigationDestination(for: Plant.self) { PlantView(plant: $0) }
        }
    }

    /// Насколько поднять плашку к вырезу.
    ///
    /// Считаем не от границы безопасной зоны, а от нижней кромки самого
    /// выреза, и ставим плашку на 2 pt ниже неё. Кромка известна по типу
    /// выреза: остров кончается на 47.7, чёлка — на 33, и вставка окна
    /// эти два случая различает (у острова она 59–62, у чёлки 47–50).
    ///
    /// Выше кромки плашку поднимать нельзя: она уже выреза и просто
    /// скроется под ним целиком. У экранов без выреза поднимать нечего.
    private var badgeLift: CGFloat {
        guard topInset >= 40 else { return 0 }
        let cutoutBottom: CGFloat = topInset >= 55 ? 47.7 : 33
        return max(0, topInset - cutoutBottom - 2)
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
        // Сверху 11, а не 15 как у приветствия в макете: кнопка комнаты
        // стоит в потоке всеми своими 44 pt, тогда как в макете эти 44 —
        // площадь нажатия, и она на 13 pt заходит за свою строку вверх и
        // вниз. Забираем 4 pt у верхнего поля, и подпись комнаты с
        // карточками встают ровно по макету.
        .padding(.top, 11)
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
        .animation(.easeOut(duration: 0.18), value: roomIndex)
    }
}
