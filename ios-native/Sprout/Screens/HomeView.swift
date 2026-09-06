import SwiftUI

/// Главный экран: приветствие, выбор комнаты и сетка растений.
struct HomeView: View {
    @State private var roomIndex = 0

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
            // Плашка с логотипом закреплена и не уезжает с прокруткой:
            // safeAreaInset отдаёт ей полосу сверху, содержимое проезжает
            // под ней.
            .safeAreaInset(edge: .top) {
                SproutBadge().padding(.bottom, 6)
            }
            .navigationDestination(for: Plant.self) { PlantView(plant: $0) }
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
