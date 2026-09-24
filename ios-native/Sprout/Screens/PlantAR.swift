import ARKit
import SwiftUI

/// Растение или весь сад комнаты — в комнате. Камера находит пол или стол,
/// растения встают туда в натуральную величину: двумя пальцами их
/// поворачивают, щипком растягивают, пальцем двигают. Над каждым —
/// табличка с процентами. «Полить» зовёт лейку, и полив засчитывается,
/// когда вода коснулась земли; в саду сперва выбирают, кого поливать, или
/// поливают всех сухих по очереди.
struct PlantAR: View {
    let ids: [Plant.ID]

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var stage = Stage()

    init(plantID: Plant.ID) {
        ids = [plantID]
    }

    init(ids: [Plant.ID]) {
        self.ids = ids
    }

    /// Без отслеживания мира экрана нет — в симуляторе кнопка не появляется.
    static var available: Bool { ARWorldTrackingConfiguration.isSupported }

    private var plants: [Plant] { ids.compactMap { garden.plant(id: $0) } }

    var body: some View {
        // Таблички — в одних координатах с камерой: обе во весь экран.
        StageView(stage: stage)
            .overlay(alignment: .topLeading) { labels }
            .ignoresSafeArea()
            .sproutUndo()
            .safeAreaInset(edge: .bottom) { controls }
            .overlay(alignment: .top) { header }
            .animation(Motion.enter, value: stage.phase)
            .animation(Motion.enter, value: stage.chosen)
            .tint(Palette.accent)
            .onAppear(perform: start)
            .onDisappear { stage.stop() }
            .onChange(of: plants.isEmpty) { _, gone in
                if gone { dismiss() }
            }
    }

    private func start() {
        stage.cast(plants, in: garden)
        stage.onWatered = { [garden] id in
            guard Bin.shared.water(id, in: garden) else { return }
            Feel.water()
        }
    }

    // MARK: - Таблички

    private var labels: some View {
        ForEach(plants) { plant in
            if let spot = stage.tags[plant.id] {
                label(plant, big: !stage.many || stage.chosen == plant.id)
                    .position(x: spot.x, y: spot.y - 36)
                    .transition(.blurReplace)
            }
        }
    }

    /// Выбранное — полной табличкой, остальные — кличкой и процентами: иначе
    /// сад тонул бы в табличках.
    private func label(_ plant: Plant, big: Bool) -> some View {
        VStack(spacing: 2) {
            Text(plant.name)
                .font(Typography.toastTitle)
                .foregroundStyle(Palette.ink)
            Text(Lang.format("Влажность %@", plant.moistureLabel))
                .font(Typography.toastNote)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            if big {
                Text(plant.wateringLabel)
                    .font(Typography.toastNote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, big ? 14 : 10)
        .padding(.vertical, big ? 10 : 6)
        .glassEffect(big && stage.many
                         ? Glass.regular.tint(Palette.accent.opacity(0.25))
                         : Glass.regular,
                     in: .rect(cornerRadius: 18))
        .animation(Motion.number, value: plant.moisture)
        .fixedSize()
        .allowsHitTesting(false)
    }

    // MARK: - Верх и низ

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Typography.navTitle)
                    .frame(width: Metrics.gearBox, height: Metrics.gearBox)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Закрыть")

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text(hint)
                    .font(Typography.toastNote)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                if stage.left > 0 {
                    Text(Lang.format("Показаны %1$lld из %2$lld: больше телефону тяжело",
                                     stage.total, stage.total + stage.left))
                        .font(Typography.toastNote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .id(hint)
            .transition(.blurReplace)

            Spacer(minLength: 0)

            // Противовес крестику — подсказка встаёт ровно посередине.
            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Metrics.contentMargin)
    }

    private var hint: String {
        switch stage.phase {
        case .searching:
            Lang.text("Медленно ведите телефоном над полом или столом")
        case .aiming where !stage.ready:
            stage.many
                ? Lang.format("Готовлю модели растений: %1$lld из %2$lld",
                              stage.loaded, stage.total)
                : Lang.text("Готовлю модель растения…")
        case .aiming:
            stage.many ? Lang.text("Нажмите — и сад встанет вокруг прицела")
                : Lang.text("Нажмите — и растение встанет сюда")
        case .placed where stage.many && stage.chosen == nil:
            Lang.text("Нажмите на растение, чтобы выбрать его")
        case .placed:
            Lang.text("Двумя пальцами — повернуть, щипком — размер")
        case .watering:
            stage.queue.isEmpty ? Lang.text("Поливаем…")
                : Lang.text("Поливаем по очереди…")
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            switch stage.phase {
            case .searching:
                EmptyView()
            case .aiming:
                Button { stage.place() } label: {
                    Group {
                        if stage.many {
                            Label("Поставить сад", systemImage: "arkit")
                        } else {
                            Label("Поставить", systemImage: "arkit")
                        }
                    }
                    .font(Typography.detail)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
            case .placed, .watering:
                Button { stage.replace() } label: {
                    Label("Переставить", systemImage: "move.3d")
                        .font(Typography.detail)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                if stage.many && stage.thirsty > 0 {
                    Button { stage.waterThirsty() } label: {
                        Label("Полить сухих", systemImage: "drop.triangle")
                            .font(Typography.detail)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .transition(.blurReplace)
                }
                Button { stage.water() } label: {
                    Label("Полить", systemImage: "drop.fill")
                        .font(Typography.detail)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .disabled(stage.many && stage.chosen == nil)
            }
        }
        .disabled(stage.phase == .watering
                  || (stage.phase == .aiming && !stage.ready))
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }
}
