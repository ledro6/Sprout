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
    /// Кличка, которую дал хозяин: «Баксик», «Сумка». Меняется.
    var name: String
    /// Вид растения: «Тюльпан».
    var species: String
    /// Влажность почвы, 0…1. Убывает со временем, полив возвращает её
    /// к единице.
    var moisture: Double
    /// За сколько суток почва высыхает досуха от полного полива. У
    /// кактуса это месяцы, у папоротника неделя — отсюда и разная
    /// скорость, с какой убывают проценты.
    var dryingDays: Double
    var addedOn: DateComponents
    var photo: String = "monstera"

    /// Через сколько суток растение попросит воды.
    ///
    /// Считается из влажности, а не хранится: иначе после полива пришлось
    /// бы держать два согласованных числа, и они разошлись бы.
    var daysUntilWatering: Int {
        max(0, Int((moisture * dryingDays).rounded()))
    }

    var thirst: Thirst { Thirst(daysUntilWatering: daysUntilWatering) }

    var moistureLabel: String { "\(Int((moisture * 100).rounded()))%" }

    var wateringLabel: String { Self.wateringLabel(days: daysUntilWatering) }

    var addedLabel: String {
        "Добавлен \(addedOn.day ?? 1).\(addedOn.month ?? 1).\(addedOn.year ?? 2024)"
    }

    /// Сушит почву за прошедшие сутки (дробные — их обычно доли).
    mutating func dry(days: Double) {
        guard dryingDays > 0, days > 0 else { return }
        moisture = max(0, moisture - days / dryingDays)
    }

    /// «Следующий полив сегодня / завтра / через 5 дней».
    static func wateringLabel(days: Int) -> String {
        if days <= 0 { return "Следующий полив сегодня" }
        if days == 1 { return "Следующий полив завтра" }
        return "Следующий полив через \(days) "
            + plural(days, "день", "дня", "дней")
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
    var name: String
    var plants: [Plant]

    /// Средняя влажность по комнате. Пустая комната считается сухой.
    var averageMoisture: Double {
        guard !plants.isEmpty else { return 0 }
        return plants.reduce(0) { $0 + $1.moisture } / Double(plants.count)
    }
}

/// Начальные данные. Первые растения в каждой комнате — из макета, с теми
/// же клличками, процентами и сроками полива; остальные досажены, чтобы
/// сетка не пустовала.
///
/// Скорость сушки подобрана так, чтобы сроки полива сошлись с макетом:
/// у Баксика 89% и 9 суток сушки дают ровно 8 дней до полива.
enum Seed {
    static let owner = "Святослав"

    static let rooms: [Room] = [
        Room(name: "Спальня", plants: [
            Plant(id: "baksik", name: "Баксик", species: "Тюльпан",
                  moisture: 0.89, dryingDays: 9,
                  addedOn: DateComponents(year: 2024, month: 11, day: 2)),
            Plant(id: "pr", name: "Пр", species: "Монстера",
                  moisture: 0.14, dryingDays: 7,
                  addedOn: DateComponents(year: 2025, month: 3, day: 17)),
            Plant(id: "tapok", name: "Тапок", species: "Хлорофитум",
                  moisture: 0.62, dryingDays: 6.5,
                  addedOn: DateComponents(year: 2025, month: 5, day: 12)),
            Plant(id: "boris", name: "Борис", species: "Алоэ",
                  moisture: 0.08, dryingDays: 5,
                  addedOn: DateComponents(year: 2024, month: 9, day: 30)),
            Plant(id: "shuba", name: "Шуба", species: "Папоротник",
                  moisture: 0.45, dryingDays: 6.7,
                  addedOn: DateComponents(year: 2025, month: 7, day: 21)),
        ]),
        Room(name: "Гостиная", plants: [
            Plant(id: "zelenik", name: "Зеленик", species: "Фикус",
                  moisture: 0.30, dryingDays: 7,
                  addedOn: DateComponents(year: 2025, month: 1, day: 9)),
            Plant(id: "gosha", name: "Гоша", species: "Драцена",
                  moisture: 0.73, dryingDays: 8.2,
                  addedOn: DateComponents(year: 2025, month: 2, day: 14)),
            Plant(id: "petrovich", name: "Петрович", species: "Кактус",
                  moisture: 0.21, dryingDays: 57,
                  addedOn: DateComponents(year: 2023, month: 8, day: 5)),
            Plant(id: "sonya", name: "Соня", species: "Орхидея",
                  moisture: 0.11, dryingDays: 9,
                  addedOn: DateComponents(year: 2025, month: 8, day: 19)),
        ]),
        Room(name: "Кухня", plants: [
            Plant(id: "murzik", name: "Мурзик", species: "Монстера",
                  moisture: 0.89, dryingDays: 9,
                  addedOn: DateComponents(year: 2024, month: 12, day: 20)),
            Plant(id: "privet", name: "Привет", species: "Замиокулькас",
                  moisture: 0.14, dryingDays: 7,
                  addedOn: DateComponents(year: 2025, month: 2, day: 4)),
            Plant(id: "lera", name: "Лера", species: "Сансевиерия",
                  moisture: 0.56, dryingDays: 9,
                  addedOn: DateComponents(year: 2025, month: 4, day: 28)),
            Plant(id: "sumka", name: "Сумка", species: "Спатифиллум",
                  moisture: 0.01, dryingDays: 6,
                  addedOn: DateComponents(year: 2025, month: 6, day: 1)),
            Plant(id: "baksik-2", name: "Баксик", species: "Тюльпан",
                  moisture: 0.89, dryingDays: 9,
                  addedOn: DateComponents(year: 2024, month: 11, day: 2)),
            Plant(id: "ukrop", name: "Укроп", species: "Розмарин",
                  moisture: 0.34, dryingDays: 5.9,
                  addedOn: DateComponents(year: 2025, month: 6, day: 7)),
            Plant(id: "baton", name: "Батон", species: "Хойя",
                  moisture: 0.67, dryingDays: 10.4,
                  addedOn: DateComponents(year: 2024, month: 10, day: 11)),
            Plant(id: "kefir", name: "Кефир", species: "Толстянка",
                  moisture: 0.05, dryingDays: 6,
                  addedOn: DateComponents(year: 2025, month: 3, day: 3)),
        ]),
    ]

    /// Поиск по всей квартире: искать растение по имени логично не только
    /// в открытой комнате.
    static func search(_ query: String, in rooms: [Room]) -> [Plant] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return rooms.flatMap(\.plants).filter {
            $0.name.lowercased().contains(q) || $0.species.lowercased().contains(q)
        }
    }
}
