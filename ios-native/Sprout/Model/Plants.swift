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

    /// Заметка хозяина. Необязательная по той же причине, что и `shot`.
    var note: String?

    /// Чертёж своей объёмной модели — по снимку, по просьбе хозяина; нет —
    /// готовая модель вида, см. `blueprint`.
    var plan: Blueprint?

    /// Скан растения — имя файла USDZ, см. `Scans`. Есть — AR ставит его, а
    /// не модель по чертежу.
    var scan: String?

    /// Подкормка и пересадка. Пусто в садах прежних сборок — тогда сроки
    /// вида, см. `tending`.
    var care: Care?

    /// Отклонённое предложение срока — чтобы не повторять его, см. `Rhythm`.
    var quiet: Double?

    var tending: Care { care ?? .usual(for: blueprint.preset) }

    /// Срок с поправкой на время года — им сохнет земля и считаются подписи.
    var period: Double { dryingDays * Season.stretch }

    /// Из влажности, а не хранится: два числа рано или поздно разошлись бы.
    var daysUntilWatering: Int {
        max(0, Int((moisture * period).rounded()))
    }

    var thirst: Thirst { Thirst(moisture: moisture) }

    /// 0 на пороге, 1 у сухой земли. Без ступеней: они читались бы щелчком.
    var alarm: Double {
        guard moisture < Thirst.warnBelow else { return 0 }
        return min(1, (Thirst.warnBelow - moisture) / Thirst.warnBelow)
    }

    var moistureLabel: String {
        Lang.format("%lld%%", Int((moisture * 100).rounded()))
    }

    var wateringLabel: String { Self.wateringLabel(days: daysUntilWatering) }

    /// Дата — по-местному: у кого «2.11.2024», у кого «11/2/2024».
    var addedLabel: String {
        let day = Calendar(identifier: .gregorian).date(from: addedOn) ?? Date()
        return Lang.format("Добавлен %@", day.formatted(
            Date.FormatStyle(date: .numeric, time: .omitted)
                .locale(Lang.locale)))
    }

    mutating func dry(days: Double) {
        guard dryingDays > 0, days > 0 else { return }
        moisture = max(0, moisture - days / period)
        var tended = tending
        tended.pass(days: days, growing: Season.growing)
        care = tended
    }

    /// Новый срок считается от того же полива: сколько дней земля уже сохла,
    /// столько и остаётся, а влажность пересчитывается под новый срок. Иначе
    /// сухой кактус, переставленный с недели на месяц, так и стоял бы сухим.
    mutating func retime(_ days: Double) {
        guard days > 0, days != dryingDays else { return }
        let dried = (1 - moisture) * dryingDays
        dryingDays = days
        moisture = min(1, max(0, 1 - dried / days))
    }

    /// От клички: у соседних сухих растений пульс не должен совпадать — в
    /// такт это читается поломкой.
    var pulsePhase: Double {
        let sum = id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Double(sum % 97) / 97
    }

    /// С двоеточием вместо «через»: строка короче и читается сроком.
    static func wateringLabel(days: Int) -> String {
        if days <= 0 { return Lang.text("Следующий полив: сегодня") }
        if days == 1 { return Lang.text("Следующий полив: завтра") }
        return Lang.format("Следующий полив: %lld дней", days)
    }

    /// Номер случайный: кличек бывает две одинаковых.
    /// Номер можно дать свой — чертёж модели берёт из него зерно ещё до
    /// посадки.
    static func new(name: String, species: String, dryingDays: Double,
                    photo: String = "monstera", shot: String? = nil,
                    traits: Traits? = nil, id: String = UUID().uuidString,
                    on day: Date = Date(),
                    calendar: Calendar = .current) -> Plant {
        Plant(id: id, name: name, species: species,
              moisture: 1, dryingDays: dryingDays,
              addedOn: calendar.dateComponents([.year, .month, .day],
                                               from: day),
              photo: photo, shot: shot,
              plan: traits.map {
                  Blueprint(preset: .of(species), traits: $0, seed: id)
              })
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

/// Полив, который ещё можно отменить: влажность до него и запись в журнале.
struct Pour: Equatable {
    var plant: Plant.ID
    var name: String
    var moisture: Double
    var when: Date
}

/// Слепок сада для файла.
struct GardenState: Codable {
    var owner: String
    var rooms: [Room]
    var savedAt: Date

    var log: [Watering]

    var since: Date

    /// Метка записи — своя у каждого сохранения: по ней сад узнаёт, что файл
    /// переписал кто-то другой (виджет, кнопка в уведомлении).
    var stamp: String?

    /// Поправка на время года в миг записи — виджету: настроек приложения
    /// он не видит, а сроки должен считать так же.
    var season: Double?

    init(owner: String, rooms: [Room], savedAt: Date,
         log: [Watering] = [], since: Date = Date(), stamp: String? = nil,
         season: Double? = nil) {
        self.owner = owner
        self.rooms = rooms
        self.savedAt = savedAt
        self.log = log
        self.since = since
        self.stamp = stamp
        self.season = season
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
        stamp = try box.decodeIfPresent(String.self, forKey: .stamp)
        season = try box.decodeIfPresent(Double.self, forKey: .season)
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
    static var stranger: String { Lang.text("Садовод") }

    static func greeting(for owner: String) -> String {
        let name = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? Lang.text("Добро пожаловать!")
            : Lang.format("Добро пожаловать, %@!", name)
    }

    static var state: GardenState {
        GardenState(owner: owner, rooms: rooms, savedAt: Date(),
                    log: [], since: Date())
    }

    /// На языке телефона: клички, комнаты и виды макета — тоже слова
    /// каталога. Раз записанный, сад дальше живёт своими словами.
    static let rooms: [Room] = [
        Room(name: Lang.text("Спальня"), plants: [
            Plant(id: "baksik", name: Lang.text("Баксик"), species: Lang.text("Тюльпан"),
                  moisture: 0.89, dryingDays: 9,
                  addedOn: DateComponents(year: 2024, month: 11, day: 2)),
            Plant(id: "pr", name: Lang.text("Пр"), species: Lang.text("Монстера"),
                  moisture: 0.14, dryingDays: 7,
                  addedOn: DateComponents(year: 2025, month: 3, day: 17)),
            Plant(id: "tapok", name: Lang.text("Тапок"), species: Lang.text("Хлорофитум"),
                  moisture: 0.62, dryingDays: 6.5,
                  addedOn: DateComponents(year: 2025, month: 5, day: 12)),
            Plant(id: "boris", name: Lang.text("Борис"), species: Lang.text("Алоэ"),
                  moisture: 0.08, dryingDays: 5,
                  addedOn: DateComponents(year: 2024, month: 9, day: 30)),
            Plant(id: "shuba", name: Lang.text("Шуба"), species: Lang.text("Папоротник"),
                  moisture: 0.45, dryingDays: 6.7,
                  addedOn: DateComponents(year: 2025, month: 7, day: 21)),
            Plant(id: "vasilisa", name: Lang.text("Василиса"), species: Lang.text("Фиалка"),
                  moisture: 0.52, dryingDays: 4.5,
                  addedOn: DateComponents(year: 2025, month: 4, day: 3)),
            Plant(id: "kompot", name: Lang.text("Компот"), species: Lang.text("Бегония"),
                  moisture: 0.27, dryingDays: 6.2,
                  addedOn: DateComponents(year: 2025, month: 5, day: 30)),
            Plant(id: "shnurok", name: Lang.text("Шнурок"), species: Lang.text("Плющ"),
                  moisture: 0.71, dryingDays: 8,
                  addedOn: DateComponents(year: 2024, month: 12, day: 14)),
        ]),
        Room(name: Lang.text("Гостиная"), plants: [
            Plant(id: "zelenik", name: Lang.text("Зеленик"), species: Lang.text("Фикус"),
                  moisture: 0.30, dryingDays: 7,
                  addedOn: DateComponents(year: 2025, month: 1, day: 9)),
            Plant(id: "gosha", name: Lang.text("Гоша"), species: Lang.text("Драцена"),
                  moisture: 0.73, dryingDays: 8.2,
                  addedOn: DateComponents(year: 2025, month: 2, day: 14)),
            Plant(id: "petrovich", name: Lang.text("Петрович"), species: Lang.text("Кактус"),
                  moisture: 0.21, dryingDays: 57,
                  addedOn: DateComponents(year: 2023, month: 8, day: 5)),
            Plant(id: "sonya", name: Lang.text("Соня"), species: Lang.text("Орхидея"),
                  moisture: 0.11, dryingDays: 9,
                  addedOn: DateComponents(year: 2025, month: 8, day: 19)),
            Plant(id: "malysh", name: Lang.text("Малыш"), species: Lang.text("Пальма"),
                  moisture: 0.64, dryingDays: 11,
                  addedOn: DateComponents(year: 2024, month: 7, day: 22)),
            Plant(id: "grusha", name: Lang.text("Груша"), species: Lang.text("Пеларгония"),
                  moisture: 0.18, dryingDays: 5.4,
                  addedOn: DateComponents(year: 2025, month: 5, day: 8)),
            Plant(id: "veter", name: Lang.text("Ветер"), species: Lang.text("Диффенбахия"),
                  moisture: 0.41, dryingDays: 7.6,
                  addedOn: DateComponents(year: 2025, month: 1, day: 26)),
        ]),
        Room(name: Lang.text("Кухня"), plants: [
            Plant(id: "murzik", name: Lang.text("Мурзик"), species: Lang.text("Монстера"),
                  moisture: 0.89, dryingDays: 9,
                  addedOn: DateComponents(year: 2024, month: 12, day: 20)),
            Plant(id: "privet", name: Lang.text("Привет"), species: Lang.text("Замиокулькас"),
                  moisture: 0.14, dryingDays: 7,
                  addedOn: DateComponents(year: 2025, month: 2, day: 4)),
            Plant(id: "lera", name: Lang.text("Лера"), species: Lang.text("Сансевиерия"),
                  moisture: 0.56, dryingDays: 9,
                  addedOn: DateComponents(year: 2025, month: 4, day: 28)),
            Plant(id: "sumka", name: Lang.text("Сумка"), species: Lang.text("Спатифиллум"),
                  moisture: 0.01, dryingDays: 6,
                  addedOn: DateComponents(year: 2025, month: 6, day: 1)),
            Plant(id: "baksik-2", name: Lang.text("Баксик"), species: Lang.text("Тюльпан"),
                  moisture: 0.89, dryingDays: 9,
                  addedOn: DateComponents(year: 2024, month: 11, day: 2)),
            Plant(id: "ukrop", name: Lang.text("Укроп"), species: Lang.text("Розмарин"),
                  moisture: 0.34, dryingDays: 5.9,
                  addedOn: DateComponents(year: 2025, month: 6, day: 7)),
            Plant(id: "baton", name: Lang.text("Батон"), species: Lang.text("Хойя"),
                  moisture: 0.67, dryingDays: 10.4,
                  addedOn: DateComponents(year: 2024, month: 10, day: 11)),
            Plant(id: "kefir", name: Lang.text("Кефир"), species: Lang.text("Толстянка"),
                  moisture: 0.05, dryingDays: 6,
                  addedOn: DateComponents(year: 2025, month: 3, day: 3)),
            Plant(id: "chesnok", name: Lang.text("Чеснок"), species: Lang.text("Базилик"),
                  moisture: 0.38, dryingDays: 3.8,
                  addedOn: DateComponents(year: 2025, month: 8, day: 2)),
            Plant(id: "banka", name: Lang.text("Банка"), species: Lang.text("Мята"),
                  moisture: 0.75, dryingDays: 4.2,
                  addedOn: DateComponents(year: 2025, month: 7, day: 14)),
            Plant(id: "sneg", name: Lang.text("Снег"), species: Lang.text("Каланхоэ"),
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
            return Lang.text("Сегодня поливать никого не нужно.")
        case 1:
            return Lang.format("Сегодня ждёт воды %@.", names[0])
        case 2 ... 5:
            return Lang.format("Сегодня ждут воды %@.", Lang.format(
                "%1$@ и %2$@", names.dropLast().joined(separator: ", "),
                names[names.count - 1]))
        default:
            return Lang.format("Сегодня ждут воды %@.", Lang.format(
                "%1$@ и ещё %2$@", names.prefix(4).joined(separator: ", "),
                Lang.format("%lld растений", names.count - 4)))
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
                || ($0.note?.lowercased().contains(text) ?? false)
        }
    }
}
