import Foundation

/// Насколько сухо растению — от этого цвет тени под карточкой.
///
/// Пороги в долях влажности: ниже 40% тень появляется оранжевой, ниже
/// 20% краснеет. Силу тени этот тип не считает, для неё есть `alarm`:
/// она растёт с каждым процентом, а не ступенями, и на границе 20%
/// меняется только цвет, тогда как яркость идёт дальше ровно.
enum Thirst {
    /// Влаги хватает, карточка спокойная.
    case calm
    /// Пора задуматься — оранжевая тень.
    case warn
    /// Земля сухая — красная.
    case alarm

    /// Ниже этой влажности появляется тревога.
    static let warnBelow = 0.4
    /// Ниже этой она краснеет.
    static let alarmBelow = 0.2

    init(moisture: Double) {
        switch moisture {
        case ..<Self.alarmBelow: self = .alarm
        case ..<Self.warnBelow: self = .warn
        default: self = .calm
        }
    }
}

struct Plant: Identifiable, Hashable, Codable {
    let id: String
    /// Кличка, которую дал хозяин: «Баксик», «Сумка». Меняется.
    var name: String
    /// Вид растения: «Тюльпан».
    var species: String
    /// Влажность почвы, 0…1. Убывает со временем, полив возвращает её к
    /// единице.
    var moisture: Double
    /// За сколько суток почва высыхает досуха от полного полива.
    ///
    /// Здесь и живёт «у каждого растения свой таймер»: у кактуса это
    /// месяцы, у папоротника неделя, и проценты у них убывают с разной
    /// скоростью. Часы у сада одни на всех, а темп у каждого свой.
    var dryingDays: Double
    var addedOn: DateComponents
    var photo: String = "monstera"

    /// Через сколько суток растение попросит воды.
    ///
    /// Считается из влажности, а не хранится: иначе после полива пришлось
    /// бы держать два согласованных числа, и рано или поздно они
    /// разошлись бы — 100% и «полить завтра».
    var daysUntilWatering: Int {
        max(0, Int((moisture * dryingDays).rounded()))
    }

    var thirst: Thirst { Thirst(moisture: moisture) }

    /// Сила тревоги, 0…1: ноль на пороге, единица у сухой земли.
    ///
    /// Растёт непрерывно, поэтому тень заметно набирает яркость с каждым
    /// процентом. Ступеней здесь намеренно нет: ступени читались бы
    /// щелчком, а не подсыханием.
    var alarm: Double {
        guard moisture < Thirst.warnBelow else { return 0 }
        return min(1, (Thirst.warnBelow - moisture) / Thirst.warnBelow)
    }

    var moistureLabel: String { "\(Int((moisture * 100).rounded()))%" }

    var wateringLabel: String { Self.wateringLabel(days: daysUntilWatering) }

    var addedLabel: String {
        "Добавлен \(addedOn.day ?? 1).\(addedOn.month ?? 1).\(addedOn.year ?? 2024)"
    }

    /// Сушит почву за прошедшие сутки — обычно за их доли.
    mutating func dry(days: Double) {
        guard dryingDays > 0, days > 0 else { return }
        moisture = max(0, moisture - days / dryingDays)
    }

    /// Сдвиг фазы пульса, 0…1.
    ///
    /// Считается от клички, а не берётся общий: у соседних сухих
    /// растений фазы не должны совпасть. Дышащие в такт читаются одной
    /// поломкой на весь экран, вразнобой — живой грядкой.
    var pulsePhase: Double {
        let sum = id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Double(sum % 97) / 97
    }

    /// «Следующий полив: сегодня / завтра / через 5 дней».
    ///
    /// С двоеточием: подпись живёт в одну строку, а двоеточие даёт глазу
    /// зацепку там, где иначе была бы длинная фраза без пауз.
    static func wateringLabel(days: Int) -> String {
        if days <= 0 { return "Следующий полив: сегодня" }
        if days == 1 { return "Следующий полив: завтра" }
        return "Следующий полив: через \(days) "
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

struct Room: Identifiable, Hashable, Codable {
    var id: String { name }
    var name: String
    var plants: [Plant]
}

/// Всё, что сад помнит между запусками.
///
/// Отдельный тип, а не сам сад: сад — наблюдаемый класс, живущий в
/// интерфейсе, а это простой слепок, который умеет лечь в файл.
struct GardenState: Codable {
    var owner: String
    var rooms: [Room]
    /// Когда слепок сделали.
    var savedAt: Date
}

/// Начальные данные. Первые растения в каждой комнате — из макета, с теми
/// же кличками и процентами; остальные досажены, чтобы сетка не пустовала
/// и было на чём смотреть прокрутку.
///
/// Скорость сушки подобрана так, чтобы сроки полива сошлись с макетом: у
/// Баксика 89% и 9 суток сушки дают ровно 8 дней до полива.
enum Seed {
    static let owner = "Святослав"

    static var state: GardenState {
        GardenState(owner: owner, rooms: rooms, savedAt: Date())
    }

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
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return [] }
        return rooms.flatMap(\.plants).filter {
            $0.name.lowercased().contains(text)
                || $0.species.lowercased().contains(text)
        }
    }
}
