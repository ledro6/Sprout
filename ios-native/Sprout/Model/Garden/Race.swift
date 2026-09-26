import Foundation

/// Общий челлендж на неделю: кто больше польёт вовремя, кто больше дней
/// польёт, кто больше польёт до десяти утра. Сервера нет: челлендж уходит
/// кодом в переписке, а счёт каждый присылает своим кодом соперника — в
/// нём едет и счёт челленджа, см. `Rival.race`.
struct Race: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var quest: Quest
    /// Первый день — сутки от 1970 года, как у кода соперника.
    var start: Int
    var days: Int
    /// Кто позвал.
    var host: String

    /// Счёт одного участника.
    struct Score: Codable, Hashable, Sendable {
        var id: String
        var count: Int

        enum CodingKeys: String, CodingKey {
            case id = "i", count = "c"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "i", quest = "q", start = "s", days = "n", host = "h"
    }

    static let mark = "SPROUTR1."

    /// Какие задания годятся в челлендж: их счёт растёт, а не срывается.
    static let kinds: [Quest] = [.onTime, .days, .morning]

    /// Закончившийся ещё неделю висит в профиле — с итогом.
    static let afterglow: TimeInterval = 7 * 86_400

    /// С завтрашнего дня, неделю: сегодня друзья ещё не успели вставить код.
    static func new(_ quest: Quest, host: String, on moment: Date = Date(),
                    id: String = UUID().uuidString) -> Race {
        Race(id: String(id.filter(\.isLetter).prefix(6)).lowercased(),
             quest: quest, start: Rival.day(of: moment) + 1, days: 7,
             host: host)
    }

    /// По местным суткам: день из кода — это число в календаре, а
    /// полночь у каждого своя.
    func span(calendar: Calendar = .current) -> DateInterval {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .current
        let parts = utc.dateComponents(
            [.year, .month, .day],
            from: Date(timeIntervalSince1970: Double(start) * 86_400))
        let begin = calendar.date(from: parts)
            ?? Date(timeIntervalSince1970: Double(start) * 86_400)
        let end = calendar.date(byAdding: .day, value: days, to: begin)
            ?? begin.addingTimeInterval(Double(days) * 86_400)
        return DateInterval(start: begin, end: end)
    }

    /// Свой счёт — по журналу, как у задания недели.
    func count(_ log: [Watering], calendar: Calendar = .current) -> Int {
        let span = span(calendar: calendar)
        let entries = log.filter { $0.when >= span.start && $0.when < span.end }
        return Week.challenge(quest, need: 1, entries: entries,
                              calendar: calendar).count
    }

    func score(_ log: [Watering], calendar: Calendar = .current) -> Score {
        Score(id: id, count: count(log, calendar: calendar))
    }

    /// «Кто больше польёт вовремя».
    var title: String { Self.title(quest) }

    static func title(_ quest: Quest) -> String {
        switch quest {
        case .days: Lang.text("Кто больше дней польёт")
        case .morning: Lang.text("Кто больше польёт до десяти утра")
        default: Lang.text("Кто больше польёт вовремя")
        }
    }

    var code: String { Codeword.encode(self, mark: Self.mark) }

    /// Сперва человеческая часть, потом код.
    func card(calendar: Calendar = .current) -> String {
        let span = span(calendar: calendar)
        let dates = span.start.formatted(.dateTime.day().month(.wide))
            + " – " + span.end.addingTimeInterval(-1)
                .formatted(.dateTime.day().month(.wide))
        let head = Lang.format("%1$@ зовёт в челлендж Sprout: «%2$@», %3$@.",
                               host, title, dates)
        let invite = Lang.text("Чтобы участвовать, скопируйте это сообщение целиком и нажмите «Вставить» в Sprout → Профиль → Друзья. Счёт присылайте своим кодом — кнопкой «Позвать».")
        return head + "\n" + invite + "\n" + code
    }

    static func read(_ text: String) -> Race? {
        Codeword.decode(Race.self, mark: mark, in: text) {
            !$0.id.isEmpty && $0.days > 0 && $0.days <= 31
                && kinds.contains($0.quest)
        }
    }
}
