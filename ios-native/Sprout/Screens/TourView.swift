import SwiftUI

/// Знакомство при первом запуске: по странице на жест или кнопку, листается
/// пальцем или «Дальше». Пропустить можно сразу, повторить — из настроек.
/// На последней странице — вход в словарик.
struct TourView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0

    /// Один раз на показ: строки берутся на языке телефона.
    private let pages = Tour.pages

    private var last: Bool { page == pages.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        TourPage(page: item, shown: page == item.id)
                            .tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 12) {
                    if last {
                        NavigationLink { GlossaryView() } label: {
                            Label("Словарик",
                                  systemImage: "character.book.closed")
                                .font(Typography.detail)
                        }
                        .buttonStyle(.glass)
                        .transition(.blurReplace)
                    }
                    Button(action: next) {
                        Text(last ? "Начать" : "Дальше")
                            .font(Typography.detail)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, 24)
                .animation(Motion.enter, value: last)
            }
            .background { SproutBackground() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !last {
                        Button("Пропустить", action: finish)
                    }
                }
            }
        }
    }

    private func next() {
        guard !last else { return finish() }
        withAnimation(Motion.enter) { page += 1 }
        Feel.pick()
    }

    private func finish() {
        Settings.shared.toured = true
        dismiss()
    }
}

/// Страница знакомства: знак в стеклянном круге, заголовок и пара строк.
/// Знак подпрыгивает, когда страница приходит на экран.
private struct TourPage: View {
    let page: Tour.Page
    let shown: Bool

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            Image(systemName: page.icon)
                .font(.system(size: Metrics.tourGlyph, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .symbolEffect(.bounce, value: shown)
                .frame(width: Metrics.tourBadge, height: Metrics.tourBadge)
                .glassEffect(.regular, in: .circle)
            Text(page.title)
                .font(Typography.welcome)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Text(page.text)
                .font(Typography.settingRow)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            // Двойной низ: страница держится выше середины, над точками.
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.margin)
        .accessibilityElement(children: .combine)
    }
}

/// Словарик: все непонятные слова приложения с пояснениями — из настроек и
/// с последней страницы знакомства.
struct GlossaryView: View {
    var body: some View {
        SproutPage(title: "Словарик") {
            ForEach(Array(Term.allCases.enumerated()), id: \.element) { item in
                if item.offset > 0 { SproutDivider() }
                TermCard(term: item.element)
            }
        }
    }
}
