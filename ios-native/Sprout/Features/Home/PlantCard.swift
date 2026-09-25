import SwiftUI

/// Карточка растения: фото, кличка, влажность и срок полива.
struct PlantCard: View {
    let plant: Plant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlantPhoto(plant: plant)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    ModelBadge(plant: plant)
                        .padding(Metrics.modelBadgeInset)
                }

            HStack {
                Text(plant.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())
                Spacer(minLength: 4)
                // Переход цифр: знак процента стоит на месте, и кличку ничто
                // не толкает вбок.
                Text(plant.moistureLabel)
                    .contentTransition(.numericText())
            }
            .font(Typography.cardTitle)
            .foregroundStyle(Palette.ink)
            .animation(Motion.number, value: plant.moisture)
            .modifier(Sharpen())

            Text(plant.wateringLabel)
                .font(Typography.cardCaption)
                .foregroundStyle(Palette.ink)
                // Одна строка: самая длинная подпись помещается; предел — на
                // случай крупного шрифта.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(Motion.number, value: plant.daysUntilWatering)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(Sharpen())
        }
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .sproutPlate(in: shape, interactive: true)
        .modifier(PlantGlow(plant: plant, shape: shape))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }
}

/// Сборка своей модели по снимку — значком на снимке, пока она идёт.
/// Собралась — значок ещё миг показывает сотню и уходит. У готовых моделей
/// видов значка нет: собирать нечего.
struct ModelBadge: View {
    let plant: Plant

    /// Что на значке — отстаёт от доски на миг сотни.
    @State private var shown: Double?

    var body: some View {
        ZStack {
            if let shown {
                Label {
                    Text(Bench.percent(shown))
                        .contentTransition(.numericText())
                } icon: {
                    Image(systemName: "arkit")
                }
                .font(Typography.modelBadge)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                // Материал, а не стекло: карточка сама стеклянная.
                .background(.regularMaterial, in: .capsule)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Bench.preparing(shown))
                .transition(.blurReplace)
            }
        }
        .animation(Motion.number, value: shown)
        .onChange(of: Bench.shared.share(plant), initial: true) { _, now in
            settle(now)
        }
    }

    private func settle(_ now: Double?) {
        guard let now else {
            shown = nil
            return
        }
        guard now >= 1 else {
            shown = now
            return
        }
        // Готова: значка не было — и не надо; был — пусть покажет сотню.
        guard shown != nil else { return }
        shown = 1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.modelLinger))
            if shown == 1 { shown = nil }
        }
    }
}
