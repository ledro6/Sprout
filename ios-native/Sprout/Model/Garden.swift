import Foundation

/// Насколько срочно растение просит воды. От этого зависит красное
/// свечение карточки — в макете оно двух сил, #FF000066 и #FF000099.
enum Thirst {
    /// Полив нескоро, карточка спокойная.
    case calm
    /// Полив завтра — мягкое свечение.
    case soon
    /// Полив сегодня или уже просрочен — свечение сильнее.
    case now

    init(daysUntilWatering days: Int) {
        switch days {
        case ..<1: self = .now
        case 1: self = .soon
        default: self = .calm
        }
    }
}

struct Plant: Identifiable, Hashable {
    let id: String
    /// Кличка, которую дал хозяин: «Баксик», «Сумка».
    let name: String
    /// Вид растения: «Тюльпан».
    let species: String
    /// Влажность почвы, 0…1.
    let moisture: Double
    let daysUntilWatering: Int
    let addedOn: DateComponents
    var photo: String = "monstera"

    var thirst: Thirst { Thirst(daysUntilWatering: daysUntilWatering) }

    var moistureLabel: String { "\(Int((moisture * 100).rounded()))%" }

    /// «Следующий полив сегодня / завтра / через 5 дней».
    var wateringLabel: String {
        if daysUntilWatering <= 0 { return "Следующий полив сегодня" }
        if daysUntilWatering == 1 { return "Следующий полив завтра" }
        return "Следующий полив через \(daysUntilWatering) "
            + Self.plural(daysUntilWatering, "день", "дня", "дней")
    }

    var addedLabel: String {
        "Добавлен \(addedOn.day ?? 1).\(addedOn.month ?? 1).\(addedOn.year ?? 2024)"
    }

    /// Русское склонение по числу: 1 день, 2 дня, 5 дней.
    static func plural(_ n: Int, _ one: String, _ few: String,
                       _ many: String) -> String {
        let mod100 = n % 100
        if (11...14).contains(mod100) { return many }
        switch n % 10 {
        case 1: return one
        case 2, 3, 4: return few
        default: return many
        }
    }
}

struct Room: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let plants: [Plant]
}

/// Данные из макета: те же клички, проценты и сроки полива.
enum Garden {
    static let owner = "Святослав"

    static let rooms: [Room] = [
        Room(name: "Спальня", plants: [
            Plant(id: "baksik", name: "Баксик", species: "Тюльпан",
                  moisture: 0.89, daysUntilWatering: 8,
                  addedOn: DateComponents(year: 2024, month: 11, day: 2)),
            Plant(id: "pr", name: "Пр", species: "Монстера",
                  moisture: 0.14, daysUntilWatering: 1,
                  addedOn: DateComponents(year: 2025, month: 3, day: 17)),
        ]),
        Room(name: "Гостиная", plants: [
            Plant(id: "zelenik", name: "Зеленик", species: "Фикус",
                  moisture: 0.30, daysUntilWatering: 2,
                  addedOn: DateComponents(year: 2025, month: 1, day: 9)),
        ]),
        Room(name: "Кухня", plants: [
            Plant(id: "murzik", name: "Мурзик", species: "Монстера",
                  moisture: 0.89, daysUntilWatering: 8,
                  addedOn: DateComponents(year: 2024, month: 12, day: 20)),
            Plant(id: "privet", name: "Привет", species: "Замиокулькас",
                  moisture: 0.14, daysUntilWatering: 1,
                  addedOn: DateComponents(year: 2025, month: 2, day: 4)),
            Plant(id: "lera", name: "Лера", species: "Сансевиерия",
                  moisture: 0.56, daysUntilWatering: 5,
                  addedOn: DateComponents(year: 2025, month: 4, day: 28)),
            Plant(id: "sumka", name: "Сумка", species: "Спатифиллум",
                  moisture: 0.01, daysUntilWatering: 0,
                  addedOn: DateComponents(year: 2025, month: 6, day: 1)),
            Plant(id: "baksik-2", name: "Баксик", species: "Тюльпан",
                  moisture: 0.89, daysUntilWatering: 8,
                  addedOn: DateComponents(year: 2024, month: 11, day: 2)),
        ]),
    ]

    /// Поиск идёт по всей квартире: искать растение по имени логично
    /// не только в открытой комнате.
    static func search(_ query: String) -> [Plant] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return rooms.flatMap(\.plants).filter {
            $0.name.lowercased().contains(q) || $0.species.lowercased().contains(q)
        }
    }
}
