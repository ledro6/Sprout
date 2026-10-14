import Foundation

/// «Обсерватория»: раз в день планетарий спрашивает «Кто первым дойдёт до
/// луча?» и показывает до четырёх планет, ближайших к воротам. Нужно
/// выбрать одну. Верно — «звезда наблюдателя», подряд верные дни — серия.
///
/// Кто пришёл первым, решает модель в миг выбора: у каждой кандидатки
/// считается срок до луча (`eta`: когда влажность дойдёт до порога
/// «сухо», по сроку полива растения), и первой считается та, у кого он
/// меньше. Игра нарочно не читает полив после выбора: иначе «выиграть»
/// можно было бы, полив соперницу заранее, — то есть награда шла бы за
/// лишний полив. Угадывает тот, кто смотрит на небо: у ближней к лучу
/// планеты срок бывает длиннее, чем у далёкой, но быстрой. Ответ
/// открывается, когда по часам пришла первая, но не позже конца
/// следующего дня.
enum Observatory {
    /// Столько планет в вопросе, не больше.
    static let limit = 4

    /// Записей дней храним.
    static let keep = 40

    struct Candidate: Codable, Hashable, Sendable {
        var id: Plant.ID
        var name: String
        /// Дней сада до луча на момент вопроса.
        var eta: Double
    }

    enum Outcome: String, Codable, Sendable {
        case hit, miss
    }

    struct Entry: Codable, Hashable, Sendable {
        /// «2026-10-14» — день вопроса.
        var day: String
        var made: Date
        var candidates: [Candidate]
        var picked: Plant.ID
        /// Кто придёт первой — решено в миг выбора, пользователю не
        /// показывается до ответа.
        var winner: Plant.ID
        /// Когда ответ открывается.
        var reveal: Date
        var outcome: Outcome?
    }

    /// Дней сада до порога «сухо»; пусто, если растение уже у луча.
    static func eta(_ orbit: Orrery.Orbit) -> Double? {
        guard orbit.period > 0, orbit.moisture > MoistureStatus.urgentBelow
        else { return nil }
        return (orbit.moisture - MoistureStatus.urgentBelow) * orbit.period
    }

    /// Ближние к воротам — с наименьшей влажностью, как углы в `Orrery`.
    /// Те, что уже у луча, не в счёт; одной планеты на вопрос мало.
    static func candidates(_ orbits: [Orrery.Orbit]) -> [Candidate] {
        let near = orbits.compactMap { orbit -> (Orrery.Orbit, Double)? in
            eta(orbit).map { (orbit, $0) }
        }
        .sorted {
            ($0.0.moisture, $0.0.rank, $0.0.id)
                < ($1.0.moisture, $1.0.rank, $1.0.id)
        }
        .prefix(limit)
        guard near.count >= 2 else { return [] }
        return near.map { Candidate(id: $0.0.id, name: $0.0.name, eta: $0.1) }
    }

    /// Первая по сроку; равные — по номеру растения, чтобы не прыгало.
    static func winner(_ candidates: [Candidate]) -> Candidate? {
        candidates.min { ($0.eta, $0.id) < ($1.eta, $1.id) }
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0,
                      parts.month ?? 0, parts.day ?? 0)
    }

    /// Вопрос на сегодня ещё не отвечен.
    static func open(_ entries: [Entry], now: Date,
                     calendar: Calendar = .current) -> Bool {
        let today = dayKey(now, calendar: calendar)
        return !entries.contains { $0.day == today }
    }

    /// Выбор планеты. `speed` — дней сада в сутках, как `Garden.speed`.
    static func pick(_ id: Plant.ID, from candidates: [Candidate], now: Date,
                     speed: Double = 1, calendar: Calendar = .current)
        -> Entry? {
        guard candidates.contains(where: { $0.id == id }),
              let first = winner(candidates) else { return nil }
        let arrival = now.addingTimeInterval(
            first.eta * 86_400 / max(speed, 0.000_1))
        let start = calendar.startOfDay(for: now)
        let cap = calendar.date(byAdding: .day, value: 2, to: start)
            ?? now.addingTimeInterval(2 * 86_400)
        return Entry(day: dayKey(now, calendar: calendar), made: now,
                     candidates: candidates, picked: id, winner: first.id,
                     reveal: min(arrival, cap), outcome: nil)
    }

    /// Ответ открыт, когда пришёл срок.
    static func settle(_ entry: Entry, now: Date) -> Entry {
        guard entry.outcome == nil, now >= entry.reveal else { return entry }
        var out = entry
        out.outcome = entry.picked == entry.winner ? .hit : .miss
        return out
    }

    /// Подряд верные дни, считая от сегодня; если сегодня ещё нет — от
    /// вчера: серия не рвётся, пока день не кончился.
    static func streak(_ entries: [Entry], today: Date,
                       calendar: Calendar = .current) -> Int {
        let hits = Set(entries.filter { $0.outcome == .hit }.map(\.day))
        var day = today
        if !hits.contains(dayKey(day, calendar: calendar)) {
            guard let back = calendar.date(byAdding: .day, value: -1, to: day)
            else { return 0 }
            day = back
        }
        var count = 0
        while hits.contains(dayKey(day, calendar: calendar)), count < 1_000 {
            count += 1
            guard let back = calendar.date(byAdding: .day, value: -1, to: day)
            else { break }
            day = back
        }
        return count
    }
}
