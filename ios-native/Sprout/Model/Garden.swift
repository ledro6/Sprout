import Foundation
import Observation

/// Живой сад: комнаты, растения, время и файл, в котором всё это лежит
/// между запусками.
///
/// Влажность не хранится замороженной — сад её сушит. Раз в секунду
/// приложение отдаёт саду прошедшее время, и почва подсыхает ровно на
/// столько, сколько его прошло. Считаем от часов, а не от числа тактов:
/// пока приложение свёрнуто, таймер стоит, а время идёт.
@Observable
final class Garden {
    var owner: String
    var rooms: [Room]
    var speed: TimeSpeed

    /// Когда сад считали в прошлый раз. Не наблюдаемое: от его смены
    /// перерисовывать нечего.
    @ObservationIgnored private var lastTick: Date

    /// Куда лечь между запусками.
    ///
    /// Documents, а не Caches: это данные хозяина, их нельзя вычистить
    /// ради места. Файл заодно попадает в резервную копию.
    @ObservationIgnored private lazy var file: URL? = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("garden.json")
    }()

    init() {
        let saved = Garden.load()
        let state = saved ?? Seed.state
        owner = state.owner
        rooms = state.rooms
        speed = state.speed

        // Пока приложение было закрыто, почва тоже сохла — но только по
        // настоящему времени. Ускоренное идёт лишь пока на сад смотрят:
        // иначе восемь часов сна при «часе в секунду» обернулись бы
        // тремя годами, и утром всё стояло бы сухим.
        lastTick = state.speed == .real ? state.savedAt : Date()
        advance()
    }

    // MARK: - Время

    func advance(to now: Date = Date()) {
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        guard elapsed > 0 else { return }
        let days = elapsed * speed.factor / 86_400
        for room in rooms.indices {
            for plant in rooms[room].plants.indices {
                rooms[room].plants[plant].dry(days: days)
            }
        }
    }

    // MARK: - Что где растёт

    var allPlants: [Plant] { rooms.flatMap(\.plants) }

    /// Те, кому пора пить, — самые сухие первыми.
    var thirsty: [Plant] {
        allPlants
            .filter { $0.thirst != .calm }
            .sorted { $0.moisture < $1.moisture }
    }

    var averageMoisture: Double {
        let plants = allPlants
        guard !plants.isEmpty else { return 0 }
        return plants.reduce(0) { $0 + $1.moisture } / Double(plants.count)
    }

    func plant(id: Plant.ID) -> Plant? {
        for room in rooms {
            if let found = room.plants.first(where: { $0.id == id }) { return found }
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

    func waterAll() {
        for room in rooms.indices {
            for plant in rooms[room].plants.indices {
                rooms[room].plants[plant].moisture = 1
            }
        }
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
        for room in rooms.indices {
            rooms[room].plants.removeAll { $0.id == id }
        }
        save()
    }

    /// Новое растение приходит политым: его только что поставили на
    /// подоконник и полили.
    func add(name: String, species: String, roomIndex: Int, dryingDays: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, rooms.indices.contains(roomIndex) else { return }
        let kind = species.trimmingCharacters(in: .whitespacesAndNewlines)
        rooms[roomIndex].plants.append(
            Plant(id: UUID().uuidString,
                  name: trimmed,
                  species: kind.isEmpty ? "Растение" : kind,
                  moisture: 1,
                  dryingDays: dryingDays,
                  addedOn: Calendar.current.dateComponents(
                    [.year, .month, .day], from: Date())))
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
        GardenState(owner: owner, rooms: rooms, speed: speed, savedAt: Date())
    }

    /// Записать сад на диск.
    ///
    /// Вызывается на действиях хозяина и при уходе приложения в фон, но
    /// не на каждом такте часов: влажность меняется ежесекундно, а писать
    /// файл ежесекундно незачем — при настоящей скорости она всё равно
    /// пересчитывается от времени слепка.
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

    private static func load() -> GardenState? {
        guard let file = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("garden.json"),
            let data = try? Data(contentsOf: file)
        else { return nil }
        // Битый файл — тоже «нет файла»: лучше начать с макетного сада,
        // чем не запуститься.
        return try? JSONDecoder().decode(GardenState.self, from: data)
    }
}
