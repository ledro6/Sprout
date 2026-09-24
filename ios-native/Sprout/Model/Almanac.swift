import Foundation

/// Статистика сада за период: считается из журнала поливов и сада, как
/// `Score`, а не копится счётчиками. Два рода времени не смешиваются:
/// привычки — поливы по дням, часам и дням недели — в настоящем времени
/// журнала; точность — по остатку воды в миг полива; прогноз — в днях сада,
/// тех же, что на карточках.
struct Almanac: Sendable {
    /// Неделя и месяц — по дням, год — по месяцам; «всё время» — по дням,
    /// пока саду меньше полутора месяцев, потом по месяцам.
    enum Period: String, CaseIterable, Identifiable, Sendable {
        case week, month, year, all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .week: Lang.text("Неделя")
            case .month: Lang.text("Месяц")
            case .year: Lang.text("Год")
            case .all: Lang.text("Всё время")
            }
        }
    }

    /// Столбик графика: день или месяц и поливы в нём.
    struct Bar: Identifiable, Hashable, Sendable {
        var start: Date
        var count: Int

        var id: Date { start }
    }

    /// Сколько воды оставалось в земле, когда поливали. Зоны — те же, что у
    /// тени карточки: без тени — заранее, оранжевая — вовремя, красная — в
    /// последний момент, сухая земля — пересохло.
    struct Aim: Hashable, Sendable {
        enum Zone: Int, CaseIterable, Identifiable, Sendable {
            case early, onTime, lastMoment, dry

            var id: Int { rawValue }

            var title: String {
                switch self {
                case .early: Lang.text("Заранее")
                case .onTime: Lang.text("Вовремя")
                case .lastMoment: Lang.text("В последний момент")
                case .dry: Lang.text("Пересохло")
                }
            }

            /// Что было в земле — подпись под названием.
            var range: String {
                switch self {
                case .early: Lang.text("40% воды и больше")
                case .onTime: Lang.text("20–40% воды")
                case .lastMoment: Lang.text("меньше 20% воды")
                case .dry: Lang.text("земля сухая")
                }
            }
        }

        /// Досуха — меньше процента: столько не видно и на карточке.
        static let dryBelow = 0.01

        private(set) var counts = [0, 0, 0, 0]

        /// Десять корзин по десять процентов: 0–10, …, 90–100.
        private(set) var bins = Array(repeating: 0, count: 10)

        /// Обычный остаток — медиана: один полив «на всякий случай» среднее
        /// сдвинул бы, а медиану нет.
        private(set) var typical: Double?

        var known: Int { counts.reduce(0, +) }

        func count(_ zone: Zone) -> Int { counts[zone.rawValue] }

        func share(_ zone: Zone) -> Double {
            known == 0 ? 0 : Double(count(zone)) / Double(known)
        }

        /// Зона, куда пришлось больше всего поливов; при равенстве — та,
        /// что ближе к «вовремя».
        var usual: Zone? {
            guard known > 0 else { return nil }
            let order: [Zone] = [.onTime, .lastMoment, .early, .dry]
            return order.max { count($0) < count($1) }
        }

        static func zone(_ left: Double) -> Zone {
            switch left {
            case ..<dryBelow: .dry
            case ..<Thirst.alarmBelow: .lastMoment
            case ..<Thirst.warnBelow: .onTime
            default: .early
            }
        }

        init() {}

        /// Записи прежних сборок без остатка воды не считаются: гадать о них
        /// нечем.
        init(_ entries: [Watering]) {
            let lefts = entries.compactMap(\.left).map { min(max($0, 0), 1) }
            for left in lefts {
                counts[Self.zone(left).rawValue] += 1
                // Запас на двоичную дробь: 0.3 × 10 выходит 2.999…
                bins[min(Int(left * 10 + 1e-9), 9)] += 1
            }
            guard !lefts.isEmpty else { return }
            let sorted = lefts.sorted()
            let middle = sorted.count / 2
            typical = sorted.count % 2 == 1 ? sorted[middle]
                : (sorted[middle - 1] + sorted[middle]) / 2
        }
    }

    /// День недели с поливами. Номер — как у календаря: 1 — воскресенье.
    struct Weekday: Identifiable, Hashable, Sendable {
        var number: Int
        var symbol: String
        var name: String
        var count: Int

        var id: Int { number }
    }

    struct RoomLine: Identifiable, Hashable, Sendable {
        var name: String
        var plants: Int
        /// Средняя влажность сейчас; пусто — растений нет.
        var moisture: Double?
        var waterings: Int
        /// Доля поливов вовремя; пусто — судить не по чему.
        var onTime: Double?

        var id: String { name }
    }

    struct PlantLine: Identifiable, Hashable, Sendable {
        var id: Plant.ID
        var name: String
        var species: String
        var room: String
        var moisture: Double
        /// Дней сада до полива — тем же счётом, что на карточке.
        var due: Int
        var waterings: Int
        var total: Int
        var last: Date?
        var typical: Double?
    }

    /// Сад в эту минуту.
    struct Now: Hashable, Sendable {
        var calm = 0
        var warn = 0
        var alarm = 0
        var average: Double?
        /// Влажность каждого — от самого сухого: полоска на обзоре.
        var levels: [Double] = []
        var driest: String?

        var count: Int { calm + warn + alarm }

        /// Доля довольных — кольцо на обзоре.
        var content: Double {
            count == 0 ? 0 : Double(calm) / Double(count)
        }
    }

    /// День сада в прогнозе: кому в этот день понадобится вода.
    struct Ahead: Identifiable, Hashable, Sendable {
        var offset: Int
        var plants: [Plant.ID] = []
        var names: [String] = []

        var id: Int { offset }
        var count: Int { plants.count }
    }

    var period: Period = .week
    var start = Date(timeIntervalSince1970: 0)
    var byMonth = false
    var bars: [Bar] = []
    var total = 0
    /// Тот же срок перед периодом; у «всего времени» сравнивать не с чем.
    var previous: Int?
    /// Дней с поливом и дней в периоде.
    var active = 0
    var length = 1
    var streak = 0
    var best = 0
    var aim = Aim()
    var hours = Array(repeating: 0, count: 24)
    var weekdays: [Weekday] = []
    var rooms: [RoomLine] = []
    var plants: [PlantLine] = []
    var now = Now()
    var ahead: [Ahead] = []

    /// Прогноз — на две недели сада.
    static let horizon = 14

    /// «Всё время» по дням — пока саду меньше стольких дней.
    static let dailyUpTo = 45

    /// Разница с прошлым периодом; пусто — сравнивать не с чем.
    var change: Int? { previous.map { total - $0 } }

    /// Час, в который поливают чаще всего; пусто — поливов не было.
    var peakHour: Int? {
        guard let most = hours.max(), most > 0 else { return nil }
        return hours.firstIndex(of: most)
    }

    var peakDay: Weekday? {
        guard let most = weekdays.map(\.count).max(), most > 0 else {
            return nil
        }
        return weekdays.first { $0.count == most }
    }

    /// Больше всего поливов в одном столбике — потолок графика.
    var tallest: Int { bars.map(\.count).max() ?? 0 }

    /// Календарь и «сейчас» — снаружи: прогон модели не должен зависеть от
    /// часового пояса и дня запуска.
    static func of(_ log: [Watering], rooms: [Room], period: Period,
                   since: Date, now moment: Date = Date(),
                   calendar: Calendar = .current) -> Almanac {
        var book = Almanac()
        book.period = period
        let today = calendar.startOfDay(for: moment)
        let (start, byMonth) = window(period, log: log, since: since,
                                      today: today, calendar: calendar)
        book.start = start
        book.byMonth = byMonth
        let inside = log.filter { $0.when >= start && $0.when <= moment }
        book.total = inside.count
        book.length = max(1, days(from: start, to: today,
                                  calendar: calendar) + 1)
        if let back = before(period, start: start, calendar: calendar) {
            book.previous = log.count { $0.when >= back && $0.when < start }
        }
        book.active = Set(inside.map { calendar.startOfDay(for: $0.when) })
            .count
        let score = Score.of(log, rooms: rooms, now: moment,
                             calendar: calendar)
        book.streak = score.streak
        book.best = score.best
        book.bars = bars(inside, from: start, to: today, byMonth: byMonth,
                         calendar: calendar)
        book.aim = Aim(inside)
        for entry in inside {
            book.hours[calendar.component(.hour, from: entry.when)] += 1
        }
        book.weekdays = weekdays(inside, calendar: calendar)
        book.rooms = rooms.map { room in
            let ids = Set(room.plants.map(\.id))
            let mine = inside.filter { ids.contains($0.plant) }
            let aim = Aim(mine)
            let levels = room.plants.map(\.moisture)
            return RoomLine(
                name: room.name, plants: room.plants.count,
                moisture: levels.isEmpty ? nil
                    : levels.reduce(0, +) / Double(levels.count),
                waterings: mine.count,
                onTime: aim.known == 0 ? nil : aim.share(.onTime))
        }
        let byPlant = Dictionary(grouping: log, by: \.plant)
        book.plants = rooms.flatMap { room in
            room.plants.map { plant in
                let all = byPlant[plant.id] ?? []
                return PlantLine(
                    id: plant.id, name: plant.name, species: plant.species,
                    room: room.name, moisture: plant.moisture,
                    due: plant.daysUntilWatering,
                    waterings: all.count { $0.when >= start
                        && $0.when <= moment },
                    total: all.count,
                    last: all.map(\.when).max(),
                    typical: Aim(all).typical)
            }
        }
        book.now = now(rooms)
        book.ahead = ahead(rooms)
        return book
    }

    /// Начало периода и шаг графика. Неделя — семь дней с сегодняшним, месяц
    /// — тридцать; год — двенадцать месяцев с текущим, чтобы столбики были
    /// целыми месяцами.
    static func window(_ period: Period, log: [Watering], since: Date,
                       today: Date, calendar: Calendar) -> (Date, Bool) {
        switch period {
        case .week:
            return (calendar.date(byAdding: .day, value: -6, to: today)
                        ?? today, false)
        case .month:
            return (calendar.date(byAdding: .day, value: -29, to: today)
                        ?? today, false)
        case .year:
            let month = calendar.dateInterval(of: .month, for: today)?.start
                ?? today
            return (calendar.date(byAdding: .month, value: -11, to: month)
                        ?? month, true)
        case .all:
            let first = ([since] + log.map(\.when)).min() ?? today
            let start = min(calendar.startOfDay(for: first), today)
            guard days(from: start, to: today, calendar: calendar)
                    >= dailyUpTo else { return (start, false) }
            return (calendar.dateInterval(of: .month, for: start)?.start
                        ?? start, true)
        }
    }

    /// Начало прошлого такого же периода.
    private static func before(_ period: Period, start: Date,
                               calendar: Calendar) -> Date? {
        switch period {
        case .week: calendar.date(byAdding: .day, value: -7, to: start)
        case .month: calendar.date(byAdding: .day, value: -30, to: start)
        case .year: calendar.date(byAdding: .month, value: -12, to: start)
        case .all: nil
        }
    }

    /// По календарю, а не делением секунд: сутки бывают в 23 и 25 часов.
    private static func days(from start: Date, to end: Date,
                             calendar: Calendar) -> Int {
        max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    /// Пустые дни тоже: без них график врал бы о промежутках.
    static func bars(_ entries: [Watering], from start: Date, to today: Date,
                     byMonth: Bool, calendar: Calendar) -> [Bar] {
        let unit: Calendar.Component = byMonth ? .month : .day
        var counts: [Date: Int] = [:]
        for entry in entries {
            let key = calendar.dateInterval(of: unit, for: entry.when)?.start
                ?? calendar.startOfDay(for: entry.when)
            counts[key, default: 0] += 1
        }
        var out: [Bar] = []
        var cursor = calendar.dateInterval(of: unit, for: start)?.start
            ?? start
        // Потолок — на случай сломанного календаря: цикл не должен виснуть.
        while cursor <= today, out.count < 400 {
            out.append(Bar(start: cursor, count: counts[cursor] ?? 0))
            guard let next = calendar.date(byAdding: unit, value: 1,
                                           to: cursor) else { break }
            cursor = next
        }
        return out
    }

    /// С первого дня недели, принятого в стране: у кого понедельник, у кого
    /// воскресенье. Названия — на языке приложения.
    static func weekdays(_ entries: [Watering],
                         calendar: Calendar) -> [Weekday] {
        var counts = Array(repeating: 0, count: 7)
        for entry in entries {
            counts[calendar.component(.weekday, from: entry.when) - 1] += 1
        }
        var namer = Calendar(identifier: .gregorian)
        namer.locale = Lang.locale
        let short = namer.shortStandaloneWeekdaySymbols
        let full = namer.standaloneWeekdaySymbols
        return (0 ..< 7).map { step in
            let index = (calendar.firstWeekday - 1 + step) % 7
            return Weekday(number: index + 1, symbol: short[index],
                           name: full[index], count: counts[index])
        }
    }

    static func now(_ rooms: [Room]) -> Now {
        let plants = rooms.flatMap(\.plants)
        var now = Now()
        for plant in plants {
            switch plant.thirst {
            case .calm: now.calm += 1
            case .warn: now.warn += 1
            case .alarm: now.alarm += 1
            }
        }
        guard !plants.isEmpty else { return now }
        now.average = plants.map(\.moisture).reduce(0, +)
            / Double(plants.count)
        now.levels = plants.map(\.moisture).sorted()
        now.driest = plants.min { $0.moisture < $1.moisture }?.name
        return now
    }

    /// Первый полив — тем же счётом, что на карточке; дальше — через срок,
    /// если поливать вовремя.
    static func ahead(_ rooms: [Room], days: Int = horizon) -> [Ahead] {
        var out = (0 ..< days).map { Ahead(offset: $0) }
        for plant in rooms.flatMap(\.plants) where plant.period > 0 {
            for turn in 0 ..< 1_000 {
                let day = Int((Double(plant.daysUntilWatering)
                               + Double(turn) * plant.period).rounded())
                guard day < days else { break }
                out[day].plants.append(plant.id)
                out[day].names.append(plant.name)
            }
        }
        return out
    }
}

