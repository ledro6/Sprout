import SwiftUI

/// Капля «Полить» на главной — полив одним нажатием, не открывая растение.
/// Та же волна от карточки, стук капель и плашка «Вернуть», что у кнопки на
/// экране растения. Полному растению лить некуда — капля бледнеет.
struct WaterDrop: View {
    let plant: Plant

    @Environment(Garden.self) private var garden

    private var full: Bool { plant.moisture >= 0.99 }

    var body: some View {
        Button(action: pour) {
            Image(systemName: "drop.fill")
                .font(.system(size: Metrics.dropGlyph, weight: .semibold))
                .frame(width: Metrics.dropBox, height: Metrics.dropBox)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(Palette.accent)
        .disabled(full)
        .animation(Motion.number, value: full)
        .accessibilityLabel(Lang.format("Полить: %@", plant.name))
    }

    private func pour() {
        guard Bin.shared.water(plant.id, in: garden) else { return }
        // Волна — от карточки, а не от капли: поливают растение.
        let spot = Cards.shared.rect(plant.id)
        Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
        Feel.water()
    }
}
