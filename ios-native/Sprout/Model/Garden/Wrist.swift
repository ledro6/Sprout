import Foundation

/// Сад на часах — столько, сколько им нужно показать: клички, комнаты,
/// влажность и срок. Телефон шлёт его часам после каждой записи сада, часы
/// держат у себя: и приложению, и циферблату. Файл общий для телефона и
/// часов, поэтому без типов сада — только своё.
struct Wrist: Codable, Equatable, Sendable {
    struct Pot: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var name: String
        var room: String
        /// 0…1, как у растения в саду.
        var moisture: Double
        /// За сколько дней высыхает — после полива с часов срок считается
        /// от него.
        var period: Double

        var level: Level { Level(moisture: moisture) }

        /// Дней до полива — как на карточке в приложении.
        var days: Int { max(0, Int((moisture * period).rounded())) }

        var percent: Int { Int((moisture * 100).rounded()) }

        /// Те же слова, что на карточке в приложении, — и те же переводы.
        var label: String {
            if days <= 0 { return Lang.text("Следующий полив: сегодня") }
            if days == 1 { return Lang.text("Следующий полив: завтра") }
            return Lang.format("Следующий полив: %lld дней", days)
        }
    }

    /// Та же тень, что на карточке: ниже 40% — пора, ниже 20% — срочно.
    enum Level: Sendable {
        case calm, warn, alarm

        static let warnBelow = 0.4
        static let alarmBelow = 0.2

        init(moisture: Double) {
            switch moisture {
            case ..<Self.alarmBelow: self = .alarm
            case ..<Self.warnBelow: self = .warn
            default: self = .calm
            }
        }
    }

    /// От самого сухого.
    var pots: [Pot]
    var sent: Date

    var thirsty: [Pot] { pots.filter { $0.level != .calm } }

    /// Полили с часов — сразу на часах, не дожидаясь телефона: он догонит.
    /// Слепок помечается мигом полива: посылка телефона, собранная раньше,
    /// его уже не перетрёт.
    mutating func water(_ id: String, at moment: Date = Date()) {
        guard let index = pots.firstIndex(where: { $0.id == id }) else {
            return
        }
        pots[index].moisture = 1
        pots.sort { $0.moisture < $1.moisture }
        sent = max(sent, moment)
    }

    /// Новая посылка — только если она не старше того, что уже есть.
    func older(than other: Wrist) -> Bool { sent < other.sent }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }

    static func decoded(_ data: Data) -> Wrist? {
        try? JSONDecoder().decode(Wrist.self, from: data)
    }

    /// Та же группа, что у телефона (`Store.group`), но на часах у неё своя
    /// папка — в ней сад для приложения и циферблата.
    static let group = "group.com.ledro6.sprout"

    static var file: URL? {
        #if canImport(Darwin)
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("wrist.json")
        #else
        nil
        #endif
    }

    static func read() -> Wrist? {
        guard let file, let data = try? Data(contentsOf: file) else {
            return nil
        }
        return decoded(data)
    }

    func write() {
        guard let file = Self.file, let data = encoded() else { return }
        try? data.write(to: file, options: .atomic)
    }

    /// Ключи посылок между телефоном и часами.
    enum Key {
        static let garden = "garden"
        static let water = "water"
        static let when = "when"
    }
}
