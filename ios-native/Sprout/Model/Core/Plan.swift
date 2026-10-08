import Foundation

/// Распорядок уведомлений: что, когда и сколько. Чистая арифметика, без
/// `UserNotifications`, — чтобы проверять её где угодно (тесты на саде из 18
/// растений). Правила:
///
/// - полив — одно утреннее на сад в заданное время («Полить сегодня: …»);
/// - остальной уход — не чаще одного сводного в неделю, и только то, что
///   рекомендует вид (`Plant.tending`: нет срока — нет напоминания);
/// - шаг лечения — своим уведомлением, если есть место;
/// - всего не больше двух пушей в день (дача, приходящая по геозоне, —
///   один из двух, см. `Rules.reserve`);
/// - тихие часы: ничего ночью, время сдвигается на их конец;
/// - чем дольше сад не открывают, тем реже: ставятся не все дни подряд, а
///   всё реже, и без упрёков в тексте.
enum Plan {
    /// «Напоминания включены» сами — после первого растения (T-26): флаг.
    /// Выключить — вопрос после посадки не задаётся, умолчание «выключены».
    static let askAfterFirstPlant = true

    /// Пушей в день, всего.
    static let perDay = 2

    /// Через сколько дней от сегодняшнего вперёд ставится утреннее: три дня
    /// подряд, дальше — всё реже, по мере того как сад не открывают.
    static let reach = [0, 1, 2, 3, 5, 8, 14]

    struct Rules: Equatable, Sendable {
        /// Минут от полуночи.
        var morning = 9 * 60
        var quietFrom = 22 * 60
        var quietTo = 8 * 60
        /// Сколько пушей в день занято приездом на дачу (ноль или один).
        var reserve = 0
        /// Сводка по уходу — в этот день недели (1 — воскресенье) и час.
        var weekday = 1
        var evening = 18 * 60
    }

    struct Slot: Equatable, Sendable {
        enum Kind: Equatable, Sendable { case morning, weekly, step }

        var kind: Kind
        var at: Date
        var title: String
        var body: String
        /// Кого польёт «Полил всех».
        var ids: [Plant.ID] = []
    }

    // MARK: - Тихие часы

    static func quiet(_ minute: Int, _ rules: Rules) -> Bool {
        if rules.quietFrom == rules.quietTo { return false }
        if rules.quietFrom < rules.quietTo {
            return minute >= rules.quietFrom && minute < rules.quietTo
        }
        return minute >= rules.quietFrom || minute < rules.quietTo
    }

    /// Момент, сдвинутый из тихих часов на их конец.
    static func outside(_ date: Date, _ rules: Rules,
                        _ calendar: Calendar) -> Date {
        let minute = minutes(of: date, calendar)
        guard quiet(minute, rules) else { return date }
        let tomorrow = rules.quietFrom > rules.quietTo
            && minute >= rules.quietFrom
        return moment(calendar.startOfDay(for: date), days: tomorrow ? 1 : 0,
                      minutes: rules.quietTo, calendar)
    }

