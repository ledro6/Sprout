import SwiftUI

/// Статистика: сколько растений, кому пора пить и как дела по комнатам.
struct StatsView: View {
    @Environment(Garden.self) private var garden

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionTitle("Статистика")
                    tiles
                    watering
                    byRoom
                }
                .padding(.bottom, 28)
            }
            .background { SproutBackground() }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var tiles: some View {
        HStack(spacing: 12) {
            tile("\(garden.allPlants.count)", "растений")
            tile("\(garden.thirsty.count)", "просят воды")
            tile(percent(garden.averageMoisture), "влажность")
        }
        .padding(.horizontal, Metrics.contentMargin)
    }

    private func tile(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.black)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(Typography.cardCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .sproutPlate(
            in: RoundedRectangle(cornerRadius: Metrics.rowRadius,
                                 style: .continuous))
    }

    @ViewBuilder
    private var watering: some View {
        let thirsty = garden.thirsty
        if thirsty.isEmpty {
            PlateSection("Полив") {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.green)
                    Text("Все политы — никто не просит воды")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.black)
                }
            }
        } else {
            PlateSection("Пора полить") {
                ForEach(thirsty) { plant in
                    PlantRow(plant: plant, caption: garden.roomName(of: plant.id)) {
                        withAnimation(.smooth) { garden.water(plant.id) }
                    }
                }
                Button("Полить все") {
                    withAnimation(.smooth) { garden.waterAll() }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Palette.accent)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var byRoom: some View {
        PlateSection("По комнатам") {
            ForEach(garden.rooms) { room in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(room.name)
                            .font(Typography.cardTitle)
                            .foregroundStyle(.black)
                        Spacer(minLength: 8)
                        Text(count(room.plants.count))
                            .font(Typography.cardCaption)
                            .foregroundStyle(.secondary)
                    }
                    MoistureBar(level: room.averageMoisture)
                }
            }
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func count(_ n: Int) -> String {
        "\(n) " + Plant.plural(n, "растение", "растения", "растений")
    }
}
