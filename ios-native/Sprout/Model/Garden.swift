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
        // Пока приложение закрыто, время не идёт. Ускоренное имеет смысл,
        // только пока на сад смотрят: иначе ночь обернулась бы годами и
        // утром всё стояло бы сухим.
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

    func water(_ id: Plant.ID) {
        change(id) { $0.moisture = 1 }
    }

    /// Пустое имя не сохраняем: безымянная карточка — это поломка, а не
    /// решение хозяина.
    func rename(_ id: Plant.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        change(id) { $0.name = trimmed }
    }

    func delete(_ id: Plant.ID) {
        for room in rooms.indices {
            rooms[room].plants.removeAll { $0.id == id }
        }
        save()
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
        GardenState(owner: owner, rooms: rooms, savedAt: Date())
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
