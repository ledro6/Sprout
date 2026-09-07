import SwiftUI

/// Группа в списке: подпись и стеклянная плашка с содержимым.
///
/// Ровно то, чем в системных приложениях служит секция списка, только
/// плашка здесь своя — та же, что у карточек растений.
struct PlateSection<Content: View>: View {
    private let title: String?
    private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(Typography.cardCaption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
            }
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .sproutPlate(
                in: RoundedRectangle(cornerRadius: Metrics.rowRadius,
                                     style: .continuous))
        }
        .padding(.horizontal, Metrics.contentMargin)
    }
}
