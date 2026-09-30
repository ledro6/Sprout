import Foundation

/// «Спросить сад» без самой модели: что рассказать ей о саде и какие
/// вопросы подсказать хозяину. Сеанс, инструменты и разговор — в
/// `Talk.swift`: FoundationModels без Apple не собрать, а это собирается и
/// проверяется где угодно.
///
/// Сведения для модели — по-английски, как и наставления (см. `Muse`), а
/// клички, виды, комнаты и заметки — как их записал хозяин: отвечает модель
/// на языке приложения и зовёт растения их именами.
enum Sage {
    /// Больше растений — и строки о каждом съели бы окно модели: оно на весь
    /// разговор несколько тысяч слов. Тогда в комнатах — только клички, а
    /// подробности — по кличке.
    static let listed = 40

    /// Длиннее вопрос обрезается, а не отвергается.
    static let longest = 500

    /// Наставление сеанса. Сведения о саде — не здесь, а у инструментов:
    /// простыня в наставлении съела бы окно уже на втором вопросе.
    static func instructions(language: String, focus: Plant?) -> String {
        // Кнопка — словами приложения: так модель и назовёт её хозяину.
        let check = Lang.text("Что с ним?")
        var text = """
        You are the garden assistant in Sprout, an app for caring for \
        houseplants. Always answer in \(language), briefly: two to five \
        short sentences, no headings or tables. Learn about the user's \
        garden only from the tools: gardenOverview lists the rooms, the \
        plants and who needs water today or tomorrow; plantDetails tells \
        about one plant by its nickname. Never invent plants, dates or \
        numbers that the tools did not give. For general care give careful, \
        widely accepted advice and say when you are not sure. If the \
        question is about a disease, pests, spots or yellow or falling \
        leaves, also advise checking the plant from a photo with the \
        "\(check)" button on the plant's screen. Do not \
        greet, apologize or explain what you are doing.
        """
        if let focus {
            text += """
             The user opened this chat from the screen of the plant \
            "\(focus.name)" (\(focus.species)): questions without a nickname \
            are about this plant.
            """
        }
        return text
    }

    /// Весь сад коротко: кого полить сегодня и завтра, чей уход подошёл и по
    /// строке на растение. Сроки — те же, что на карточках.
    static func overview(_ rooms: [Room], now: Date = Date(),
                         calendar: Calendar = .current) -> String {
        let plants = rooms.flatMap(\.plants)
        guard !plants.isEmpty else { return empty }
        let season = Season.growing ? "It is the growing season."
            : "It is the rest season: the app pauses feeding."
        let tomorrow = plants.filter { $0.daysUntilWatering == 1 }
        var lines = [
            "The garden: \(plants.count) plants in \(rooms.count) rooms. "
                + "Today is \(day(now, calendar: calendar)). \(season)",
            "Needs water today: " + roll(Seed.due(in: rooms), rooms: rooms),
            "Needs water tomorrow: " + roll(tomorrow, rooms: rooms),
        ]
        let chores = plants.compactMap { plant -> String? in
            let due = duties(plant)
            guard !due.isEmpty else { return nil }
            return quoted(plant.name) + " — " + due.joined(separator: ", ")
        }
        if !chores.isEmpty {
            lines.append("Care due now: " + chores.joined(separator: "; "))
        }
        lines.append("Rooms:")
        let brief = plants.count > listed
        for room in rooms {
            let names = room.plants.map { brief ? quoted($0.name) : line($0) }
            let list = names.isEmpty ? "no plants"
                : names.joined(separator: "; ")
            lines.append(room.name + ": " + list)
        }
        return lines.joined(separator: "\n")
    }

