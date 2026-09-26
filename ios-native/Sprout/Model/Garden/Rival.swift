import Foundation
import Observation

/// Счёт друга, который прислал свой код. Сервера у Sprout нет: друг присылает
/// строку в переписке, вы вставляете её, и его счёт встаёт рядом с вашим.
struct Rival: Codable, Identifiable, Hashable, Sendable {
    var name: String
    var total: Int
    var streak: Int
    var best: Int
    var plants: Int

    /// Сутки от 1970 года, а не дата: каждый знак кода виден в переписке, а
    /// точнее дня не нужно.
    var day: Int

    // Сад целиком — для сравнения. В кодах прежних сборок этого нет, и
    // сравнение показывает прочерк.
    var level: Int? = nil
    var medals: Int? = nil
    /// Разных видов в саду.
    var kinds: Int? = nil
    /// Поливы вовремя — в процентах от всех.
    var aim: Int? = nil
    /// Полных недель заданий.
    var weeks: Int? = nil
    /// Счёт в общем челлендже, см. `Race`.
    var race: Race.Score? = nil

    /// Без оглядки на регистр: друг, приславший код дважды, занимает одну
    /// строку.
    var id: String { name.lowercased() }

    var stamp: Date { Date(timeIntervalSince1970: Double(day) * 86_400) }

    enum CodingKeys: String, CodingKey {
        case name = "n", total = "t", streak = "s"
        case best = "b", plants = "p", day = "d"
        case level = "l", medals = "m", kinds = "k", aim = "a", weeks = "w"
        case race = "r"
    }

