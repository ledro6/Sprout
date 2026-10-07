import Foundation

/// NFC-метка на горшке. На ней одна запись — ссылка приложения на растение:
/// `sprout://plant/<номер>`. Номер, а не кличка: кличку меняют, а номер у
/// растения один на всю жизнь и на всех телефонах общего сада — метку,
/// записанную одним, читает и другой.
///
/// Здесь только чистая логика: ссылка туда и обратно, что делать с
/// прочитанным и защита от двойного полива. Сеанс NFC — в `Tags`.
enum PotTag {
    static let scheme = "sprout"
    static let host = "plant"

    /// Номер длиннее — не наш: у растений это UUID или короткое слово
    /// макета («baksik»). Предел держит запись в самой маленькой метке
    /// (NTAG213, 137 байт).
    static let longest = 64

    /// Тот же горшок приложили снова, а полив отмечен недавно, — второй раз
    /// не поливаем: метку легко задеть, пока ставишь лейку.
    static let calm: TimeInterval = 10 * 60

    /// Буквы, цифры, дефис и подчёркивание — всё, из чего бывают номера;
    /// остальное в ссылке пришлось бы экранировать, а с чужой метки пришло
    /// бы что угодно.
    static func valid(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= longest else { return false }
        return id.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar)
                || scalar == "-" || scalar == "_")
        }
    }

    /// Ссылка для записи; негодный номер — без ссылки.
    static func link(_ id: Plant.ID) -> URL? {
        guard valid(id) else { return nil }
        return URL(string: "\(scheme)://\(host)/\(id)")
    }

    /// Номер растения из ссылки. Схема и хост — без учёта регистра: так их
    /// сравнивает и система; номер — как есть.
    static func plant(in url: URL) -> Plant.ID? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host else { return nil }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 1, url.query == nil, url.fragment == nil
        else { return nil }
        let id = String(parts[0])
        return valid(id) ? id : nil
    }

    /// Полив по метке — сразу или с вопросом.
    enum Pour: String, CaseIterable, Identifiable {
        case now, ask

        var id: String { rawValue }

        var title: String {
            switch self {
            case .now: Lang.text("Сразу")
            case .ask: Lang.text("Спросить")
            }
        }
    }

    /// Что сделать с прочитанной меткой.
    enum Reaction: Equatable {
        /// На метке не наша ссылка или чужое.
        case foreign
        /// Растение с этим номером из сада ушло.
        case gone
        /// Открыть и полить.
        case water(Plant.ID)
        /// Открыть и спросить, полить ли.
        case ask(Plant.ID)
        /// Открыть, а полив уже отмечен — тогда-то.
        case fresh(Plant.ID, Date)
    }

    static func react(to url: URL?, rooms: [Room], log: [Watering],
                      mode: Pour, now: Date) -> Reaction {
        guard let url, let id = plant(in: url) else { return .foreign }
        guard rooms.contains(where: { $0.plants.contains { $0.id == id } })
        else { return .gone }
        if let last = lately(id, log: log, now: now) {
            return .fresh(id, last)
        }
        return mode == .now ? .water(id) : .ask(id)
    }

    /// Последний полив растения, если он моложе `calm`. Запись из будущего
    /// (часы переводили) тоже считается свежей — лишний полив хуже.
    static func lately(_ id: Plant.ID, log: [Watering], now: Date) -> Date? {
        let last = log.lazy.filter { $0.plant == id }.map(\.when).max()
        guard let last, now.timeIntervalSince(last) < calm else { return nil }
        return last
    }
}
