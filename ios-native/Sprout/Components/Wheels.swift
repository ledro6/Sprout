import SwiftUI

/// Процент барабаном — порог влажности для напоминаний: любой целый, а не
/// шаг в десять. Подпись числа — из каталога: у кого знак впереди, у кого
/// через пробел.
struct PercentWheel: View {
    @Binding var share: Double

    var range: ClosedRange<Int> = Settings.thresholds

    private var whole: Int {
        min(max(Int((share * 100).rounded()), range.lowerBound),
            range.upperBound)
    }

    var body: some View {
        HStack(spacing: 6) {
            Picker(Lang.format("%lld%%", whole), selection: Binding(
                get: { whole },
                set: { share = Double($0) / 100 })) {
                ForEach(range, id: \.self) { value in
                    Text(Lang.format("%lld%%", value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: Metrics.wheelWidth + 24, height: Metrics.wheelHeight)
            .clipped()
            Spacer(minLength: 0)
        }
        .font(Typography.settingRow)
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .contain)
    }
}

/// Срок полива барабаном, как в «Таймере»: «Раз в [N] дней». Дробный срок —
/// 4,5 дня из таблицы видов — барабан показывает ближайшим целым и не
/// трогает, пока его не крутили.
struct PeriodWheel: View {
    @Binding var days: Double

    private var whole: Int {
        min(max(Int(days.rounded()), 1), Species.longest)
    }

    var body: some View {
        let (before, after) = Self.around(whole)
        HStack(spacing: 6) {
            if !before.isEmpty { Text(before) }
            Picker(Species.periodLabel(Double(whole)), selection: Binding(
                get: { whole },
                set: { days = Double($0) })) {
                ForEach(1 ... Species.longest, id: \.self) { count in
                    Text(count.formatted()).tag(count)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: Metrics.wheelWidth, height: Metrics.wheelHeight)
            .clipped()
            if !after.isEmpty {
                Text(after)
                    .contentTransition(.interpolate)
                    .animation(Motion.number, value: whole)
            }
            Spacer(minLength: 0)
        }
        .font(Typography.settingRow)
        .foregroundStyle(Palette.ink)
        .accessibilityElement(children: .contain)
    }

    /// Слова по обе стороны барабана — из той же строки каталога, что «Раз в
    /// 7 дней»: порядок слов и форма числа у каждого языка свои, и склеивать
    /// их здесь значило бы переводить заново.
    static func around(_ count: Int) -> (String, String) {
        let line = Species.periodLabel(Double(count))
        let marks = [count.formatted(.number.locale(Lang.locale)), "\(count)"]
        guard let range = marks.lazy.compactMap({ line.range(of: $0) }).first
        else { return (line, "") }
        let trim = CharacterSet.whitespaces
        return (String(line[..<range.lowerBound]).trimmingCharacters(in: trim),
                String(line[range.upperBound...]).trimmingCharacters(in: trim))
    }
}
