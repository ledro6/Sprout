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

    /// Без оглядки на регистр: друг, приславший код дважды, занимает одну
    /// строку.
    var id: String { name.lowercased() }

    var stamp: Date { Date(timeIntervalSince1970: Double(day) * 86_400) }

    enum CodingKeys: String, CodingKey {
        case name = "n", total = "t", streak = "s"
        case best = "b", plants = "p", day = "d"
    }

    static func day(of moment: Date) -> Int {
        Int((moment.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    static func mine(owner: String, score: Score, plants: Int,
                     on moment: Date = Date()) -> Rival {
        Rival(name: owner, total: score.total, streak: score.streak,
              best: score.best, plants: plants, day: day(of: moment))
    }

    // MARK: - Код

    /// Версия в метке: сменится набор полей — старый код не разберётся молча
    /// не тем.
    static let mark = "SPROUT1."

    /// Сперва человеческая часть, потом код: сообщение читает человек.
    var card: String {
        let waterings = Plant.plural(total, "полив", "полива", "поливов")
        let days = Plant.plural(streak, "день", "дня", "дней")
        return """
        \(name) в Sprout: \(total) \(waterings), череда \(streak) \(days), \
        лучшая \(best).
        Позвать меня в соперники: скопируйте это сообщение целиком и \
        нажмите «Вставить» в Sprout → Профиль → Друзья.
        \(code)
        """
    }

    /// base64url, а не base64: «+» и «/» переписка и браузеры портят.
    var code: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return Self.mark + Self.pack(data)
    }

    /// Ищем метку, а не разбираем текст целиком: вставляют обычно всё
    /// сообщение.
    static func read(_ text: String) -> Rival? {
        for piece in text.split(whereSeparator: \.isWhitespace) {
            guard let start = piece.range(of: mark) else { continue }
            let token = piece[start.upperBound...].prefix(while: allowed)
            guard let data = unpack(String(token)),
                  let rival = try? JSONDecoder().decode(Rival.self, from: data),
                  !rival.name.trimmingCharacters(in: .whitespaces).isEmpty
            else { continue }
            return rival
        }
        return nil
    }

    private static func allowed(_ c: Character) -> Bool {
        c.isASCII && (c.isLetter || c.isNumber || c == "-" || c == "_")
    }

    private static func pack(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func unpack(_ token: String) -> Data? {
        guard !token.isEmpty else { return nil }
        var text = token
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Хвост из «=» base64url не передаёт — дописываем.
        while text.count % 4 != 0 { text.append("=") }
        return Data(base64Encoded: text)
    }
}

/// Позванные соперники — в `UserDefaults`: это не данные сада.
@Observable
final class Friends {
    static let shared = Friends()

    private(set) var rivals: [Rival] = []

    @ObservationIgnored private let store: UserDefaults
    private static let key = "rivals"

    init(store: UserDefaults = .standard) {
        self.store = store
        if let data = store.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([Rival].self, from: data) {
            rivals = Self.ranked(saved)
        }
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

    /// При равенстве — по кличке, чтобы строки не перескакивали от запуска к
    /// запуску.
    private static func ranked(_ list: [Rival]) -> [Rival] {
        list.sorted { ($0.total, $1.name) > ($1.total, $0.name) }
    }
}