    static func day(of moment: Date) -> Int {
        Int((moment.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    static func mine(owner: String, score: Score, plants: Int,
                     level: Int? = nil, medals: Int? = nil, kinds: Int? = nil,
                     aim: Int? = nil, weeks: Int? = nil,
                     race: Race.Score? = nil,
                     on moment: Date = Date()) -> Rival {
        Rival(name: owner, total: score.total, streak: score.streak,
              best: score.best, plants: plants, day: day(of: moment),
              level: level, medals: medals, kinds: kinds, aim: aim,
              weeks: weeks, race: race)
    }

    /// Доля поливов вовремя, в процентах; судить не по чему — пусто.
    static func aim(_ log: [Watering]) -> Int? {
        let known = log.compactMap(\.left)
        guard !known.isEmpty else { return nil }
        let good = known.count { Almanac.Aim.zone($0) == .onTime }
        return Int((Double(good) / Double(known.count) * 100).rounded())
    }

    // MARK: - Код

    /// Версия в метке: сменится набор полей — старый код не разберётся молча
    /// не тем.
    static let mark = "SPROUT1."

    /// Сперва человеческая часть, потом код: сообщение читает человек.
    var card: String {
        var score = Lang.format("%1$@ в Sprout: %2$@, череда %3$@, лучшая %4$lld.",
                                name, Lang.format("%lld поливов", total),
                                Lang.format("%lld дней", streak), best)
        if let level {
            score += " " + Lang.format("Уровень %1$lld — %2$@.", level,
                                       Gardener.title(level))
        }
        let invite = Lang.text("Позвать меня в соперники: скопируйте это сообщение целиком и нажмите «Вставить» в Sprout → Профиль → Друзья.")
        return score + "\n" + invite + "\n" + code
    }

    var code: String { Codeword.encode(self, mark: Self.mark) }

    static func read(_ text: String) -> Rival? {
        Codeword.decode(Rival.self, mark: mark, in: text) {
            !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

/// Коды в переписке: метка с версией и base64url — «+» и «/» переписка и
/// браузеры портят. Ищем метку, а не разбираем текст целиком: вставляют
/// обычно всё сообщение.
enum Codeword {
    static func encode(_ value: some Encodable, mark: String) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "" }
        return mark + pack(data)
    }

    static func decode<Value: Decodable>(
        _ type: Value.Type, mark: String, in text: String,
        valid: (Value) -> Bool = { _ in true }
    ) -> Value? {
        for piece in text.split(whereSeparator: \.isWhitespace) {
            guard let start = piece.range(of: mark) else { continue }
            let token = piece[start.upperBound...].prefix(while: allowed)
            guard let data = unpack(String(token)),
                  let value = try? JSONDecoder().decode(type, from: data),
                  valid(value)
            else { continue }
            return value
        }
        return nil
    }

    private static func allowed(_ c: Character) -> Bool {
        c.isASCII && (c.isLetter || c.isNumber || c == "-" || c == "_")
    }

    static func pack(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func unpack(_ token: String) -> Data? {
        guard !token.isEmpty else { return nil }
        var text = token
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Хвост из «=» base64url не передаёт — дописываем.
        while text.count % 4 != 0 { text.append("=") }
        return Data(base64Encoded: text)
    }
}

/// Позванные соперники и общие челленджи — в `UserDefaults`: это не
/// данные сада.
@Observable
final class Friends {
    static let shared = Friends()

    private(set) var rivals: [Rival] = []
    /// Челленджи, в которых участвуем, — от старых к новым.
    private(set) var races: [Race] = []

    @ObservationIgnored private let store: UserDefaults
    private static let key = "rivals"
    private static let racesKey = "races"

    init(store: UserDefaults = .standard) {
        self.store = store
        if let data = store.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Rival].self, from: data) {
            rivals = Self.ranked(saved)
        }
        if let data = store.data(forKey: Self.racesKey),
           let saved = try? JSONDecoder().decode([Race].self, from: data) {
            races = saved
        }
    }

    /// Челлендж, который показывает профиль: идущий, а закончился — ещё
    /// неделю, с итогом.
    func current(at moment: Date = Date(),
                 calendar: Calendar = .current) -> Race? {
        races.last { race in
            let span = race.span(calendar: calendar)
            return span.start <= moment
                && moment < span.end.addingTimeInterval(Race.afterglow)
        }
    }

    /// Тот же челлендж второй раз не заводится.
    func join(_ race: Race) {
        races.removeAll { $0.id == race.id }
        races.append(race)
        // Помнить больше десятка незачем: показывается один.
        races = Array(races.suffix(10))
        saveRaces()
    }

    func leave(_ id: Race.ID) {
        races.removeAll { $0.id == id }
        saveRaces()
    }

    /// Места в челлендже: свой счёт — живой, чужие — какими их прислали.
    /// Кто не прислал счёт этого челленджа, в таблице нет.
    func standings(_ race: Race, mine: Rival) -> [(name: String, count: Int)] {
        var rows = [(name: mine.name, count: mine.race?.count ?? 0)]
        for rival in rivals where rival.id != mine.id {
            if let score = rival.race, score.id == race.id {
                rows.append((rival.name, score.count))
            }
        }
        return rows.sorted { ($0.count, $1.name) > ($1.count, $0.name) }
    }

    /// Свой код в соперники не берём: строка хозяина в таблице уже есть,
    /// живая.
    @discardableResult
    func take(_ text: String, mine owner: String) -> Rival? {
        guard let rival = Rival.read(text) else { return nil }
        guard rival.id != owner.lowercased() else { return nil }
        add(rival)
        return rival
    }

    /// Тот, кто уже в таблице, заменяется целиком: счёт у друга один.
    func add(_ rival: Rival) {
        var next = rivals.filter { $0.id != rival.id }
        next.append(rival)
        rivals = Self.ranked(next)
        save()
    }

    func remove(_ id: Rival.ID) {
        rivals.removeAll { $0.id == id }
        save()
    }

    func clear() {
        rivals = []
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rivals) else { return }
        store.set(data, forKey: Self.key)
    }

    private func saveRaces() {
        guard let data = try? JSONEncoder().encode(races) else { return }
        store.set(data, forKey: Self.racesKey)
    }

    /// При равенстве — по кличке, чтобы строки не перескакивали от запуска к
    /// запуску.
    private static func ranked(_ list: [Rival]) -> [Rival] {
        list.sorted { ($0.total, $1.name) > ($1.total, $0.name) }
    }
}
