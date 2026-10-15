import Foundation

/// Редкие события неба. Каждое показывается один раз — строкой в «Небе
/// сада» и тихой картинкой, потом остаётся в «Небесном журнале».
///
/// Ни одно не награждает за лишний полив. Северное сияние требует недели
/// без пересохших и без единого раннего полива; метеорный дождь — только
/// если все политые в тот день политы не раньше срока; комета — просто
/// новое растение, поливом её не вызвать.
///
/// «Спутники» (черенки вокруг родителя) не сделаны: у `Cutting` нет
/// ссылки на родительское растение — это код для друга, а у посаженного
/// растения о родителе ничего не хранится.
enum Rare {
    enum Kind: String, Codable, Sendable {
        /// Неделя без единого сухого растения.
        case aurora
        /// Растение добавлено за последние три дня.
        case comet
        /// День парада, когда все политые политы вовремя.
        case meteor
    }

    struct Event: Codable, Hashable, Sendable {
        var kind: Kind
        /// Одно событие — один ключ: «comet:<растение>», «meteor:<день>».
        var key: String
        var when: Date
        /// Кличка растения для кометы; для метеорного дождя — число
        /// политых, строкой.
        var subject: String = ""
        /// Показано в «Небе сада» (и больше туда не вернётся).
        var shown = false
    }

    static let auroraDays = 7
    static let cometDays = 3
    /// Парад — столько растений в один день и больше, как `Orrery.parades`.
    static let meteorLeast = 3

    private static func added(_ plant: Plant, _ calendar: Calendar) -> Date? {
        calendar.date(from: plant.addedOn)
    }

    /// Северное сияние: в саду есть растения старше недели, ни одно
    /// сейчас не «сухо», за неделю ни один полив не был «впритык» (тогда
    /// растение успело пересохнуть) или «рано» (тогда сияние было бы
    /// наградой за лишний полив).
    static func aurora(_ plants: [Plant], log: [Watering], now: Date,
                       calendar: Calendar = .current) -> Bool {
        let start = now.addingTimeInterval(-Double(auroraDays) * 86_400)
        let dates = plants.compactMap { added($0, calendar) }
        guard let oldest = dates.min(), oldest <= start else { return false }
        guard plants.allSatisfy({ $0.moisture >= MoistureStatus.urgentBelow })
        else { return false }
        return !log.contains { entry in
            guard entry.when >= start, entry.when <= now else { return false }
            return Precision.hit(entry) != .bullseye && !isUnknown(entry)
        }
    }

    /// Полив без доли воды (журнал прежней сборки) сияние не портит, но и
    /// не помогает: судить нечем.
    private static func isUnknown(_ entry: Watering) -> Bool {
        entry.counts && entry.left == nil
    }

    /// Новые растения: добавлены не раньше трёх дней назад.
    static func comets(_ plants: [Plant], now: Date,
                       calendar: Calendar = .current) -> [Plant] {
        let today = calendar.startOfDay(for: now)
        return plants.filter { plant in
            guard let born = added(plant, calendar) else { return false }
            let days = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: born), to: today).day
                ?? Int.max
            return days >= 0 && days < cometDays
        }
    }

    /// Метеорные дожди за вчера и позавчера: в день растений-«парада»
    /// (три и больше политых) каждый полив — вовремя (в яблочко или
    /// впритык), без ранних, лишних и без доли воды. Сегодня не считаем:
    /// день ещё не кончился. Ключ — день, значение — сколько политых.
    static func meteors(_ log: [Watering], now: Date,
                        calendar: Calendar = .current) -> [String: Int] {
        var out: [String: Int] = [:]
        let today = calendar.startOfDay(for: now)
        for back in 1 ... 2 {
            guard let day = calendar.date(byAdding: .day, value: -back,
                                          to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: day)
            else { continue }
            let pours = log.filter { $0.when >= day && $0.when < end }
            let hits = pours.map { Precision.hit($0) }
            let plants = Set(pours.map(\.plant))
            guard plants.count >= meteorLeast,
                  hits.allSatisfy({ $0 == .bullseye || $0 == .tight })
            else { continue }
            out[Observatory.dayKey(day, calendar: calendar)] = plants.count
        }
        return out
    }

    /// Всё, что небо готово показать сейчас, кроме уже бывшего. `old` —
    /// события из книги: ключи не повторяются, сияние ждёт новой недели.
    static func detect(plants: [Plant], log: [Watering], old: [Event],
                       now: Date, calendar: Calendar = .current) -> [Event] {
        var found: [Event] = []
        let known = Set(old.map(\.key))
        let weekAgo = now.addingTimeInterval(-Double(auroraDays) * 86_400)
        let lately = old.contains { $0.kind == .aurora && $0.when > weekAgo }
        if !lately, aurora(plants, log: log, now: now, calendar: calendar) {
            found.append(Event(kind: .aurora,
                               key: "aurora:" + Observatory.dayKey(
                                   now, calendar: calendar),
                               when: now))
        }
        for plant in comets(plants, now: now, calendar: calendar) {
            let key = "comet:" + plant.id
            if !known.contains(key) {
                found.append(Event(kind: .comet, key: key, when: now,
                                   subject: plant.name))
            }
        }
        for (day, count) in meteors(log, now: now, calendar: calendar)
            .sorted(by: { $0.key < $1.key }) {
            let key = "meteor:" + day
            if !known.contains(key) {
                found.append(Event(kind: .meteor, key: key, when: now,
                                   subject: String(count)))
            }
        }
        return found
    }
}
