import Foundation

/// План лечения после «Что с ним?»: шаги — советы находок (`Finding`),
/// ничего сверх них; совет, который повторяют, — несколько шагов со своими
/// сроками. Составляет его `Treatment.plan` рядом с находками; здесь —
/// только то, что нужно саду, виджету и общему саду: шаги, сроки, отметки.
///
/// Сроки — настоящие даты, а считаются в днях сада, как подкормка: «через
/// 3 дня» на экране — те же три дня, что у полива. Лежит в растении и
/// уходит в общий сад вместе с уходом — по отметке `Plant.tended`.
struct Treatment: Codable, Hashable, Sendable {
    struct Step: Codable, Hashable, Identifiable, Sendable {
        var id: String
        /// Совет — ключ каталога строк, как его пишет находка: на экране он
        /// на языке приложения, даже если план составлен до смены языка.
        var advice: String
        var icon: String
        /// Который раз из скольких — у совета, который повторяют.
        var round = 1
        var rounds = 1
        var due: Date
        var done: Date?

        init(id: String, advice: String, icon: String, round: Int = 1,
             rounds: Int = 1, due: Date, done: Date? = nil) {
            self.id = id
            self.advice = advice
            self.icon = icon
            self.round = round
            self.rounds = rounds
            self.due = due
            self.done = done
        }

        /// Чего нет в файле — по умолчанию: план мог записать телефон
        /// другой сборки.
        init(from decoder: any Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            id = try box.decode(String.self, forKey: .id)
            advice = try box.decodeIfPresent(String.self, forKey: .advice) ?? ""
            icon = try box.decodeIfPresent(String.self, forKey: .icon)
                ?? "cross.case.fill"
            round = try box.decodeIfPresent(Int.self, forKey: .round) ?? 1
            rounds = try box.decodeIfPresent(Int.self, forKey: .rounds) ?? 1
            due = try box.decodeIfPresent(Date.self, forKey: .due)
                ?? .distantPast
            done = try box.decodeIfPresent(Date.self, forKey: .done)
        }

        var title: String { Lang.text(advice) }

        /// «2 из 4» — у повторяющегося; у разового пусто.
        var count: String? {
            rounds > 1 ? Lang.format("%1$lld из %2$lld", round, rounds) : nil
        }
    }

    /// Что лечим — `Finding.Kind` строкой: сад собирается и без разбора
    /// снимков (виджет).
    var kinds: [String]
    var started: Date
    var steps: [Step]
    /// Снимки «до» и «после» — имена файлов в `Shots`.
    var before: String?
    var after: String?
    /// Когда вылечили; пусто — лечится.
    var cured: Date?

    init(kinds: [String], started: Date, steps: [Step], before: String? = nil,
         after: String? = nil, cured: Date? = nil) {
        self.kinds = kinds
        self.started = started
        self.steps = steps
        self.before = before
        self.after = after
        self.cured = cured
    }

    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        kinds = try box.decodeIfPresent([String].self, forKey: .kinds) ?? []
        started = try box.decodeIfPresent(Date.self, forKey: .started)
            ?? .distantPast
        steps = try box.decodeIfPresent([Step].self, forKey: .steps) ?? []
        before = try box.decodeIfPresent(String.self, forKey: .before)
        after = try box.decodeIfPresent(String.self, forKey: .after)
        cured = try box.decodeIfPresent(Date.self, forKey: .cured)
    }

    /// Сколько дней сада — в настоящих секундах.
    static func seconds(days: Double, speed: Double = Garden.speed)
        -> TimeInterval {
        days * 86_400 / speed
    }

    var active: Bool { cured == nil }

    var done: Int { steps.count { $0.done != nil } }

    var total: Int { steps.count }

    /// Всё отмечено — пора сказать «Вылечено».
    var complete: Bool { !steps.isEmpty && done == total }

    /// Ближайший несделанный шаг; при равных сроках — по порядку плана.
    var next: Step? {
        steps.filter { $0.done == nil }.min { $0.due < $1.due }
    }

    /// Несделанные, чей срок пришёл.
    func due(at now: Date = Date()) -> [Step] {
        steps.filter { $0.done == nil && $0.due <= now }
    }

    /// Снимки плана на диске — уходят вместе с ним и с растением.
    var files: [String] { [before, after].compactMap { $0 } }

    /// Отметить шаг сделанным — или снять отметку.
    mutating func mark(_ id: Step.ID, done: Bool, at now: Date = Date()) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else {
            return
        }
        steps[index].done = done ? (steps[index].done ?? now) : nil
    }

    /// «Вылечено»: несделанные шаги больше не ждут — и не напоминают.
    mutating func cure(at now: Date = Date()) {
        guard cured == nil else { return }
        cured = now
    }

    /// Срок шага словами, в днях сада: «пора», «сегодня», «через 3 дня».
    static func when(_ due: Date, from now: Date = Date(),
                     speed: Double = Garden.speed) -> String {
        let left = due.timeIntervalSince(now) * speed / 86_400
        if left <= 0 { return Lang.text("пора") }
        if left < 1 { return Lang.text("сегодня") }
        return Lang.format("через %lld дней", Int(left.rounded()))
    }
}
