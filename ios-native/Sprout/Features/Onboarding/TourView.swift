import SwiftUI

/// Знакомство при первом запуске: три страницы — что делает приложение, как
/// поливать, уведомления (время и «Пока без уведомлений»). Листается пальцем
/// или «Дальше». Пропустить можно сразу, повторить — из настроек. На
/// последней странице — вход в словарик; разрешение на уведомления
/// спрашивается только здесь и по кнопке, после объяснения «зачем».
struct TourView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0

    /// Уведомления не разрешили — страница говорит, где это чинится.
    @State private var refused = false

    /// Один раз на показ: строки берутся на языке телефона.
    private let pages = Tour.pages

    private var last: Bool { page == pages.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        TourPage(page: item, shown: page == item.id,
                                 refused: refused)
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
                    Button(action: last && !refused ? remind : next) {
                        Text(primary)
                            .font(Typography.detail)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                    .controlSize(.extraLarge)
                    if last && !refused {
                        Button("Пока без уведомлений", action: finish)
                            .font(Typography.detail)
                            .buttonStyle(.glass)
                    }
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

    private var primary: String {
        if !last { return Lang.text("Дальше") }
        return refused ? Lang.text("Начать") : Lang.text("Напоминать по утрам")
    }

    private func next() {
        guard !last else { return finish() }
        withAnimation(Motion.enter) { page += 1 }
        Feel.pick()
    }

    /// Системный запрос — по кнопке, после объяснения на странице. Разрешили
    /// — утреннее напоминание включено (`Notifier.ask`); нет — страница
    /// покажет «Открыть Настройки».
    private func remind() {
        Task { @MainActor in
            if await Notifier.ask() {
                finish()
            } else {
                withAnimation(Motion.enter) { refused = true }
            }
        }
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
    var refused = false

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
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if page.id == Tour.reminderPage {
                DatePicker(Lang.text("Время напоминания"),
                           selection: ReminderTimes.date(Binding(
                               get: { Settings.shared.morning },
                               set: { Settings.shared.morning = $0 })),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                if refused { AccessNote(need: .notifications) }
            }
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