    /// Подробности по кличке: вид, комната, влажность, поливы, уход, датчик,
    /// питомцы и заметка. Одинаковых кличек бывает несколько — тогда все.
    static func details(_ nickname: String, in rooms: [Room], log: [Watering],
                        focus: Plant.ID? = nil, now: Date = Date(),
                        calendar: Calendar = .current) -> String {
        let found = find(nickname, in: rooms, focus: focus)
        guard !found.isEmpty else {
            let names = rooms.flatMap(\.plants).prefix(listed)
                .map { quoted($0.name) }
            guard !names.isEmpty else { return empty }
            return "There is no plant \(quoted(nickname)) in the garden. "
                + "The plants are: " + names.joined(separator: ", ") + "."
        }
        let cards = found.prefix(3).map { plant in
            card(plant, room: rooms.first { $0.plants.contains(plant) }?.name,
                 log: log, now: now, calendar: calendar)
        }
        guard found.count > 1 else { return cards[0] }
        return "There are \(found.count) plants with this nickname.\n\n"
            + cards.joined(separator: "\n\n")
    }

    /// Растения по кличке, как её ни напиши: в кавычках, в падеже («у
    /// Баксика» — по правилам Siri, см. `Seed.spoken`), или вид вместо
    /// клички — «монстера» найдёт монстер сада. Пусто и лист открыт с
    /// растения — это растение. Среди тёзок растение листа — оно одно.
    static func find(_ nickname: String, in rooms: [Room],
                     focus: Plant.ID? = nil) -> [Plant] {
        let plants = rooms.flatMap(\.plants)
        let key = fold(nickname)
        var found: [Plant]
        if key.isEmpty {
            found = plants.filter { $0.id == focus }
        } else {
            found = plants.filter { fold($0.name) == key }
            if found.isEmpty { found = Seed.spoken(nickname, in: rooms) }
            if found.isEmpty, let kind = Preset.known(key) {
                found = plants.filter { Preset.known($0.species) == kind }
            }
        }
        if let focus, found.contains(where: { $0.id == focus }) {
            return found.filter { $0.id == focus }
        }
        return found
    }

    /// Вопросы-подсказки. Кличка — в кавычках и с «растение»: так она
    /// остаётся в именительном падеже, склонять клички приложение не умеет.
    static func prompts(about plant: Plant?) -> [String] {
        var prompts = [Lang.text("Кого полить сегодня?")]
        if let plant {
            prompts.append(Lang.format("Почему желтеют листья у растения «%@»?",
                                       plant.name))
            prompts.append(Lang.format("Как пересадить растение «%@»?",
                                       plant.name))
        }
        return prompts
    }

    /// О ком подсказать вопросы, когда лист открыт не с растения, — о самом
    /// сухом: ему совет нужнее всех.
    static func example(in rooms: [Room]) -> Plant? {
        rooms.flatMap(\.plants).min { $0.moisture < $1.moisture }
    }

