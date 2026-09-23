import Foundation

/// Насколько сухо: ниже 40% тень оранжевая, ниже 20% красная. Силу тени
/// считает `alarm` — плавно, без ступеней.
enum Thirst {
    case calm
    case warn
    case alarm

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

struct Plant: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var species: String
    /// 0…1; полив возвращает к единице.
    var moisture: Double
    /// За сколько суток почва высыхает досуха — свой таймер у каждого
    /// растения.
    var dryingDays: Double
    var addedOn: DateComponents
    var photo: String = "monstera"

    /// Имя снимка хозяина, см. `Shots`; у макетных растений пусто.
    /// Необязательное — так сады прежних сборок читаются как были.
    var shot: String?

    /// Из влажности, а не хранится: два числа рано или поздно разошлись бы.
    var daysUntilWatering: Int {
        max(0, Int((moisture * dryingDays).rounded()))
    }

    var thirst: Thirst { Thirst(moisture: moisture) }

    /// 0 на пороге, 1 у сухой земли. Без ступеней: они читались бы щелчком.
    var alarm: Double {
        guard moisture < Thirst.warnBelow else { return 0 }
        return min(1, (Thirst.warnBelow - moisture) / Thirst.warnBelow)
    }

    var moistureLabel: String { "\(Int((moisture * 100).rounded()))%" }

    var wateringLabel: String { Self.wateringLabel(days: daysUntilWatering) }

    var addedLabel: String {
        "Добавлен \(addedOn.day ?? 1).\(addedOn.month ?? 1).\(addedOn.year ?? 2024)"
    }

    mutating func dry(days: Double) {
        guard dryingDays > 0, days > 0 else { return }
        moisture = max(0, moisture - days / dryingDays)
    }

    /// От клички: у соседних сухих растений пульс не должен совпадать — в
    /// такт это читается поломкой.
    var pulsePhase: Double {
        let sum = id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Double(sum % 97) / 97
    }

    /// С двоеточием вместо «через»: строка короче и читается сроком.
    static func wateringLabel(days: Int) -> String {
        if days <= 0 { return "Следующий полив: сегодня" }
        if days == 1 { return "Следующий полив: завтра" }
        return "Следующий полив: \(days) " + plural(days, "день", "дня", "дней")
    }

    /// Номер случайный: кличек бывает две одинаковых.
    static func new(name: String, species: String, dryingDays: Double,
                    photo: String = "monstera", shot: String? = nil,
                    on day: Date = Date(),
                    calendar: Calendar = .current) -> Plant {
        Plant(id: UUID().uuidString, name: name, species: species,
              moisture: 1, dryingDays: dryingDays,
              addedOn: calendar.dateComponents([.year, .month, .day],
                                               from: day),
              photo: photo, shot: shot)
    }

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

/// Что убрали из сада и откуда. Номер комнаты — на случай, если за отсчёт её
/// не стало, см. `Garden.putBack`.
struct Removal: Equatable {
    var plant: Plant
    var room: String
    var roomIndex: Int
    var index: Int
}

/// Слепок сада для файла.
struct GardenState: Codable {
    var owner: String
    var rooms: [Room]
    var savedAt: Date

    var log: [Watering]

    var since: Date

    init(owner: String, rooms: [Room], savedAt: Date,
         log: [Watering] = [], since: Date = Date()) {
        self.owner = owner
        self.rooms = rooms
        self.savedAt = savedAt
        self.log = log
        self.since = since
    }

    /// Журнала и даты в файлах прежних сборок нет, а синтезированный разбор
    /// на отсутствующий ключ падает — сад начался бы заново.
    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        owner = try box.decode(String.self, forKey: .owner)
        rooms = try box.decode([Room].self, forKey: .rooms)
        savedAt = try box.decode(Date.self, forKey: .savedAt)
        log = try box.decodeIfPresent([Watering].self, forKey: .log) ?? []
        since = try box.decodeIfPresent(Date.self, forKey: .since) ?? savedAt
    }
}

/// Начальные данные. Первые растения в комнатах — из макета, остальные
/// досажены. Сушка подобрана под сроки макета: у Баксика 89% и 9 суток —
/// ровно 8 дней.
enum Seed {
    /// Имени у нового сада нет: приложение здоровается без имени, пока его не
    /// назвали в профиле.
    static let owner = ""

    /// Для кода и таблицы, где без имени нельзя.
    static let stranger = "Садовод"

