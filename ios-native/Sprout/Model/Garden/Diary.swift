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

    /// Точка линии высыхания: сколько воды в земле и не полив ли это.
    struct Point: Hashable, Identifiable, Sendable {
        var when: Date
        var level: Double
        /// Точка сразу после полива — на ней капля.
        var poured = false

        var id: String { "\(when.timeIntervalSince1970)-\(poured)" }
    }

    /// Сколько дней сада видно на графике.
    static let span = 30.0

    /// Линия высыхания за последние `span` дней сада: полив поднимает к
    /// единице, дальше земля сохнет ровно по сроку растения, а упав до нуля —
    /// лежит на дне, пока не польют. Перед поливом — сколько воды осталось
    /// на самом деле, если журнал это помнит. Последняя точка — сейчас.
    static func curve(_ log: [Watering], plant: Plant, now: Date = Date())
        -> [Point] {
        let dry = Agenda.real(max(plant.period, 0.01))
        let from = now.addingTimeInterval(-Agenda.real(span))
        let pours = log.filter { $0.plant == plant.id && $0.when <= now }
            .sorted { $0.when < $1.when }
        let inside = pours.filter { $0.when >= from }
        var points: [Point] = []
        // Что было в начале окна — по поливу до него, если он был.
        if let before = pours.last(where: { $0.when < from }) {
            let left = 1 - from.timeIntervalSince(before.when) / dry
            points.append(Point(when: from, level: max(left, 0)))
        }
        var last: (when: Date, level: Double)? = points.last.map {
            ($0.when, $0.level)
        }
        func slide(to moment: Date, ending: Double?) {
            guard let start = last else { return }
            let fall = moment.timeIntervalSince(start.when) / dry
            let end = ending ?? max(start.level - fall, 0)
            // Высохла раньше — лежит на дне, пока не польют.
            let bottom = start.when.addingTimeInterval(start.level * dry)
            if end <= 0.001, start.level > 0, bottom < moment {
                points.append(Point(when: bottom, level: 0))
            }
            points.append(Point(when: moment, level: end))
        }
        for pour in inside {
            slide(to: pour.when, ending: pour.left.map { min(max($0, 0), 1) })
            points.append(Point(when: pour.when, level: 1, poured: true))
            last = (pour.when, 1)
        }
        if last != nil {
            slide(to: now, ending: min(max(plant.moisture, 0), 1))
        }
        return points
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
