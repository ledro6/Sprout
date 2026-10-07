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
        /// Влажность с датчика, а не посчитана по сроку. Пусто в посылках
        /// прежних сборок — посчитана.
        var measured: Bool?

        /// Статус и сроки — тем же движком, что в приложении
        /// (`MoistureStatus`): своих порогов у часов нет.
        var status: MoistureStatus { MoistureStatus(moisture: moisture) }

        /// Полить сегодня — как «Ждут воды» на телефоне.
        var due: Bool { MoistureStatus.due(moisture: moisture, period: period) }

        /// Дней до полива — как на карточке в приложении.
        var days: Int { MoistureStatus.days(moisture: moisture, period: period) }

        var percent: Int { Int((moisture * 100).rounded()) }

        /// Земля ещё влажная — полив переспрашивает, см.
        /// `MoistureStatus.wateringGuard`.
        var wet: Bool {
            MoistureStatus.wateringGuard(moisture: moisture) != .allow
        }

        var estimated: Bool { measured != true }

        /// Те же слова, что на карточке в приложении, — и те же переводы.
        var label: String {
            MoistureStatus.nextWatering(moisture: moisture, period: period,
                                        estimated: estimated)
        }
    }

    /// От самого сухого.
    var pots: [Pot]
    var sent: Date

    /// Кого полить сегодня — тот же набор, что `MoistureStatus.needsWater`.
    var thirsty: [Pot] { pots.filter(\.due) }

    /// Полили с часов — сразу на часах, не дожидаясь телефона: он догонит.
    /// Слепок помечается мигом полива: посылка телефона, собранная раньше,
    /// его уже не перетрёт.
    /// Влажную землю — только с подтверждением (`anyway`), как на
    /// телефоне; отвечает, полилось ли.
    @discardableResult
    mutating func water(_ id: String, at moment: Date = Date(),
                        anyway: Bool = false) -> Bool {
        guard let index = pots.firstIndex(where: { $0.id == id }),
              anyway || !pots[index].wet else {
            return false
        }
        pots[index].moisture = 1
        pots.sort { $0.moisture < $1.moisture }
        sent = max(sent, moment)
        return true
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
        /// Полили влажную землю, подтвердив, — см. `Garden.water`.
        static let anyway = "anyway"
    }
}
