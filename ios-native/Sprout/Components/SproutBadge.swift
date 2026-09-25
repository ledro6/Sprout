import SwiftUI

/// Плашка под чёлкой: логотип и название. Размеры из макета.
struct SproutBadge: View {
    var body: some View {
        HStack(spacing: 2.5) {
            SproutLogo()
            Text("Sprout")
                .font(Typography.wordmark)
                // Чёрный в обеих темах: плашка светло-зелёная всегда — это
                // знак, а не поверхность.
                .foregroundStyle(.black)
        }
        .padding(.leading, 6.9)
        .padding(.trailing, 7.6)
        .frame(height: 28)
        .background(Palette.greenSoft, in: .capsule)
    }
}
