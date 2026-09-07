import SwiftUI

/// Заголовок раздела: «Главная», «Профиль» и прочие.
///
/// Намеренно не системный. Системный при прокрутке не исчезает, а
/// переезжает в панель сверху и остаётся там; нужно, чтобы он уходил
/// вместе с содержимым, как в Музыке. Начертание то же, что у системного
/// крупного заголовка, — 34 pt bold, — и поле по левому краю то же.
struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.largeTitle.bold())
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }
}
