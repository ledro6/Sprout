import SwiftUI

/// Карточка растения: фото, кличка, влажность и срок полива.
///
/// Материал плашки общий для всего приложения — см. `sproutPlate`.
/// У карточки стекло отзывчивое: под пальцем оно проминается и
/// отпускает пружиной, всё это делает сама система.
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
        .sproutPlate(in: shape, interactive: true)
        .background { glow }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }

    /// Тревожное свечение: тот же ореол, что и тень, только красный и без
    /// смещения. В макете розовое лежит строго вокруг карточки — внутри
    /// она остаётся нейтральной.
    @ViewBuilder
    private var glow: some View {
        if plant.thirst != .calm {
            shape.sproutHalo(
                plant.thirst == .now ? Palette.thirstyNow : Palette.thirsty,
                blur: Metrics.glowBlur)
        }
    }
}

/// Появление карточки: поднимается снизу, чуть приближаясь, и
/// проявляется. Соседняя стартует на полкадра позже — сетка не
/// подставляется разом, а набегает волной.
///
/// Движение взято с ленты Сообщений: там при прокрутке вверх содержимое
/// приходит одной пружиной, без затухающей кривой, и потому читается как
/// продолжение жеста, а не как проигранный ролик.
struct CardAppear: ViewModifier {
    /// Порядковый номер карточки в сетке — от него задержка.
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.9, anchor: .top)
            .offset(y: shown ? 0 : 26)
            .onAppear(perform: reveal)
    }

    private func reveal() {
        guard !reduceMotion else {
            shown = true
            return
        }
        withAnimation(
            .spring(duration: 0.45, bounce: 0.28)
                .delay(Double(index) * 0.055)
        ) {
            shown = true
        }
    }
}
