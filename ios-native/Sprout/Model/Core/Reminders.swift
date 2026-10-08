import Foundation

/// Напоминание о поливе: кого и когда будить. Одна арифметика, без
/// `UserNotifications`, — чтобы проверять её где угодно.
enum Reminder {
    struct Due {
        var plant: Plant
        var others: Int
        var after: TimeInterval
        /// Кого польёт кнопка «Полил» в уведомлении: всех, кому к этому
        /// мигу станет сухо.
        var ids: [Plant.ID] = []
    }

    /// Подкормка, пересадка или мелкий уход — отдельным уведомлением: у
    /// полива своя кнопка, а у ухода её нет.
    struct Chore {
        enum Kind: Equatable {
            case feed, repot
            case duty(Duty)
        }

        var plant: Plant
        var kind: Kind
        var after: TimeInterval

        var repot: Bool { kind == .repot }
    }

    /// Раньше уведомление бессмысленно: сухие растения набираются за минуты,
    /// и оно прилетало бы, пока экран ещё не погас.
    static let soonest: TimeInterval = 15

    /// Через сколько секунд растение попадёт в «полить сегодня»
    /// (`MoistureStatus.due`); уже там — ноль, пусто — никогда. Порог у
    /// каждого свой: сухо (меньше 20 %) — или срок дошёл до нуля дней, у
    /// растений с коротким сроком это раньше.
    ///
    /// Время сада — настоящее (`Garden.speed`), и напоминание приходит в тот
    /// день, когда карточка говорит «Полить сегодня».
    static func delay(for plant: Plant) -> TimeInterval? {
        guard plant.dryingDays > 0, plant.period > 0 else { return nil }
        guard !plant.needsWaterToday else { return 0 }
        // С датчика влажность сама не падает: срок скажет новое показание.
        guard plant.estimated else { return nil }
        // Ноль дней — когда влажность × срок меньше половины дня.
        let edge = max(MoistureStatus.urgentBelow, 0.5 / plant.period)
        let days = max(0, plant.moisture - edge) * plant.period
        return days * 86_400 / Garden.speed
    }

    /// Одно на всю квартиру, а не по штуке на растение, — но с числом
    /// соседей, которые к тому же мигу попадут в «полить сегодня». Те, кому
    /// полить уже сегодня, — это ровно `MoistureStatus.needsWater`.
    static func next(in rooms: [Room]) -> Due? {
        let plants = rooms.flatMap(\.plants)
        var soonest: (plant: Plant, delay: TimeInterval)?
        for plant in plants {
            guard let delay = delay(for: plant) else { continue }
            if soonest == nil || delay < soonest!.delay
                || (delay == soonest!.delay
                    && plant.moisture < soonest!.plant.moisture) {
                soonest = (plant, delay)
            }
        }
        guard let soonest else { return nil }
        let together = plants.filter {
            guard let delay = delay(for: $0) else { return false }
            return delay <= soonest.delay
        }
        .sorted { $0.moisture < $1.moisture }
        return Due(plant: soonest.plant, others: together.count - 1,
                   after: max(soonest.delay, Self.soonest),
                   ids: together.map(\.id))
    }

    static var title: String { Lang.text("Пора поливать") }

    static func text(for due: Due) -> String {
        guard due.others > 0 else {
            return Lang.format("«%@» просит воды", due.plant.name)
        }
        return Lang.format("«%1$@» и ещё %2$@ просят воды", due.plant.name,
                           Lang.format("%lld растений", due.others))
    }

    /// Ближайший уход по всей квартире. Подкормка — только в пору роста:
    /// зимой её счёт стоит.
    static func chore(in rooms: [Room]) -> Chore? {
        var best: (plant: Plant, kind: Chore.Kind, days: Double)?
        for plant in rooms.flatMap(\.plants) {
            let tending = plant.tending
            var options: [(Chore.Kind, Double)] = []
            if Season.growing, let left = tending.feedIn {
                options.append((.feed, left))
            }
            if let left = tending.repotIn { options.append((.repot, left)) }
            for duty in Duty.allCases {
                if let left = tending.left(duty) {
                    options.append((.duty(duty), left))
                }
            }
            for (kind, days) in options where best == nil || days < best!.days {
                best = (plant, kind, days)
            }
        }
        guard let best else { return nil }
        return Chore(plant: best.plant, kind: best.kind,
                     after: max(best.days * 86_400 / Garden.speed, soonest))
    }

    /// Шаг плана лечения — своим уведомлением: ближайший несделанный, чей
    /// срок ещё впереди. Прошедший уже был на экране растения и в прошлом
    /// напоминании; вылеченное больше не зовёт.
    struct Remedy {
        var plant: Plant
        var step: Treatment.Step
        var after: TimeInterval
    }

    static func remedy(in rooms: [Room], now: Date = Date()) -> Remedy? {
        var best: Remedy?
        for plant in rooms.flatMap(\.plants) {
            guard let plan = plant.treatment, plan.active else { continue }
            for step in plan.steps where step.done == nil && step.due > now {
                let after = step.due.timeIntervalSince(now)
                if best == nil || after < best!.after {
                    best = Remedy(plant: plant, step: step, after: after)
                }
            }
        }
        guard var best else { return nil }
        best.after = max(best.after, soonest)
        return best
    }

    static func title(for remedy: Remedy) -> String {
        Lang.format("Лечение: «%@»", remedy.plant.name)
    }

    static func text(for remedy: Remedy) -> String {
        guard let count = remedy.step.count else { return remedy.step.title }
        return remedy.step.title + " · " + count
    }

    static func title(for chore: Chore) -> String {
        switch chore.kind {
        case .feed: Lang.text("Пора подкормить")
        case .repot: Lang.text("Пора пересадить")
        case .duty(let duty): duty.now
        }
    }

    static func text(for chore: Chore) -> String {
        switch chore.kind {
        case .feed: Lang.format("«%@» ждёт подкормки", chore.plant.name)
        case .repot:
            Lang.format("«%@» просится в горшок побольше", chore.plant.name)
        case .duty(let duty): duty.nudge(chore.plant.name)
        }
    }
}
