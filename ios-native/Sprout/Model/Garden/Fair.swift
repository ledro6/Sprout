import Foundation

/// Честные правила серии, заданий недели и опыта: приложение не награждает
/// за лишний полив. Серия — хорошие дни подряд, а не дни с поливом;
/// задания и опыт считают только нужные поливы — в окне «скоро пить» и
/// «сухо». За флагом (`enabled`): выключить — вернутся прежние правила
/// целиком.
///
/// Новые правила — с даты, когда сборка с ними впервые запустилась
/// (`since`): накопленные серии, задания и опыт не пересчитываются
/// задним числом, дни и поливы до неё считаются по-прежнему.
enum Fair {
    /// Флаг. `false` — прежние правила везде.
    static let enabled = true

    /// С какого мига новые правила. Ставит приложение при запуске
    /// (`start`); пусто — правил ещё нет (виджет, прогон модели).
    nonisolated(unsafe) static var since: Date?

    /// Действующая дата правил — пусто, если флаг выключен.
    static var from: Date? { enabled ? since : nil }

    private static let key = "fairSince"

    /// Дата первого запуска с правилами — запоминается один раз.
    static func start(store: UserDefaults = .standard,
                      now: Date = Date()) -> Date {
        let saved = store.double(forKey: key)
        if saved > 0 { return Date(timeIntervalSince1970: saved) }
        store.set(now.timeIntervalSince1970, forKey: key)
        return now
    }

    /// Нужный полив: земля была в «скоро пить» или «сухо». Без доли воды
    /// (журналы прежних сборок) — нужный: судить нечем.
    static func needed(_ entry: Watering) -> Bool {
        entry.counts
            && (entry.left.map { $0 < MoistureStatus.soonBelow } ?? true)
    }

    /// Идёт ли полив в задания и опыт: до даты правил — любой не лишний,
    /// после — только нужный.
    static func credits(_ entry: Watering, from: Date?) -> Bool {
        guard let from, entry.when >= from else { return entry.counts }
        return needed(entry)
    }

    // MARK: - Хороший день

    /// День по новым правилам.
    enum Verdict: Equatable, Sendable {
        /// Ни одно растение не осталось сухим.
        case good
        /// Растение, которому в начале дня пора было пить, так и не
        /// полили.
        case bad
        /// Сегодня, и кто-то ещё ждёт полива: день не кончился.
        case pending
        /// В саду ещё не было растений.
        case empty
    }

    /// Журнал по растениям, от старого к новому.
    static func pours(_ log: [Watering]) -> [Plant.ID: [Watering]] {
        var pours: [Plant.ID: [Watering]] = [:]
        for entry in log.sorted(by: { $0.when < $1.when }) {
            pours[entry.plant, default: []].append(entry)
        }
        return pours
    }

    /// Влажность растения в миг `moment` по журналу — расчётом: от
    /// последнего полива до него; полива раньше нет — назад от следующего
    /// (его доли воды), а нет и его — назад от нынешней влажности.
    static func moisture(of plant: Plant, at moment: Date, pours: [Watering],
                         now: Date) -> Double {
        let perSecond = Garden.speed / 86_400 / max(plant.period, 0.01)
        func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
        if let last = pours.last(where: { $0.when <= moment }) {
            return clamp(1 - moment.timeIntervalSince(last.when) * perSecond)
        }
        if let next = pours.first(where: { $0.when > moment }) {
            guard let left = next.left else { return 1 }
            return clamp(left + next.when.timeIntervalSince(moment) * perSecond)
        }
        return clamp(plant.moisture + now.timeIntervalSince(moment) * perSecond)
    }

    /// Хороший ли день `day` (полночь): в саду нет растения, которому в
    /// начале дня пора было пить (`MoistureStatus.due` — «сухо» или срок
    /// вышел), а его так и не полили до конца дня. Растение, высохшее к
    /// вечеру, день не портит — его польют завтра. Архивных в `rooms` нет.
    static func verdict(_ day: Date, rooms: [Room], pours: [Plant.ID: [Watering]],
                        now: Date, calendar: Calendar) -> Verdict {
        let end = calendar.date(byAdding: .day, value: 1, to: day)
            ?? day.addingTimeInterval(86_400)
        let today = now < end
        var any = false
        var waiting = false
        for plant in rooms.flatMap(\.plants) {
            if let added = calendar.date(from: plant.addedOn),
               calendar.startOfDay(for: added) > day { continue }
            any = true
            let mine = pours[plant.id] ?? []
            let start = moisture(of: plant, at: day, pours: mine, now: now)
            guard MoistureStatus.due(moisture: start, period: plant.period)
            else { continue }
            let watered = mine.contains { $0.when >= day && $0.when < end }
            guard !watered else { continue }
            if today { waiting = true } else { return .bad }
        }
        if !any { return .empty }
        return waiting ? .pending : .good
    }

    // MARK: - Серия

    /// Серия, рекорд и когда серия впервые дошла до каждой длины.
    struct Run: Equatable, Sendable {
        var streak = 0
        var best = 0
        /// Вчера серия прервалась: «Серия прервалась. Бывает — начнём
        /// заново».
        var broke = false
        var firsts: [Int: Date] = [:]
    }

    /// «Заморозка»: один плохой день за семь серию не обнуляет.
    static let freeze = 7

    /// Дни до даты правил — по-прежнему: день с поливом (не лишним);
    /// с даты — хорошие дни (`verdict`) с заморозкой. Сегодня в серию
    /// идёт, когда уже хороший, и не рвёт её, пока не кончился.
    static func run(_ log: [Watering], rooms: [Room], from: Date,
                    now: Date, calendar: Calendar) -> Run {
        // Влажность восстанавливается по всем поливам, и лишним тоже: вода
        // в землю попала. В серию по прежним правилам лишние не идут.
        let pours = Self.pours(log)
        let watered = Set(log.filter(\.counts).map {
            calendar.startOfDay(for: $0.when)
        })
        let rule = calendar.startOfDay(for: from)
        let today = calendar.startOfDay(for: now)
        var day = min(watered.min() ?? rule, rule)
        var out = Run()
        var frozen: Date?
        var lastBad = false
        while day <= today {
            let verdict: Verdict
            if day < rule {
                verdict = watered.contains(day) ? .good
                    : (day == today ? .pending : .bad)
            } else {
                verdict = Self.verdict(day, rooms: rooms, pours: pours,
                                       now: now, calendar: calendar)
            }
            switch verdict {
            case .good:
                out.streak += 1
                out.best = max(out.best, out.streak)
                if out.firsts[out.streak] == nil {
                    out.firsts[out.streak] = day
                }
                lastBad = false
            case .bad:
                let thaw = frozen.map {
                    (calendar.dateComponents([.day], from: $0, to: day).day
                        ?? 0) >= freeze
                } ?? true
                if day >= rule, out.streak > 0, thaw {
                    frozen = day
                    lastBad = false
                } else {
                    lastBad = out.streak > 0 || lastBad
                    out.streak = 0
                    frozen = nil
                }
            case .pending, .empty:
                break
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day)
            else { break }
            day = next
        }
        out.broke = lastBad && out.streak == 0 && out.best > 0
        return out
    }
}