    static func greeting(for owner: String) -> String {
        let name = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Добро пожаловать!"
            : "Добро пожаловать, \(name)!"
    }

    static var state: GardenState {
        GardenState(owner: owner, rooms: rooms, savedAt: Date(),
                    log: [], since: Date())
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
            Plant(id: "vasilisa", name: "Василиса", species: "Фиалка",
                  moisture: 0.52, dryingDays: 4.5,
                  addedOn: DateComponents(year: 2025, month: 4, day: 3)),
            Plant(id: "kompot", name: "Компот", species: "Бегония",
                  moisture: 0.27, dryingDays: 6.2,
                  addedOn: DateComponents(year: 2025, month: 5, day: 30)),
            Plant(id: "shnurok", name: "Шнурок", species: "Плющ",
                  moisture: 0.71, dryingDays: 8,
                  addedOn: DateComponents(year: 2024, month: 12, day: 14)),
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
            Plant(id: "malysh", name: "Малыш", species: "Пальма",
                  moisture: 0.64, dryingDays: 11,
                  addedOn: DateComponents(year: 2024, month: 7, day: 22)),
            Plant(id: "grusha", name: "Груша", species: "Пеларгония",
                  moisture: 0.18, dryingDays: 5.4,
                  addedOn: DateComponents(year: 2025, month: 5, day: 8)),
            Plant(id: "veter", name: "Ветер", species: "Диффенбахия",
                  moisture: 0.41, dryingDays: 7.6,
                  addedOn: DateComponents(year: 2025, month: 1, day: 26)),
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
            Plant(id: "chesnok", name: "Чеснок", species: "Базилик",
                  moisture: 0.38, dryingDays: 3.8,
                  addedOn: DateComponents(year: 2025, month: 8, day: 2)),
            Plant(id: "banka", name: "Банка", species: "Мята",
                  moisture: 0.75, dryingDays: 4.2,
                  addedOn: DateComponents(year: 2025, month: 7, day: 14)),
            Plant(id: "sneg", name: "Снег", species: "Каланхоэ",
                  moisture: 0.09, dryingDays: 8.8,
                  addedOn: DateComponents(year: 2024, month: 10, day: 5)),
        ]),
    ]

    /// «Сегодня» — тем же счётом, что подпись на карточке.
    static func due(in rooms: [Room]) -> [Plant] {
        rooms.flatMap(\.plants)
            .filter { $0.daysUntilWatering == 0 }
            .sorted { $0.moisture < $1.moisture }
    }

    /// Для Siri: больше пяти имён на слух не держатся — остальные числом.
    static func dueLine(_ plants: [Plant]) -> String {
        let names = plants.map(\.name)
        switch names.count {
        case 0:
            return "Сегодня поливать никого не нужно."
        case 1:
            return "Сегодня ждёт воды \(names[0])."
        case 2 ... 5:
            return "Сегодня ждут воды "
                + names.dropLast().joined(separator: ", ")
                + " и \(names[names.count - 1])."
        default:
            let rest = names.count - 4
            return "Сегодня ждут воды "
                + names.prefix(4).joined(separator: ", ")
                + " и ещё \(rest) "
                + Plant.plural(rest, "растение", "растения", "растений") + "."
        }
    }

    /// Растения по сказанному: голосом кличку говорят в падеже — «Полей
    /// Баксика». Сравниваем по основе, без последней гласной и с запасом на
    /// окончание. Одинаковые клички находятся все — выбирать спросит Siri.
    static func spoken(_ phrase: String, in rooms: [Room]) -> [Plant] {
        let said = words(phrase)
        guard !said.isEmpty else { return [] }
        return rooms.flatMap(\.plants).filter { plant in
            let name = words(plant.name)
            return !name.isEmpty && name.allSatisfy { part in
                said.contains { heard(part, in: $0) }
            }
        }
    }

    /// «е» вместо «ё»: голос их не различает.
    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func heard(_ part: String, in word: String) -> Bool {
        if word == part { return true }
        var stem = part
        if stem.count > 3, let last = stem.last, "аяоеиыуюйь".contains(last) {
            stem.removeLast()
        }
        return word.hasPrefix(stem) && abs(word.count - part.count) <= 2
    }

    static func search(_ query: String, in rooms: [Room]) -> [Plant] {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return [] }
        return rooms.flatMap(\.plants).filter {
            $0.name.lowercased().contains(text)
                || $0.species.lowercased().contains(text)
        }
    }
}
