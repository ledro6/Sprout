import SwiftUI

/// «Полила Маша, 5 мин назад» — под карточкой и строкой растения, пока
/// чужому поливу меньше часа. Минуты идут сами: подпись обновляется раз в
/// минуту. Не в общем саду и после своего полива — пусто.
struct RecentPour: View {
    let plant: Plant

    var body: some View {
        // Сад — общий, а не из окружения: карточку показывают и предпросмотры
        // меню, куда окружение не доходит.
        if let entry = Kinship.shared.recent(plant.id, in: Garden.shared.log) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                if let line = Family.ago(entry, now: context.date) {
                    Label(line, systemImage: "person.2.fill")
                        .font(Typography.cardCaption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}