    static func moment(_ start: Date, days: Int, minutes: Int,
                       _ calendar: Calendar) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: start)
            ?? start.addingTimeInterval(Double(days) * 86_400)
        return calendar.date(byAdding: .minute, value: minutes, to: day)
            ?? day.addingTimeInterval(Double(minutes) * 60)
    }

    static func minutes(of date: Date, _ calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
    }

    // MARK: - Тексты

    /// «Полить сегодня: Фикус, Монстера (+3)».
    static func morningText(_ plants: [Plant]) -> String {
        let names = plants.prefix(2).map(\.name).joined(separator: ", ")
        let more = plants.count - 2
        return Lang.format("Полить сегодня: %@",
                           more > 0 ? names + " (+\(more))" : names)
    }

    /// Сводка по уходу: «Подкормка: 3 · Пересадка: 1».
    static func weeklyText(_ counts: [(String, Int)]) -> String {
        counts.map { Lang.format("%1$@: %2$lld", $0.0, $0.1) }
            .joined(separator: " · ")
    }

    /// Сколько растений ждут каждого ухода в ближайшие `span` секунд.
    /// Подкормка — только в пору роста (зимой удобрение жжёт корни); у вида
    /// нет срока — нет и счёта.
    static func errands(_ plants: [Plant], within span: TimeInterval)
        -> [(String, Int)] {
        var feed = 0
        var repot = 0
        var duties: [Duty: Int] = [:]
        for plant in plants {
            let care = plant.tending
            if Season.growing, let left = care.feedIn,
               Agenda.real(left) <= span {
                feed += 1
            }
            if let left = care.repotIn, Agenda.real(left) <= span {
                repot += 1
            }
            for duty in Duty.allCases {
                if let left = care.left(duty), Agenda.real(left) <= span {
                    duties[duty, default: 0] += 1
                }
            }
        }
        var all: [(String, Int)] = []
        if feed > 0 { all.append((Lang.text("Подкормка"), feed)) }
        if repot > 0 { all.append((Lang.text("Пересадка"), repot)) }
        for duty in Duty.allCases {
            if let count = duties[duty] { all.append((duty.title, count)) }
        }
        return all
    }

    // MARK: - Расписание

    /// Что поставить, начиная с `now`; `notBefore` — не раньше (отложили на
    /// завтра). Слоты по возрастанию времени.
    static func slots(in rooms: [Room], now: Date, rules: Rules = Rules(),
                      notBefore: Date? = nil,
                      calendar: Calendar = .current) -> [Slot] {
        let plants = rooms.flatMap(\.plants)
        let earliest = max(now.addingTimeInterval(Reminder.soonest),
                           notBefore ?? .distantPast)
        let today = calendar.startOfDay(for: now)
        let room = max(perDay - rules.reserve, 0)
        var used: [Date: Int] = [:]
        var slots: [Slot] = []

        func fits(_ date: Date) -> Bool {
            used[calendar.startOfDay(for: date), default: 0] < room
        }
        func take(_ slot: Slot) {
            used[calendar.startOfDay(for: slot.at), default: 0] += 1
            slots.append(slot)
        }
        /// Не влезло в день — на следующий, до двух раз; дальше решит
        /// пересчёт при следующем уходе из приложения.
        func place(_ slot: Slot, minutes: Int) {
            var slot = slot
            for shift in 0 ... 2 {
                let day = moment(calendar.startOfDay(for: slot.at),
                                 days: shift, minutes: minutes, calendar)
                let at = outside(day, rules, calendar)
                if at >= earliest, fits(at) {
                    slot.at = at
                    take(slot)
                    return
                }
            }
        }

        // 1. Полив — первым: ему место гарантировано.
        var thirsty: [(plant: Plant, wait: TimeInterval)] = []
        for plant in plants {
            if let wait = Reminder.delay(for: plant) {
                thirsty.append((plant, wait))
            }
        }
        for offset in reach {
            let at = outside(moment(today, days: offset,
                                    minutes: rules.morning, calendar),
                             rules, calendar)
            guard at >= earliest, fits(at) else { continue }
            let span = at.timeIntervalSince(now)
            let due = thirsty.filter { $0.wait <= span }.map(\.plant)
                .sorted { $0.moisture < $1.moisture }
            guard !due.isEmpty else { continue }
            take(Slot(kind: .morning, at: at, title: "",
                      body: morningText(due), ids: due.map(\.id)))
        }

        // 2. Шаг лечения — ближайший.
        if let remedy = Reminder.remedy(in: rooms, now: now) {
            let at = now.addingTimeInterval(remedy.after)
            place(Slot(kind: .step, at: at,
                       title: Reminder.title(for: remedy),
                       body: Reminder.text(for: remedy)),
                  minutes: minutes(of: at, calendar))
        }

        // 3. Сводка по уходу — одна, в заданный день недели.
        for offset in 0 ..< 15 {
            let day = moment(today, days: offset, minutes: 0, calendar)
            guard calendar.component(.weekday, from: day) == rules.weekday
            else { continue }
            let at = moment(today, days: offset, minutes: rules.evening,
                            calendar)
            guard at >= earliest else { continue }
            let counts = errands(plants, within: at.timeIntervalSince(now)
                                 + 7 * 86_400)
            if !counts.isEmpty {
                place(Slot(kind: .weekly, at: at,
                           title: Lang.text("Уход на этой неделе"),
                           body: weeklyText(counts)),
                      minutes: rules.evening)
            }
            break
        }
        return slots.sorted { $0.at < $1.at }
    }
}
