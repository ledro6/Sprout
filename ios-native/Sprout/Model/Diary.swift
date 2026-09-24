import Foundation

/// Поливы одного растения — из общего журнала сада, а не отдельным списком у
/// растения, который пришлось бы держать согласованным. Время настоящее, не
/// садовое.
struct Diary: Equatable {
    var entries: [Date]

    static let shown = 6

    var total: Int { entries.count }

    /// Пусто, пока поливов меньше двух.
    var average: TimeInterval? {
        guard let first = entries.last, let last = entries.first,
              entries.count > 1 else { return nil }
        return last.timeIntervalSince(first) / Double(entries.count - 1)
    }

    static func of(_ log: [Watering], plant: Plant.ID) -> Diary {
        Diary(entries: log.filter { $0.plant == plant }
            .map(\.when)
            .sorted(by: >))
    }

    /// «Сегодня, 14:05», «Вчера, 9:12», «20 сентября, 18:40», прошлогоднее —
    /// с годом. Числа и месяцы — по-местному: у кого «9:12», у кого
    /// «9:12 AM».
    static func label(_ moment: Date, now: Date = Date(),
                      calendar: Calendar = .current) -> String {
        let time = moment.formatted(Date.FormatStyle(calendar: calendar,
                                                     timeZone: calendar.timeZone)
            .hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
            .locale(Lang.locale))
        if calendar.isDate(moment, inSameDayAs: now) {
            return Lang.format("Сегодня, %@", time)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(moment, inSameDayAs: yesterday) {
            return Lang.format("Вчера, %@", time)
        }
        var style = Date.FormatStyle(calendar: calendar,
                                     timeZone: calendar.timeZone)
            .day().month(.wide).locale(Lang.locale)
        if calendar.component(.year, from: moment)
            != calendar.component(.year, from: now) {
            style = style.year()
        }
        return Lang.format("%1$@, %2$@", moment.formatted(style), time)
    }

    /// «раз в 3 дня», «раз в 5 ч» — крупнейшей единицей, в которой выходит
    /// хотя бы одна.
    static func rhythm(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return Lang.text("чаще раза в минуту") }
        if seconds < 3_600 {
            let minutes = Int((seconds / 60).rounded())
            return minutes <= 1 ? Lang.text("раз в минуту")
                : Lang.format("раз в %lld минут", minutes)
        }
        if seconds < 86_400 {
            let hours = Int((seconds / 3_600).rounded())
            return hours <= 1 ? Lang.text("раз в час")
                : Lang.format("раз в %lld часов", hours)
        }
        let days = Int((seconds / 86_400).rounded())
        return days <= 1 ? Lang.text("раз в день")
            : Lang.format("раз в %lld дней", days)
    }
}
