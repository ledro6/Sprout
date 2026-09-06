import SwiftUI

/// Главный экран: приветствие, выбор комнаты и сетка растений.
struct HomeView: View {
    @State private var roomIndex = 0
    @State private var menuOpen = false
    /// Левый верхний угол кнопки комнаты — из него вырастает меню.
    @State private var pickerAnchor: CGPoint = .zero

    private var room: Room { Garden.rooms[roomIndex] }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        grid
                    }
                }
                .background { SproutBackground() }
                .navigationDestination(for: Plant.self) { PlantView(plant: $0) }
            }

            if menuOpen {
                RoomMenu(
                    rooms: Garden.rooms.map(\.name),
                    selected: roomIndex,
                    anchor: pickerAnchor,
                    onPick: { index in
                        roomIndex = index
                        withAnimation(.smooth) { menuOpen = false }
                    },
                    onDismiss: { withAnimation(.smooth) { menuOpen = false } }
                )
            }
        }
        .coordinateSpace(.named("screen"))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Добро пожаловать,\n\(Garden.owner)!")
                .font(Typography.greeting)
                .foregroundStyle(.black)

            RoomPickerButton(room: room.name) {
                withAnimation(.smooth) { menuOpen = true }
            }
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named("screen"))
            } action: { frame in
                pickerAnchor = frame.origin
            }
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
            ForEach(room.plants) { plant in
                NavigationLink(value: plant) {
                    PlantCard(plant: plant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 3)
        .padding(.horizontal, Metrics.margin)
    }
}
