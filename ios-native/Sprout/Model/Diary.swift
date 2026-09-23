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
    /// с годом. Месяцы своим списком, а не форматтером: строка не зависит от
    /// языка телефона и одинакова в проверке модели.
    static func label(_ moment: Date, now: Date = Date(),
                      calendar: Calendar = .current) -> String {
        let time = clock(moment, calendar: calendar)
        if calendar.isDate(moment, inSameDayAs: now) {
            return "Сегодня, \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(moment, inSameDayAs: yesterday) {
            return "Вчера, \(time)"
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: moment)
        let day = parts.day ?? 1
        let month = months[min(max((parts.month ?? 1) - 1, 0), 11)]
        let year = parts.year ?? 0
        guard year == calendar.component(.year, from: now) else {
            return "\(day) \(month) \(year), \(time)"
        }
        return "\(day) \(month), \(time)"
    }

    /// «раз в 3 дня», «раз в 5 ч» — крупнейшей единицей, в которой выходит
    /// хотя бы одна.
    static func rhythm(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return "чаще раза в минуту" }
        if seconds < 3_600 {
            let minutes = Int((seconds / 60).rounded())
            return minutes <= 1 ? "раз в минуту" : "раз в \(minutes) мин"
        }
        if seconds < 86_400 {
            let hours = Int((seconds / 3_600).rounded())
            return hours <= 1 ? "раз в час" : "раз в \(hours) ч"
        }
        let days = Int((seconds / 86_400).rounded())
        return days <= 1 ? "раз в день"
            : "раз в \(days) " + Plant.plural(days, "день", "дня", "дней")
    }

    private static func clock(_ moment: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: moment)
        let minute = parts.minute ?? 0
        return "\(parts.hour ?? 0):" + (minute < 10 ? "0\(minute)" : "\(minute)")
    }

    private static let months = [
        "января", "февраля", "марта", "апреля", "мая", "июня", "июля",
        "августа", "сентября", "октября", "ноября", "декабря",
    ]
}
