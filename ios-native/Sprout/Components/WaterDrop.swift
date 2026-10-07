import SwiftUI

/// Капля «Полить» на главной — полив одним нажатием, не открывая растение.
/// Та же волна от карточки, стук капель и плашка «Вернуть», что у кнопки на
/// экране растения. Полному растению лить некуда — капля бледнеет.
struct WaterDrop: View {
    let plant: Plant

    @Environment(Garden.self) private var garden

    /// Чужой полив меньше часа назад, о котором спрашиваем перед своим.
    @State private var asking: Watering?

    private var full: Bool { plant.moisture >= 0.99 }

    /// Только что полил кто-то из семьи — капля приглушена, нажатие сначала
    /// спрашивает: два полива подряд заливают корни.
    private var recent: Watering? {
        Kinship.shared.recent(plant.id, in: garden.log)
    }

    var body: some View {
        Button {
            if let recent { asking = recent } else { pour() }
        } label: {
            // Пересыхает — капля дышит: зовёт полить.
            Image(systemName: "drop.fill")
                .font(.system(size: Metrics.dropGlyph, weight: .semibold))
                .symbolEffect(.breathe, isActive: plant.thirst == .alarm
                              && !Power.shared.calm)
                .frame(width: Metrics.dropBox, height: Metrics.dropBox)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(Palette.accentFill)
        .disabled(full)
        .opacity(recent == nil ? 1 : 0.5)
        .animation(Motion.number, value: full)
        .accessibilityLabel(Lang.format("Полить: %@", plant.name))
        .confirmationDialog(asking.map { Family.again($0) } ?? "",
                            isPresented: Binding(
                                get: { asking != nil },
                                set: { if !$0 { asking = nil } }),
                            titleVisibility: .visible) {
            Button("Полить") { pour() }
            Button("Отмена", role: .cancel) {}
        }
    }

    /// Влажную землю — сперва вопрос, см. `Overflow`.
    private func pour() {
        let id = plant.id
        Overflow.shared.water(id, in: garden) {
            // Волна — от карточки, а не от капли: поливают растение.
            let spot = Cards.shared.rect(id)
            Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
            Feel.water()
        }
    }
}
