import SwiftUI

/// Срок полива степпером: «Раз в [N] дней» и «−/+». Дробный срок — 4,5 дня
/// из таблицы видов — степпер показывает ближайшим целым и не трогает, пока
/// его не нажимали. Барабан заменён: срок меняют без прокрутки.
struct PeriodStepper: View {
    @Binding var days: Double

    private var whole: Int {
        min(max(Int(days.rounded()), 1), Species.longest)
    }

    var body: some View {
        Stepper(value: Binding(get: { whole }, set: { days = Double($0) }),
                in: 1 ... Species.longest) {
            Text(Species.periodLabel(Double(whole)))
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .animation(Motion.number, value: whole)
        }
        .accessibilityElement(children: .contain)
    }
}
