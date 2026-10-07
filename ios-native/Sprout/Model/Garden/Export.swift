import Foundation

/// Журнал поливов наружу — таблицей CSV и файлом JSON, через лист
/// «Поделиться»: свои данные можно забрать в любой момент. Строка — один
/// полив: когда, кого, где, сколько воды оставалось в земле и кто полил.
enum Export {
    struct Row: Codable, Equatable, Sendable {
        var date: Date
        var plant: String
        var species: String?
        var room: String?
        /// Влажность перед поливом, проценты; в старых записях её нет.
        var moistureBefore: Int?
        /// Кто полил — в общем саду.
        var by: String?
    }

    /// Кличка, вид и комната растения — всё, что журналу нужно от сада.
    struct Place: Equatable, Sendable {
        var name: String
        var species: String
        var room: String
    }

    static func places(_ rooms: [Room]) -> [Plant.ID: Place] {
        var known: [Plant.ID: Place] = [:]
        for room in rooms {
            for plant in room.plants {
                known[plant.id] = Place(name: plant.name,
                                        species: plant.species,
                                        room: room.name)
            }
        }
        return known
    }

    /// Поливы по порядку. Растение, которого в саду уже нет, — номером.
    static func rows(_ log: [Watering],
                     places known: [Plant.ID: Place]) -> [Row] {
        log.sorted { $0.when < $1.when }.map { entry in
            let found = known[entry.plant]
            return Row(date: entry.when,
                       plant: found?.name ?? entry.plant,
                       species: found?.species,
                       room: found?.room,
                       moistureBefore: entry.left.map {
                           Int(($0 * 100).rounded())
                       },
                       by: entry.by)
        }
    }

    /// Таблица для Numbers и Excel: UTF-8 с меткой порядка байтов — иначе
    /// Excel покажет кириллицу кракозябрами, — запятые, строки через CRLF.
    static func csv(_ rows: [Row]) -> String {
        let iso = ISO8601DateFormatter()
        let head = [Lang.text("Дата"), Lang.text("Растение"), Lang.text("Вид"),
                    Lang.text("Комната"), Lang.text("Влажность до полива, %"),
                    Lang.text("Кто полил")]
        var lines = [head.map(cell).joined(separator: ",")]
        for row in rows {
            let cells = [iso.string(from: row.date), row.plant,
                         row.species ?? "", row.room ?? "",
                         row.moistureBefore.map(String.init) ?? "",
                         row.by ?? ""]
            lines.append(cells.map(cell).joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Ячейка CSV: кавычки — если внутри запятая, кавычка или перенос.
    /// Кличка с «=», «+», «-» или «@» в начале таблица приняла бы за
    /// формулу — перед ней апостроф.
    static func cell(_ text: String) -> String {
        var text = text
        if let first = text.first, "=+-@".contains(first) {
            text = "'" + text
        }
        guard text.contains(where: { ",\"\n\r".contains($0) }) else {
            return text
        }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func json(_ rows: [Row]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(rows)) ?? Data("[]".utf8)
    }
}