/// Статистика одного растения — для его экрана в статистике.
struct PlantBook: Sendable {
    var total = 0
    var inPeriod = 0
    var last: Date?
    /// За всё время: у одного растения поливов за неделю мало для выводов.
    var aim = Almanac.Aim()
    /// Поливы периода — от старого к новому.
    var recent: [Watering] = []
    /// Три ближайших полива, в днях сада.
    var dues: [Int] = []
    /// Средний промежуток между поливами в настоящем времени, см. `Diary`.
    var average: TimeInterval?

    static let dueCount = 3

    static func of(_ plant: Plant, log: [Watering], period: Almanac.Period,
                   since: Date, now moment: Date = Date(),
                   calendar: Calendar = .current) -> PlantBook {
        var book = PlantBook()
        let mine = log.filter { $0.plant == plant.id }
            .sorted { $0.when < $1.when }
        let today = calendar.startOfDay(for: moment)
        let (start, _) = Almanac.window(period, log: log, since: since,
                                        today: today, calendar: calendar)
        book.total = mine.count
        book.recent = mine.filter { $0.when >= start && $0.when <= moment }
        book.inPeriod = book.recent.count
        book.last = mine.last?.when
        book.aim = Almanac.Aim(mine)
        book.average = Diary.of(log, plant: plant.id).average
        if plant.period > 0 {
            book.dues = (0 ..< dueCount).map { turn in
                Int((Double(plant.daysUntilWatering)
                     + Double(turn) * plant.period).rounded())
            }
        }
        return book
    }
}
