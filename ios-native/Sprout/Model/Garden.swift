import Foundation
import Observation

/// Живой сад: комнаты, растения, время и файл, в котором всё это лежит
/// между запусками.
///
/// Влажность не хранится замороженной — сад её сушит. Раз в секунду
/// приложение отдаёт саду прошедшее время, и почва подсыхает ровно на
/// столько, сколько его прошло. Считаем от часов, а не от числа тактов:
/// такт может задержаться, а время идёт ровно.
@Observable
final class Garden {
    /// Во сколько раз время здесь быстрее настоящего.
    ///
    /// В жизни почва сохнет неделями, и за сеанс проценты не сдвинулись
    /// бы ни на один — смотреть было бы не на что, а вся затея с таймером
    /// осталась бы на словах. Секунда идёт за час: сутки проходят за 24
    /// секунды, недельное растение пересыхает за три минуты, и видно и
    /// как убывают проценты, и как тень желтеет, а потом краснеет.
    ///
    /// Захочется медленнее — это единственное число, которое надо трогать.
    static let speed: Double = 3_600

    var owner: String
    var rooms: [Room]

    /// Журнал поливов. Из него считается вся статистика — см. `Score`.
    private(set) var log: [Watering]

    /// Когда завели сад. Не константа только ради переноса: сад,
    /// принесённый с прежнего телефона, приносит с собой и свой возраст.
    private(set) var since: Date

    /// Когда сад считали в прошлый раз. Не наблюдаемое: от его смены
    /// перерисовывать нечего.
    @ObservationIgnored private var lastTick = Date()

    /// Куда лечь между запусками.
    ///
    /// Documents, а не Caches: это данные хозяина, их нельзя вычистить
    /// ради места. Файл заодно попадает в резервную копию.
    @ObservationIgnored private lazy var file: URL? = Self.fileURL()

    init() {
        let state = Self.load() ?? Seed.state
        owner = state.owner
        rooms = state.rooms
        log = state.log
        since = state.since
        // Отсчёт начинается с запуска: что было до первого запуска, саду
        // знать неоткуда. А вот между запусками время идёт — вернувшись
        // из фона, сад отдаёт себе всё прошедшее разом. Иначе врали бы
        // напоминания о поливе: уведомление прилетело бы, а на карточке
        // стояла бы прежняя влажность. См. «Живой сад» в README.
        lastTick = Date()
    }

    // MARK: - Время

    /// Отдать саду прошедшее время. Зовётся часами приложения.
    func advance(to now: Date = Date()) {
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        guard elapsed > 0 else { return }
        let days = elapsed * Self.speed / 86_400
        for room in rooms.indices {
            for plant in rooms[room].plants.indices {
                rooms[room].plants[plant].dry(days: days)
            }
        }
    }

    // MARK: - Что где растёт

    /// Как подписывать сад там, где без имени нельзя, — в коде для
    /// друзей и в строке таблицы соперников.
    ///
    /// Пустое имя значит «ещё не назвался», а не «зовут пусто»: код с
    /// пустым именем обратно не разберётся, и соперник пришёл бы в
    /// таблицу безымянным.
    var signed: String { owner.isEmpty ? Seed.stranger : owner }

    /// Сколько всего растений в квартире.
    var plantCount: Int { rooms.reduce(0) { $0 + $1.plants.count } }

    func plant(id: Plant.ID) -> Plant? {
        for room in rooms {
            if let found = room.plants.first(where: { $0.id == id }) {
                return found
            }
        }
        return nil
    }

    func roomName(of id: Plant.ID) -> String? {
        rooms.first { $0.plants.contains { $0.id == id } }?.name
    }

    func search(_ query: String) -> [Plant] { Seed.search(query, in: rooms) }

    // MARK: - Что с ними делают

    func water(_ id: Plant.ID, at moment: Date = Date()) {
        // Запись в журнал — до полива, а не после: `change` сам пишет сад
        // на диск, и запись должна попасть в тот же файл.
        log.append(Watering(plant: id, when: moment))
        change(id) { $0.moisture = 1 }
    }

    /// Что сад может рассказать о поливах.
    func score(now: Date = Date(), calendar: Calendar = .current) -> Score {
        Score.of(log, rooms: rooms, now: now, calendar: calendar)
    }

    /// Завести растение в комнате. Нет такой комнаты — заводим и её.
    func add(_ plant: Plant, to room: String) {
        if let index = rooms.firstIndex(where: { $0.name == room }) {
            rooms[index].plants.append(plant)
        } else {
            rooms.append(Room(name: room, plants: [plant]))
        }
        save()
    }

    /// Принять сад целиком — из файла, сохранённого на прежнем телефоне.
    ///
    /// Не слияние, а замена: слить два сада нечем. Одинаковых растений в
    /// них не бывает — номер у каждого свой, случайный, — и «объединение»
    /// свелось бы к тому, что все растения принесённого сада встали бы
    /// рядом со здешними вторым комплектом. Замена честнее, и поэтому
    /// экран спрашивает подтверждение.
    func restore(_ state: GardenState) {
        owner = state.owner
        rooms = state.rooms
        log = state.log
        since = state.since
        save()
    }

    /// Стереть сад: ни растений, ни журнала.
    ///
    /// Имя хозяина остаётся: стирают сад, а не себя. И день, когда сад
    /// завели, тоже — это возраст самого приложения у человека, а не
    /// возраст того, что в нём сейчас растёт.
    func erase() {
        for shot in rooms.flatMap(\.plants).compactMap(\.shot) {
            Shots.drop(shot)
        }
        rooms = []
        log = []
        save()
    }

    /// Переименовать хозяина. Пустое имя не сохраняем — по той же
    /// причине, что и пустую кличку.
    func rename(owner name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        owner = trimmed
        save()
    }

    /// Пустое имя не сохраняем: безымянная карточка — это поломка, а не
    /// решение хозяина.
    func rename(_ id: Plant.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        change(id) { $0.name = trimmed }
    }

    func delete(_ id: Plant.ID) {
        // Снимок уходит вместе с растением: иначе Documents копил бы
        // картинки, на которые больше никто не смотрит.
        let shot = plant(id: id)?.shot
        for room in rooms.indices {
            rooms[room].plants.removeAll { $0.id == id }
        }
        save()
        if let shot { Shots.drop(shot) }
    }

    private func change(_ id: Plant.ID, _ edit: (inout Plant) -> Void) {
        for room in rooms.indices {
            if let index = rooms[room].plants.firstIndex(where: { $0.id == id }) {
                edit(&rooms[room].plants[index])
                save()
                return
            }
        }
    }

    // MARK: - Файл

    /// Слепок сада.
    var state: GardenState {
        GardenState(owner: owner, rooms: rooms, savedAt: Date(),
                    log: log, since: since)
    }

    /// Записать сад на диск.
    ///
    /// Зовётся на действиях хозяина и при уходе приложения в фон, но не на
    /// каждом такте часов: влажность меняется ежесекундно, а писать файл
    /// ежесекундно незачем.
    func save() {
        guard let file else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(state).write(to: file, options: .atomic)
        } catch {
            // Не сохранились — не повод падать: сад в памяти цел, а
            // разбираться с диском посреди полива нечем.
        }
    }

    private static func fileURL() -> URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("garden.json")
    }

    private static func load() -> GardenState? {
        guard let file = fileURL(),
              let data = try? Data(contentsOf: file)
        else { return nil }
        // Битый файл — тоже «нет файла»: лучше начать с макетного сада,
        // чем не запуститься.
        return try? JSONDecoder().decode(GardenState.self, from: data)
    }
}
