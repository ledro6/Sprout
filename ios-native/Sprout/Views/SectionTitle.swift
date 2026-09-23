import SwiftUI

/// Заголовок раздела. Не системный: системный при прокрутке переезжает в
/// панель сверху, а этот уезжает с содержимым, как в Музыке.
struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.largeTitle.bold())
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .sproutRide()
    }
}