    /// Вопрос — как написан, без пробелов по краям; пустой — не вопрос.
    static func question(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(longest))
    }

    // MARK: - Строки

    private static let empty = "The garden is empty: there are no plants yet."

    /// Растение строкой обзора: кличка, вид, влажность и полив.
    private static func line(_ plant: Plant) -> String {
        "\(quoted(plant.name)) \(plant.species), \(percent(plant.moisture)) "
            + "moisture, water \(when(plant.daysUntilWatering))"
    }

    private static func card(_ plant: Plant, room: String?, log: [Watering],
                             now: Date, calendar: Calendar) -> String {
        let diary = Diary.of(log, plant: plant.id)
        let added = calendar.date(from: plant.addedOn) ?? now
        let place = room.map { ", room \($0)" } ?? ""
        let measured = plant.sensor?.last != nil ? "from a soil sensor"
            : "estimated by the app from the watering period"
        let last = diary.entries.first.map {
            ago($0, now: now, calendar: calendar)
        } ?? "not recorded"
        var lines = [
            "\(quoted(plant.name)): species \(plant.species)\(place), "
                + "in the garden since \(day(added, calendar: calendar)).",
            "Soil moisture \(percent(plant.moisture)), \(measured).",
            "Watering: every \(number(plant.dryingDays)) days; next watering "
                + "\(when(plant.daysUntilWatering)).",
            "Last watered: \(last); waterings recorded: \(diary.total).",
        ]
        let tending = plant.tending
        if let every = tending.feedEvery {
            let next = tending.feedDue ? "due now"
                : "next " + soon(tending.feedIn ?? 0)
            lines.append("Feeding: every \(number(every)) days; \(next).")
        } else {
            lines.append("Feeding: no reminders.")
        }
        if let every = tending.repotEvery {
            let next = tending.repotDue ? "due now"
                : "next " + soon(tending.repotIn ?? 0)
            lines.append("Repotting: every \(Care.months(days: every)) "
                         + "months; \(next).")
        } else {
            lines.append("Repotting: no reminders.")
        }
        for duty in tending.errands {
            guard let every = tending.every(duty) else { continue }
            let next = tending.due(duty) ? "due now"
                : "next " + soon(tending.left(duty) ?? 0)
            lines.append("Care, \(chore(duty)): every \(number(every)) days; "
                         + "\(next).")
        }
        if let sensor = plant.sensor {
            let readings = sensor.last == nil ? ", no readings yet" : ""
            lines.append("Soil sensor: \(sensor.name)\(readings).")
        }
        if let danger = Toxicity.of(plant.species) {
            lines.append("Pets: \(pets(danger)).")
        }
        if let note = plant.note {
            lines.append("The owner's note: \"\(note.prefix(300))\"")
        }
        return lines.joined(separator: "\n")
    }

    /// Пусто — «nobody», чтобы модель не додумывала.
    private static func roll(_ plants: [Plant], rooms: [Room]) -> String {
        guard !plants.isEmpty else { return "nobody." }
        return plants.prefix(listed).map { plant in
            let room = rooms.first { $0.plants.contains(plant) }?.name
            return quoted(plant.name) + (room.map { " (\($0))" } ?? "")
        }
        .joined(separator: ", ") + "."
    }

    private static func duties(_ plant: Plant) -> [String] {
        let tending = plant.tending
        var due: [String] = []
        if tending.feedDue { due.append("feeding") }
        if tending.repotDue { due.append("repotting") }
        due += tending.errands.filter { tending.due($0) }.map(chore)
        return due
    }

    private static func chore(_ duty: Duty) -> String {
        switch duty {
        case .mist: "misting"
        case .turn: "turning to the light"
        case .wipe: "wiping the leaves"
        }
    }

    private static func pets(_ danger: Toxicity) -> String {
        switch danger {
        case .safe: "safe for cats and dogs"
        case .toxic: "toxic to cats and dogs"
        case .lily: "deadly to cats"
        case .deadly: "deadly to cats and dogs"
        }
    }

    /// Дни — как на карточке: «сегодня», «завтра», «через 8 дней».
    private static func when(_ days: Int) -> String {
        switch days {
        case ..<1: "today"
        case 1: "tomorrow"
        default: "in \(days) days"
        }
    }

    /// Срок ухода: до месяца — днями, дальше — месяцами.
    private static func soon(_ days: Double) -> String {
        let whole = Int(days.rounded())
        guard whole >= 30 else { return when(whole) }
        return "in \(max(1, Care.months(days: days))) months"
    }

    private static func ago(_ moment: Date, now: Date,
                            calendar: Calendar) -> String {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: moment),
            to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        default: return "\(days) days ago"
        }
    }

    /// Дата по-английски — сведения для модели, а не для глаз.
    private static func day(_ date: Date, calendar: Calendar) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted,
                                        calendar: calendar,
                                        timeZone: calendar.timeZone)
            .locale(Locale(identifier: "en_US_POSIX")))
    }

    private static func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }

    /// «9», «6.5» — без хвоста нулей.
    private static func number(_ value: Double) -> String {
        let tenth = (value * 10).rounded() / 10
        return tenth == tenth.rounded() ? "\(Int(tenth))" : "\(tenth)"
    }

    private static func quoted(_ name: String) -> String { "\"\(name)\"" }

    /// Для сравнения кличек: без регистра, кавычек и значков над буквами —
    /// «ё» и «е» не различаются, как и у Siri.
    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive],
                     locale: nil)
            .trimmingCharacters(in: CharacterSet(
                charactersIn: " \n\t.,!?«»\"'“”„"))
    }
}
