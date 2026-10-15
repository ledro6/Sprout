import Foundation

/// Откуда взята влажность и что с ней делать — строка под статусом, и
/// обратная связь от почвы: два ответа «Как земля была?» подряд — повод
/// поменять срок. Предложение только предлагает: меняет срок кнопка.
enum SoilNote {
    /// Одна строка о том, откуда влажность: датчик, расчёт или «ещё влажно».
    static func reason(for plant: Plant, log: [Watering],
                       now: Date = Date()) -> String {
        if case .warn = plant.wateringGuard {
            return Lang.format("Земля ещё влажная (%@): проверим через %lld дн",
                               plant.moistureLabel, plant.daysUntilWatering)
        }
        if !plant.estimated, let reading = plant.sensor?.last {
            return Lang.format("По датчику %@, обновлено %@",
                               plant.moistureLabel,
                               ago(reading.when, now: now))
        }
        guard let last = log.filter({ $0.plant == plant.id }).map(\.when).max()
        else {
            return Lang.format("По расчёту: вид «%@»", plant.species)
        }
        let days = Int(max(0, now.timeIntervalSince(last)) / 86_400)
        return Lang.format("По расчёту: последний полив %lld дн назад, вид «%@»",
                           days, plant.species)
    }

    /// Ответы «Как земля была?» этого растения по порядку.
    static func answered(for plant: Plant, log: [Watering]) -> [Watering] {
        log.filter { $0.plant == plant.id && $0.soil != nil }
            .sorted { $0.when < $1.when }
    }

    /// Срок, который стоит предложить: два последних ответа одинаковые —
    /// оба «влажно» дают N+1, оба «сухо» дают N−1 (не меньше дня). Пусто у
    /// растений с датчиком и при любом другом ответе.
    static func suggest(for plant: Plant, log: [Watering]) -> Double? {
        guard plant.sensor == nil else { return nil }
        let recent = answered(for: plant, log: log).suffix(2).compactMap(\.soil)
        guard recent.count == 2, recent[0] == recent[1] else { return nil }
        let current = max(1, plant.dryingDays.rounded())
        switch recent[0] {
        case .wet: return current + 1
        case .dry: return current > 1 ? current - 1 : nil
        case .fine: return nil
        }
    }

    /// Когда видели показание датчика: «только что», «N мин назад», «N ч
    /// назад», «вчера» или дата.
    private static func ago(_ date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return Lang.text("только что") }
        if seconds < 3_600 {
            return Lang.format("%lld мин назад", Int(seconds / 60))
        }
        if seconds < 86_400 {
            return Lang.format("%lld ч назад", Int(seconds / 3_600))
        }
        let calendar = Calendar.current
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return Lang.text("вчера")
        }
        return date.formatted(Date.FormatStyle(date: .numeric, time: .omitted)
            .locale(Lang.locale))
    }
}
