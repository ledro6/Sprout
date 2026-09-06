import SwiftUI

/// Карточка растения: стеклянная плашка, фото, кличка, влажность и срок
/// полива.
///
/// Тени на самом стекле нет намеренно. `.shadow` заставляет систему
/// растеризовать вью отдельным слоем, стекло при этом теряет фон, который
/// должно преломлять, и превращается в глухую тёмную плашку. Всё, что
/// нужно нарисовать за стеклом, кладётся в `.background` — он рисуется
/// позади вью вместе со стеклом, и стекло его честно преломляет.
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
            .clear.interactive(),
            in: .rect(cornerRadius: Metrics.cardRadius, style: .continuous)
        )
        .background { glow }
    }

    /// Тревожное свечение — только ореолом по контуру, а не заливкой:
    /// заливка просвечивала бы сквозь прозрачное стекло и красила саму
    /// карточку, а в макете розовое лежит вокруг неё.
    @ViewBuilder
    private var glow: some View {
        if plant.thirst != .calm {
            RoundedRectangle(
                cornerRadius: Metrics.cardRadius, style: .continuous
            )
            .stroke(
                plant.thirst == .now ? Palette.thirstyNow : Palette.thirsty,
                lineWidth: 16)
            .blur(radius: 14)
        }
    }
}
