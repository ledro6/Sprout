import Foundation

/// Открытка для друзей — картинкой: растение или вся оранжерея. Здесь
/// только то, что считается: сколько дней в саду и какую серию показать.
/// Рисует `PlantPoster`.
enum Postcard {
    /// Сторона картинки — 4:5, как пост в ленте: 360 × 450 точек втрое —
    /// 1080 × 1350.
    static let width: Double = 360
    static let height: Double = 450
    static let scale: Double = 3

    /// Полных дней по календарю, а не делением секунд: сутки бывают в 23 и
    /// 25 часов. Дата в будущем — ноль.
    static func days(from start: Date, to now: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    /// Растение в саду — с дня, когда его добавили. Без даты — ноль.
    static func days(since added: DateComponents, to now: Date,
                     calendar: Calendar) -> Int {
        guard added.year != nil, let start = calendar.date(from: added)
        else { return 0 }
        return days(from: start, to: now, calendar: calendar)
    }

    /// «Первый день», дальше «12 дней».
    static func age(_ days: Int) -> String {
        days < 1 ? Lang.text("Первый день") : Lang.format("%lld дней", days)
    }

    /// Серия — от двух дней: один день подряд — ещё не серия, и хвастаться
    /// им на открытке странно.
    static func streak(_ value: Int) -> Int? { value >= 2 ? value : nil }
}
