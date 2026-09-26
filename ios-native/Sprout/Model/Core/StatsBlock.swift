import Foundation

/// Блоки статистики — те, что хозяин переставляет и убирает через
/// «Выбрать». Период сверху не блок: без него остальное не читается.
enum StatsBlock: String, CaseIterable, Codable, Identifiable, Sendable {
    case now, recap, orrery, summary, waterings, aim, habits, calendar,
         records, forecast, rooms, plants

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: Lang.text("Сейчас")
        case .recap: Lang.text("Итоги года")
        case .orrery: Lang.text("Планетарий")
        case .summary: Lang.text("Итог")
        case .waterings: Lang.text("Поливы")
        case .aim: Lang.text("Точность полива")
        case .habits: Lang.text("Привычки")
        case .calendar: Lang.text("Календарь поливов")
        case .records: Lang.text("Рекорды")
        case .forecast: Lang.text("Прогноз")
        case .rooms: Lang.text("Комнаты")
        case .plants: Lang.text("Растения")
        }
    }

    var icon: String {
        switch self {
        case .now: "leaf"
        case .recap: "sparkles.rectangle.stack"
        case .orrery: "circle.dotted.circle"
        case .summary: "sum"
        case .waterings: "chart.bar"
        case .aim: "scope"
        case .habits: "clock"
        case .calendar: "calendar"
        case .records: "trophy"
        case .forecast: "chart.line.uptrend.xyaxis"
        case .rooms: "door.left.hand.open"
        case .plants: "list.number"
        }
    }

    /// Порядок из сохранённого: незнакомое выбрасывается, новые блоки
    /// следующих сборок встают в конец, повторы — один раз.
    static func order(_ saved: [StatsBlock]) -> [StatsBlock] {
        var out: [StatsBlock] = []
        for block in saved where !out.contains(block) { out.append(block) }
        return out + allCases.filter { !out.contains($0) }
    }

    /// Поставить `block` перед `target`: перетащили и бросили на него.
    static func move(_ block: StatsBlock, before target: StatsBlock,
                     in order: [StatsBlock]) -> [StatsBlock] {
        guard block != target else { return order }
        var out = order.filter { $0 != block }
        let at = out.firstIndex(of: target) ?? out.count
        // Тащили сверху вниз — встаёт после цели, как в списках iOS.
        let from = order.firstIndex(of: block) ?? 0
        let to = order.firstIndex(of: target) ?? 0
        out.insert(block, at: from < to ? min(at + 1, out.count) : at)
        return out
    }
}
