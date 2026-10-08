import SwiftUI

/// Карточка растения: фото, кличка, влажность и срок полива. На главной — с
/// каплей «Полить» под фото, в нижней строке: поверх фото она закрывала
/// растение. Срочная карточка (сухо или скоро пить) кроме свечения несёт
/// значок статуса перед кличкой: в оттенках серого свечение не видно.
struct PlantCard: View {
    let plant: Plant

    /// Капля «Полить»; у предпросмотров меню и перетаскивания её нет.
    var drop = false

    /// Крупный шрифт: кличка и процент встают друг под другом, а кличка
    /// переносится, а не обрезается.
    @Environment(\.dynamicTypeSize) private var type

    private var big: Bool { type.isAccessibilitySize }

    var body: some View {
        let head = big
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 4))
        VStack(alignment: .leading, spacing: 8) {
            PlantPhoto(plant: plant)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    ModelBadge(plant: plant)
                        .padding(Metrics.modelBadgeInset)
                }

            head {
                if urgent {
                    Image(systemName: plant.status.symbol)
                        .foregroundStyle(StatusStyle(plant.status).color)
                        .accessibilityLabel(plant.status.word)
                }
                Text(plant.name)
                    .lineLimit(big ? nil : 2)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())
                if !big { Spacer(minLength: 4) }
                // Переход цифр: знак процента стоит на месте, и кличку ничто
                // не толкает вбок.
                Text(plant.moistureLabel)
                    .contentTransition(.numericText())
            }
            .font(Typography.cardTitle)
            .foregroundStyle(Palette.ink)
            // По подписи, а не по доле: доля меняется каждую секунду, и
            // анимация запускалась на каждой карточке без видимой перемены.
            .animation(Motion.number, value: plant.moistureLabel)
            .modifier(Sharpen())

            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plant.wateringLabel)
                        .font(Typography.cardCaption)
                        .foregroundStyle(Palette.ink)
                        // Две строки не страшны: капля стоит рядом, а не
                        // под подписью.
                        .lineLimit(big ? nil : 2)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText())
                        .animation(Motion.number, value: plant.daysUntilWatering)
                    // Откуда процент над ней: «Датчик» или «Расчёт».
                    SourceBadge(estimated: plant.estimated)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if drop {
                    WaterDrop(plant: plant)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .modifier(Sharpen())

            RecentPour(plant: plant)
        }
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .sproutSolidPlate(in: shape)
        .modifier(PlantGlow(plant: plant, shape: shape))
    }

    /// Срочная: свечение горит — «скоро пить» или «сухо».
    private var urgent: Bool {
        plant.status == .urgent || plant.status == .soon
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
