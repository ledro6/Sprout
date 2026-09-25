import Foundation

/// «Уезжаю»: кто дождётся хозяина, а кого должен полить сосед и в какие дни.
/// Считается так, будто перед отъездом полили всех: это первый совет плана.
/// Дни — те же, что у влажности, с поправкой на время года.
enum Trip {
    struct Need: Equatable, Sendable {
        var plant: Plant
        var room: String
        /// Через сколько дней после отъезда земля высохнет досуха.
        var dries: Double
        /// В какие дни от отъезда соседу полить: с запасом, до сухой земли.
        var visits: [Int]
    }

    /// Сосед приходит, пока в земле ещё остаётся десятая часть.
    static let margin = 0.9

    /// Кому нужен сосед — по порядку: кто высохнет раньше, тот выше.
    static func needs(in rooms: [Room], days: Int) -> [Need] {
        var out: [Need] = []
        for room in rooms {
            for plant in room.plants where plant.dryingDays > 0 {
                let lasts = plant.period
                guard Double(days) > lasts else { continue }
                let step = max(1, Int((lasts * margin).rounded(.down)))
                let visits = Array(stride(from: step, to: days, by: step))
                out.append(Need(plant: plant, room: room.name, dries: lasts,
                                visits: visits))
            }
        }
        return out.sorted { $0.dries < $1.dries }
    }

    /// Остальные дождутся сами.
    static func fine(in rooms: [Room], days: Int) -> [Plant] {
        let needy = Set(needs(in: rooms, days: days).map(\.plant.id))
        return rooms.flatMap(\.plants).filter { !needy.contains($0.id) }
    }

    /// Уезжают обычно не сию минуту: по умолчанию — завтра, в начале
    /// следующего часа.
    static func departure(after now: Date = Date(),
                          calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.dateInterval(of: .hour, for: tomorrow)?.end ?? tomorrow
    }

    /// Живое действие живёт восемь часов — отсчёт до отъезда начинается не
    /// раньше, иначе погаснет до него.
    static let countdownSpan: TimeInterval = 8 * 3600

    /// Когда начать отсчёт: сразу, если до отъезда меньше восьми часов, —
    /// иначе за восемь часов до него. Уехавшему отсчитывать нечего.
    static func countdownStart(to leave: Date, now: Date = Date()) -> Date? {
        guard leave > now else { return nil }
        return max(now, leave.addingTimeInterval(-countdownSpan))
    }

    /// Полит перед отъездом — если не раньше, чем за полсуток до него.
    static let fresh: TimeInterval = 12 * 3600

    static func watered(_ rooms: [Room], log: [Watering],
                        now: Date = Date()) -> Bool {
        let recent = Set(log.lazy.filter {
            now.timeIntervalSince($0.when) < fresh
        }.map(\.plant))
        return rooms.allSatisfy { room in
            room.plants.allSatisfy { recent.contains($0.id) }
        }
    }

    /// Когда сосед придёт в первый раз.
    static func firstVisit(_ needs: [Need], leave: Date,
                           calendar: Calendar = .current) -> Date? {
        guard let first = needs.compactMap(\.visits.first).min() else {
            return nil
        }
        return calendar.date(byAdding: .day, value: first,
                             to: calendar.startOfDay(for: leave))
    }

    /// Целых дней между датами — по календарю, а не делением секунд: сутки
    /// бывают в 23 и 25 часов.
    static func days(from leave: Date, to back: Date,
                     calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: leave)
        let to = calendar.startOfDay(for: back)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day
                   ?? 0)
    }

    /// Памятка соседу — текстом, чтобы отправить любым мессенджером.
    static func memo(_ needs: [Need], leave: Date, back: Date,
                     calendar: Calendar = .current) -> String {
        let style = Date.FormatStyle.dateTime.day().month(.wide)
            .locale(Lang.locale)
        var lines = [Lang.format("Привет! Меня не будет с %1$@ по %2$@.",
                                 leave.formatted(style), back.formatted(style))]
        guard !needs.isEmpty else {
            lines.append(Lang.text("Растения дождутся меня сами — поливать никого не нужно. Спасибо!"))
            return lines.joined(separator: "\n")
        }
        lines.append(Lang.text("Пожалуйста, полей растения:"))
        for need in needs {
            let dates = need.visits.compactMap {
                calendar.date(byAdding: .day, value: $0, to: leave)?
                    .formatted(style)
            }
            lines.append(Lang.format("• %1$@ (%2$@, «%3$@») — %4$@",
                                     need.plant.name, need.plant.species,
                                     need.room,
                                     dates.joined(separator: ", ")))
        }
        lines.append(Lang.text("Полить — до мокрой земли, но чтобы вода не стояла в поддоне. Остальные растения дождутся меня сами. Спасибо!"))
        return lines.joined(separator: "\n")
    }
}
