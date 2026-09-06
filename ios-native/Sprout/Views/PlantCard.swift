import SwiftUI

/// Карточка растения: стеклянная плашка, фото, кличка, влажность и срок
/// полива.
///
/// Анимаций тут не написано ни одной. Нажатие обрабатывает система:
/// `.glassEffect` с `interactive` даёт штатный отклик стекла, а переход
/// на экран растения делает NavigationLink.
struct PlantCard: View {
    let plant: Plant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(plant.photo)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

            HStack {
                Text(plant.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text(plant.moistureLabel)
            }
            .font(Typography.cardTitle)
            .foregroundStyle(.black)

            Text(plant.wateringLabel)
                .font(Typography.cardCaption)
                .foregroundStyle(.black)
                .lineLimit(2)
                .frame(height: 24, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: Metrics.cardRadius, style: .continuous)
        )
        // Тень из макета: смещение (0, 8), размытие 40 — у SwiftUI радиус
        // задаётся вдвое меньшим числом, чем блюр в Figma.
        .shadow(color: glow, radius: 20, x: 0, y: 8)
    }

    private var glow: Color {
        switch plant.thirst {
        case .calm: Palette.shadow
        case .soon: Palette.thirsty
        case .now: Palette.thirstyNow
        }
    }
}
