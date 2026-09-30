import Foundation

/// Дача: комнаты, что растут не дома, место, где они растут, и дождь там.
/// Здесь только арифметика — её проверяет прогон модели. Место, напоминание
/// по приезде и погоду на даче ведёт `Dachnik`.
enum Dacha {
    /// Место дачи — где хозяин нажал «Отметить дачу здесь».
    struct Spot: Codable, Equatable, Sendable {
        var latitude: Double
        var longitude: Double
        var marked: Date
    }

    /// Радиус геозоны в метрах: участок с домом и подъездом. Уже — система
    /// может не заметить приезда, шире — напомнит ещё у соседей.
    static let radius = 200.0

    /// Место точнее этого, в метрах, годится; грубее — пусть уточнится:
    /// ошибка в полкруга геозоны сдвинула бы её с участка.
    static let roughest = 100.0

    /// Кому вода по приезде.
    struct Arrival: Equatable, Sendable {
        var ids: [Plant.ID]

        var count: Int { ids.count }
    }

    static func rooms(_ rooms: [Room]) -> [Room] { rooms.filter(\.atDacha) }

    /// Всё, что не на даче, — обычным напоминаниям, когда о даче
    /// напоминают только там.
    static func home(_ rooms: [Room]) -> [Room] {
        rooms.filter { !$0.atDacha }
    }

    /// Дачные комнаты совсем без крыши — там идёт дождь, см. `Climate.open`.
    static func open(_ rooms: [Room]) -> [Room] {
        rooms.filter { $0.atDacha && Climate.open($0.name) }
    }

    /// Все дачные растения, которые сохнут, — по счёту их и приглашают
    /// полить. Не «кому сухо сейчас»: уведомление ставится заранее, а
    /// приедут, может быть, через неделю. Число меняется, только когда
    /// меняется сама дача, — и то же уведомление не ставится заново, пока
    /// хозяин на участке.
    static func arrival(in rooms: [Room]) -> Arrival? {
        let ids = Self.rooms(rooms).flatMap(\.plants)
            .filter { $0.dryingDays > 0 }
            .map(\.id)
        return ids.isEmpty ? nil : Arrival(ids: ids)
    }

    /// «Вы на даче — полить: 3 растения».
    static func text(for arrival: Arrival) -> String {
        Lang.format("Вы на даче — полить: %@",
                    Lang.format("%lld растений", arrival.count))
    }

    // MARK: - Дождь

    /// Час погоды на даче: сколько выпало или обещано и насколько верно.
    struct Hour: Equatable, Sendable {
        var start: Date
        var millimeters: Double
        /// 0…1.
        var chance: Double
    }

    /// Что дождь уже сделал и что обещано. Живёт между запусками, чтобы
    /// один дождь не полил дважды.
    struct Rainfall: Codable, Equatable, Sendable {
        /// До этого часа дожди учтены.
        var counted: Date
        /// Когда погоду на даче узнавали в последний раз.
        var checked: Date
        /// Последний дождь, отложивший полив: когда учтён и сколько выпало.
        var soaked: Date?
        var millimeters: Double?
        /// Начало суток, на которые обещан дождь.
        var promised: Date?
    }

    /// Морось землю не промочит: столько миллиметров не в счёт.
    static let drizzle = 2.0

    /// Столько сверх мороси — как полный полив.
    static let downpour = 10.0

    /// Обещанный дождь — не меньше стольких миллиметров за сутки…
    static let enough = 3.0

    /// …и хоть в какой-то час — не ниже такой вероятности.
    static let likely = 0.5

    /// Сколько влажности вернёт дождь: морось — ничего, ливень — всю.
    static func gain(_ millimeters: Double) -> Double {
        min(max(millimeters - drizzle, 0) / downpour, 1)
    }

    /// Сколько выпало за прошедшие целые часы с `from` до `now` и до какого
    /// мига теперь всё учтено; идущий час — в следующий раз.
    static func fallen(_ hours: [Hour], from: Date, to now: Date)
        -> (millimeters: Double, until: Date?) {
        let past = hours.filter {
            $0.start >= from && $0.start.addingTimeInterval(3_600) <= now
        }
        let total = past.reduce(0) { $0 + max($1.millimeters, 0) }
        let until = past.map { $0.start.addingTimeInterval(3_600) }.max()
        return (total, until)
    }

    /// Начало завтрашних суток, если на них обещан дождь.
    static func promised(_ hours: [Hour], now: Date,
                         calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let after = calendar.date(byAdding: .day, value: 2, to: today)
        else { return nil }
        let day = hours.filter { $0.start >= tomorrow && $0.start < after }
        let total = day.reduce(0) { $0 + max($1.millimeters, 0) }
        let surest = day.map(\.chance).max() ?? 0
        return total >= enough && surest >= likely ? tomorrow : nil
    }

    /// «Прошёл дождь» — сутки после того, как он отложил полив.
    static func lately(_ rain: Rainfall?, now: Date = Date()) -> Bool {
        guard let soaked = rain?.soaked else { return false }
        let age = now.timeIntervalSince(soaked)
        return age >= 0 && age < 86_400
    }

    /// «Завтра дождь» — пока обещанные сутки и правда завтрашние.
    static func tomorrow(_ rain: Rainfall?, now: Date = Date(),
                         calendar: Calendar = .current) -> Bool {
        guard let promised = rain?.promised,
              let tomorrow = calendar.date(
                  byAdding: .day, value: 1,
                  to: calendar.startOfDay(for: now))
        else { return false }
        return calendar.isDate(promised, inSameDayAs: tomorrow)
    }
}

extension Room {
    var atDacha: Bool { dacha == true }
}

extension Garden {
    /// Комната едет на дачу или возвращается домой. Состав сада тот же,
    /// поэтому Siri и виджету пересказывать нечего.
    func settle(_ room: String, dacha on: Bool) {
        guard let index = rooms.firstIndex(where: { $0.name == room }),
              rooms[index].atDacha != on
        else { return }
        rooms[index].dacha = on ? true : nil
        save()
    }

    /// Дождь на даче: земля под открытым небом намокает, как от полива, но
    /// в журнал это не идёт — поливал не хозяин. Растения с датчиком не
    /// трогаем: у них влажность настоящая.
    func soak(_ names: Set<String>, by gain: Double) {
        guard gain > 0 else { return }
        var wet = false
        for room in rooms.indices where names.contains(rooms[room].name) {
            for index in rooms[room].plants.indices {
                let plant = rooms[room].plants[index]
                guard plant.dryingDays > 0, plant.sensor == nil,
                      plant.moisture < 1
                else { continue }
                rooms[room].plants[index].moisture = min(1,
                                                         plant.moisture + gain)
                wet = true
            }
        }
        if wet { save() }
    }
}
