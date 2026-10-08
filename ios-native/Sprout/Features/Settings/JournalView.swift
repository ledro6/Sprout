import SwiftUI

/// Журнал событий для самопроверки: последние записи, только чтение и
/// «Очистить». Живёт на телефоне, никуда не уходит, см. `Journal`.
struct JournalView: View {
    private let journal = Journal.shared

    var body: some View {
        SproutPage(title: "Журнал событий") {
            Group {
                if journal.enabled {
                    Text("Пишется только на этом телефоне: без фото, кличек и мест.")
                } else {
                    Text("Выключен. Включите в «О приложении» — записи пойдут сюда.")
                }
            }
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if journal.events.isEmpty {
                Text("Пока пусто")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
            } else {
                ForEach(Array(journal.events.reversed().enumerated()),
                        id: \.offset) { item in
                    row(item.element)
                }

                SproutDivider()

                Button(role: .destructive) {
                    journal.clear()
                    Feel.toss()
                } label: {
                    Text("Очистить")
                        .font(Typography.settingRow)
                        .frame(minHeight: Metrics.tapTarget)
                }
            }
        }
    }

    /// Имя события — как в плане, это техническая метка, не перевод.
    private func row(_ event: Journal.Event) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: event.detail.map { event.kind.rawValue + " · " + $0 }
                 ?? event.kind.rawValue)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            Text(event.at.formatted(date: .abbreviated, time: .standard))
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
