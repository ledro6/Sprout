import ARKit
import SwiftUI

/// Растение в комнате. Камера находит пол или стол, растение встаёт туда в
/// натуральную величину: двумя пальцами его поворачивают, щипком растягивают,
/// пальцем двигают. Над ним — табличка с процентами. «Полить» зовёт лейку, и
/// полив засчитывается, когда вода коснулась земли.
struct PlantAR: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var stage = Stage()

    /// Без отслеживания мира экрана нет — в симуляторе кнопка не появляется.
    static var available: Bool { ARWorldTrackingConfiguration.isSupported }

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        // Табличка — в одних координатах с камерой: обе во весь экран.
        StageView(stage: stage)
            .overlay(alignment: .topLeading) { label }
            .ignoresSafeArea()
            .sproutUndo()
            .safeAreaInset(edge: .bottom) { controls }
            .overlay(alignment: .top) { header }
            .animation(Motion.enter, value: stage.phase)
            .tint(Palette.accent)
            .onAppear(perform: start)
            .onDisappear { stage.stop() }
            .onChange(of: plant == nil) { _, gone in
                if gone { dismiss() }
            }
    }

    private func start() {
        guard let plant else { return }
        stage.cast(plant, in: garden)
        stage.onWatered = { [garden, plantID] in
            guard Bin.shared.water(plantID, in: garden) else { return }
            Feel.water()
        }
    }

    // MARK: - Табличка

    @ViewBuilder
    private var label: some View {
        if let spot = stage.tag, let plant {
            VStack(spacing: 2) {
                Text(plant.name)
                    .font(Typography.toastTitle)
                    .foregroundStyle(Palette.ink)
                Text("Влажность \(plant.moistureLabel)")
                    .font(Typography.toastNote)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(plant.wateringLabel)
                    .font(Typography.toastNote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .animation(Motion.number, value: plant.moisture)
            .fixedSize()
            .position(x: spot.x, y: spot.y - 36)
            .allowsHitTesting(false)
            .transition(.blurReplace)
        }
    }

    // MARK: - Верх и низ

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Typography.navTitle)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Закрыть")

            Spacer(minLength: 0)

            Text(hint)
                .font(Typography.toastNote)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassEffect(.regular, in: .capsule)
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
        case .searching: "Медленно ведите телефоном над полом или столом"
        case .aiming where !stage.ready: "Готовлю модель растения…"
        case .aiming: "Нажмите — и растение встанет сюда"
        case .placed: "Двумя пальцами — повернуть, щипком — размер"
        case .watering: "Поливаем…"
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
                    Label("Поставить", systemImage: "arkit")
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
                Button { stage.water() } label: {
                    Label("Полить", systemImage: "drop.fill")
                        .font(Typography.detail)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .disabled(stage.phase == .watering
                  || (stage.phase == .aiming && !stage.ready))
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }
}
