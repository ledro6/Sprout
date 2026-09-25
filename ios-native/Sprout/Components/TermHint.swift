import SwiftUI

/// «?» у непонятного слова: нажал — всплывает пояснение простыми словами.
/// Пузырём у самого слова, а не листом снизу: слово остаётся на виду.
struct TermHint: View {
    let term: Term

    @State private var open = false

    init(_ term: Term) {
        self.term = term
    }

    var body: some View {
        Button { open = true } label: {
            Image(systemName: "questionmark.circle")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                // Значок мелкий — палец ловит поле вокруг, а строка от
                // этого не растёт.
                .padding(Metrics.hintReach)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(-Metrics.hintReach)
        .accessibilityLabel(Lang.format("Что значит «%@»", term.title))
        .popover(isPresented: $open) {
            TermCard(term: term)
                .padding(Metrics.groupPadding)
                .frame(width: Metrics.hintWidth)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// Слово и пояснение — в пузыре у «?» и строкой словарика.
struct TermCard: View {
    let term: Term

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: term.icon)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(term.title)
                    .font(Typography.settingRow.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(term.meaning)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
