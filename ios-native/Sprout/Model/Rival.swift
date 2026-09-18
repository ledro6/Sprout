import Foundation
import Observation

/// Счёт соперника — друга, который прислал свой код.
///
/// Сервера у Sprout нет, и учётной записи тоже. Таблица соперников всё
/// равно возможна: друг присылает строку со своим счётом, вы вставляете
/// её здесь, и его результат встаёт рядом с вашим. Обновится он тогда,
/// когда друг пришлёт код снова.
///
/// Честнее, чем «онлайн-таблица», которой не было бы: настоящая требует
/// сервера, учётных записей и платного аккаунта разработчика, а эта
/// работает сегодня, без сети вовсе, и переписка идёт там, где друзья и
/// так переписываются.
struct Rival: Codable, Identifiable, Hashable, Sendable {
    var name: String
    var total: Int
    var streak: Int
    var best: Int
    var plants: Int

    /// Сутки от 1 января 1970 — когда сняли счёт.
    ///
    /// Днями, а не датой: код передают в переписке, и каждый лишний знак
    /// в нём виден. Дата в JSON занимает семнадцать знаков, день — пять, а
    /// точнее дня здесь ничего и не нужно.
    var day: Int

    /// По кличке, без оглядки на регистр: один и тот же друг, приславший
    /// код дважды, должен занять одну строку, а не две.
    var id: String { name.lowercased() }

    var stamp: Date { Date(timeIntervalSince1970: Double(day) * 86_400) }

    enum CodingKeys: String, CodingKey {
        case name = "n", total = "t", streak = "s"
        case best = "b", plants = "p", day = "d"
    }

    /// Сутки, в которые попадает эта дата.
    static func day(of moment: Date) -> Int {
        Int((moment.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Свой счёт — тот, что уходит друзьям.
    static func mine(owner: String, score: Score, plants: Int,
                     on moment: Date = Date()) -> Rival {
        Rival(name: owner, total: score.total, streak: score.streak,
              best: score.best, plants: plants, day: day(of: moment))
    }

    // MARK: - Код

    /// С чего начинается код. Версия в самой метке: поменяется набор
    /// полей — поменяется и она, и старый код не разберётся молча не тем.
    static let mark = "SPROUT1."

    /// Строка, которую отправляют другу.
    ///
    /// Сперва человеческая часть, потом код. Человеческая нужна затем,
    /// что сообщение читает человек: получить в чате одну строку
    /// нечитаемых знаков — то же, что получить вложение без подписи.
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

    /// Сам код: метка и слепок счёта в base64url.
    ///
    /// base64url, а не обычный base64: обычный кладёт в строку «+» и «/»,
    /// а их переписка и браузеры любят превращать во что угодно. В
    /// base64url их место занимают «-» и «_», и строка проходит через
    /// чужие руки целой.
    var code: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return Self.mark + Self.pack(data)
    }

    /// Найти код в присланном тексте и разобрать его.
    ///
    /// Именно найти, а не разобрать целиком: вставляют обычно всё
    /// сообщение, вместе с человеческой частью, а иногда и вместе с
    /// «переслано от…». Ищем метку, берём от неё всё, что похоже на код, и
    /// на этом останавливаемся.
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

    /// Знаки base64url. Всё, что не из них, — уже не код: точка в конце
    /// предложения, закрывающая скобка, перевод строки.
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
        // Хвост из «=» base64url не передаёт — дописываем обратно.
        while text.count % 4 != 0 { text.append("=") }
        return Data(base64Encoded: text)
    }
}

/// Соперники, которых уже позвали.
///
/// В `UserDefaults`, а не в файле сада: это не сад. Сад — растения
/// хозяина, им место в Documents и в резервной копии; присланные счета
/// друзей — несколько строк, которые надо помнить между запусками, и это
/// ровно то, для чего `UserDefaults` и есть.
@Observable
final class Friends {
    static let shared = Friends()

    /// От большего счёта к меньшему — таблица и есть порядок.
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

    /// Разобрать присланное и поставить в таблицу.
    ///
    /// Своё имя в соперники не берём: строка хозяина в таблице и так
    /// есть, живая, а вставленный собственный код застыл бы рядом с ней
    /// вторым, устаревшим «вами».
    @discardableResult
    func take(_ text: String, mine owner: String) -> Rival? {
        guard let rival = Rival.read(text) else { return nil }
        guard rival.id != owner.lowercased() else { return nil }
        add(rival)
        return rival
    }

    /// Прислал код тот, кто уже в таблице, — заменяем строку целиком.
    /// Счёт у друга один, и двух строк на него быть не может.
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

    /// Порядок таблицы: по поливам, а при равенстве — по кличке, чтобы
    /// строки не перескакивали местами от запуска к запуску.
    private static func ranked(_ list: [Rival]) -> [Rival] {
        list.sorted { ($0.total, $1.name) > ($1.total, $0.name) }
    }
}
