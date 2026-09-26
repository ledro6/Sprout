import Foundation

/// «Итоги года сада» — всё, о чём рассказывает презентация, одним разом из
/// журнала, сада и полки наград. Год календарный; пока он не кончился —
/// с января по сегодня.
struct Recap: Sendable {
    var year: Int
    var waterings = 0
    /// Дней, когда поливали хоть что-то.
    var days = 0
    /// Самая длинная череда за год.
    var streak = 0
    /// Самые политые — первым любимчик года.
    var podium: [Star] = []
    var hours = [Int](repeating: 0, count: 24)
    var peakHour: Int?
    /// Доля поливов вовремя среди тех, где известен остаток воды.
    var onTime: Double?
    var months = [Int](repeating: 0, count: 12)
    /// Месяц, когда поливали больше всего, 0…11.
    var bestMonth: Int?
    /// Растений добавлено за год.
    var added = 0
    var plants = 0
    var rooms = 0
    /// Награды, полученные в этом году, — по порядку получения.
    var awards: [Rank] = []
    /// Дни года с поливом, от нуля, — для кольца года.
    var lit: Set<Int> = []
    /// Дней в году: кольцу нужно знать, високосный ли он.
    var length = 365

    /// Слайды презентации — по порядку. Про что рассказать нечего, того
    /// слайда нет: пустой пьедестал хуже никакого.
    enum Slide: Hashable, Sendable {
        case intro, waterings, favorite, podium, streak, rhythm, aim, months,
             garden, awards, outro
    }

    var deck: [Slide] {
        guard !empty else { return [.intro, .garden, .outro] }
        var deck: [Slide] = [.intro, .waterings]
        if favorite != nil { deck.append(.favorite) }
        if podium.count >= 3 { deck.append(.podium) }
        if streak >= 2 { deck.append(.streak) }
        if peakHour != nil { deck.append(.rhythm) }
        if onTime != nil { deck.append(.aim) }
        if bestMonth != nil { deck.append(.months) }
        deck.append(.garden)
        if !awards.isEmpty { deck.append(.awards) }
        deck.append(.outro)
        return deck
    }

    /// Растение в итогах — с тем, чем его показать.
    struct Star: Equatable, Sendable {
        var id: Plant.ID
        var name: String
        var species: String
        var photo: String
        var shot: String?
        var count: Int
    }

    /// Садовник по часу, когда поливают чаще всего.
    enum Persona: Sendable, Equatable {
        case lark, day, evening, owl

        init(hour: Int) {
            switch hour {
            case 4 ..< 11: self = .lark
            case 11 ..< 17: self = .day
            case 17 ..< 22: self = .evening
            default: self = .owl
            }
        }

        var title: String {
            switch self {
            case .lark: Lang.text("Жаворонок")
            case .day: Lang.text("Дневной садовник")
            case .evening: Lang.text("Вечерний садовник")
            case .owl: Lang.text("Сова")
            }
        }

        var line: String {
            switch self {
            case .lark: Lang.text("Сад просыпается вместе с вами — и сразу пьёт.")
            case .day: Lang.text("Поливаете между делами, при свете дня.")
            case .evening: Lang.text("Вечер — время для сада: день позади, лейка в руке.")
            case .owl: Lang.text("Весь дом спит, а у растений — ужин.")
            }
        }
    }

    var persona: Persona? { peakHour.map(Persona.init(hour:)) }

    var favorite: Star? { podium.first }

    /// Воды ушло — оценкой: стакан на полив.
    static let glass = 0.25

    var liters: Double { Double(waterings) * Self.glass }

    /// Пустой год — рассказывать нечего, кроме приглашения.
    var empty: Bool { waterings == 0 }

    static func of(_ log: [Watering], rooms: [Room], awards: [Rank: Date],
                   year: Int, now: Date = Date(),
                   calendar: Calendar = .current) -> Recap {
        var recap = Recap(year: year)
        let inside = log.filter {
            calendar.component(.year, from: $0.when) == year && $0.when <= now
        }.sorted { $0.when < $1.when }
        recap.waterings = inside.count
        recap.days = Set(inside.map { calendar.startOfDay(for: $0.when) }).count
        recap.streak = Trophies.dayRuns(inside, calendar: calendar).best
        for entry in inside {
            recap.hours[calendar.component(.hour, from: entry.when)] += 1
            recap.months[calendar.component(.month, from: entry.when) - 1] += 1
            if let day = calendar.ordinality(of: .day, in: .year,
                                             for: entry.when) {
                recap.lit.insert(day - 1)
            }
        }
        if let january = calendar.date(from: DateComponents(year: year,
                                                            month: 1, day: 1)),
           let days = calendar.range(of: .day, in: .year, for: january) {
            recap.length = days.count
        }
        if let most = recap.hours.max(), most > 0 {
            recap.peakHour = recap.hours.firstIndex(of: most)
        }
        if let most = recap.months.max(), most > 0 {
            recap.bestMonth = recap.months.firstIndex(of: most)
        }
        let aim = Almanac.Aim(inside)
        if aim.known > 0 { recap.onTime = aim.share(.onTime) }
        // Любимчик — из тех, кто ещё в саду: ушедшему нечего показать.
        let counts = Dictionary(grouping: inside, by: \.plant)
            .mapValues(\.count)
        let order = rooms.flatMap(\.plants)
        recap.podium = order.compactMap { plant -> Star? in
            guard let count = counts[plant.id] else { return nil }
            return Star(id: plant.id, name: plant.name,
                        species: plant.species, photo: plant.photo,
                        shot: plant.shot, count: count)
        }
        .enumerated()
        .sorted { $0.element.count != $1.element.count
            ? $0.element.count > $1.element.count : $0.offset < $1.offset }
        .prefix(3)
        .map(\.element)
        recap.added = order.count { $0.addedOn.year == year }
        recap.plants = order.count
        recap.rooms = rooms.count
        recap.awards = awards
            .filter { calendar.component(.year, from: $0.value) == year }
            .sorted { $0.value != $1.value ? $0.value < $1.value
                : $0.key.id < $1.key.id }
            .map(\.key)
        return recap
    }

    /// Мелодия года для презентации: такт на месяц, шкатулкой, как музыка
    /// сфер. Чем больше поливали в месяце, тем выше и гуще его такт; тихий
    /// месяц звучит одной нотой. Своя у каждого сада — как свой год.
    func melody(beat: Double = 0.3) -> [Spheres.Note] {
        let scale = [0, 2, 4, 7, 9]
        let busiest = Double(max(months.max() ?? 0, 1))
        var notes: [Spheres.Note] = []
        for (month, count) in months.enumerated() {
            let share = Double(count) / busiest
            // Восемь долей на такт; нот в такте — от одной до восьми.
            let voices = count == 0 ? 1 : 2 + Int((share * 6).rounded())
            let lift = Int((share * 4).rounded())
            for step in 0 ..< voices {
                let slot = step * 8 / voices
                // Арпеджио вверх и обратно: волна, а не лесенка.
                let wave = [0, 2, 4, 3, 1, 3, 5, 2][(step + month) % 8]
                let degree = wave + lift
                let semitone = scale[degree % scale.count]
                    + 12 * (degree / scale.count)
                notes.append(Spheres.Note(
                    at: Double(month * 8 + slot) * beat,
                    pitch: 220 * pow(2, Double(semitone) / 12),
                    pan: step % 2 == 0 ? -0.3 : 0.3))
            }
        }
        return notes
    }

    /// Сколько длится мелодия: двенадцать тактов по восемь долей.
    static func length(beat: Double = 0.3) -> Double { 12 * 8 * beat }
}
