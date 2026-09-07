import SwiftUI

/// Полоска влажности почвы.
struct MoistureBar: View {
    let level: Double
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.menuItemFill)
                Capsule()
                    .fill(Palette.moisture(level))
                    // Не меньше своей толщины: у пустой полоски иначе
                    // оставался бы обрезок капсулы вместо точки.
                    .frame(width: max(height,
                                      proxy.size.width * min(max(level, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.4), value: level)
    }
}

/// Строка списка: растение, его влажность и, если нужно, лейка.
struct PlantRow: View {
    let plant: Plant
    var caption: String?
    var onWater: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(plant.photo)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plant.name)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(plant.moistureLabel)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Palette.moisture(plant.moisture))
                        .monospacedDigit()
                }
                MoistureBar(level: plant.moisture)
                Text(caption ?? plant.wateringLabel)
                    .font(Typography.cardCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let onWater {
                Button(action: onWater) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Palette.accent)
                .accessibilityLabel("Полить \(plant.name)")
            }
        }
    }
}
