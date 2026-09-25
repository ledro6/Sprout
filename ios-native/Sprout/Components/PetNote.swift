import SwiftUI

/// Можно ли растение питомцам — строкой под полем вида, пока его вписывают.
/// Незнакомый вид — пусто: гадать о чужом коте не будем.
struct PetNote: View {
    let species: String

    var body: some View {
        let danger = Toxicity.of(species)
        Group {
            if let danger {
                Label(danger.line, systemImage: "pawprint.fill")
                    .font(Typography.settingNote)
                    .foregroundStyle(tone(of: danger))
                    .transition(.blurReplace)
            }
        }
        .animation(Motion.number, value: danger)
    }

    /// Те же цвета, что строка на экране растения.
    private func tone(of danger: Toxicity) -> Color {
        switch danger {
        case .safe: .secondary
        case .toxic: Palette.warn
        case .lily, .deadly: Palette.alarm
        }
    }
}
