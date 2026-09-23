import Foundation
import Observation

/// Живой сад: комнаты, растения, время и файл. Влажность сохнет по часам, а
/// не по числу тактов: такт может задержаться.
@Observable
final class Garden {
    /// Во сколько раз время сада быстрее настоящего: секунда за час, иначе за
    /// сеанс проценты не сдвинулись бы. Захочется медленнее — это
    /// единственное число.
    static let speed: Double = 3_600

    /// Один сад на приложение — ради Siri: команда исполняется и без окон,
    /// когда корня интерфейса нет, и должна поливать тот же сад, что видят
    /// экраны.
    static let shared = Garden()

    var owner: String
    var rooms: [Room]

    private(set) var log: [Watering]

    /// Счётчик изменений состава сада — по нему корень пересказывает Siri
    /// клички. Следить за самими комнатами нельзя: влажность в них меняется
    /// ежесекундно.
    private(set) var roster = 0

    /// Не константа ради переноса сада с прежнего телефона.
    private(set) var since: Date

    @ObservationIgnored private var lastTick = Date()

    /// Documents, а не Caches: данные хозяина нельзя вычищать ради места, и
    /// так файл попадает в резервную копию.
    @ObservationIgnored private lazy var file: URL? = Self.fileURL()

    init() {
        let state = Self.load() ?? Seed.state
        owner = state.owner
        rooms = state.rooms
        log = state.log
        since = state.since
        // Отсчёт — с запуска: что было до него, саду знать неоткуда.
        lastTick = Date()
    }

    // MARK: - Время

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

    /// Пустое имя — «ещё не назвался»: код с пустым именем не разберётся
    /// обратно.
    var signed: String { owner.isEmpty ? Seed.stranger : owner }

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

    /// Отвечает, что было до полива, — для отмены, см. `unwater`.
    @discardableResult
    func water(_ id: Plant.ID, at moment: Date = Date()) -> Pour? {
        guard let before = plant(id: id) else { return nil }
        // Запись в журнал — до полива: `change` пишет файл, и запись должна в
        // него попасть.
        log.append(Watering(plant: id, when: moment))
        change(id) { $0.moisture = 1 }
        return Pour(plant: id, name: before.name, moisture: before.moisture,
                    when: moment)
    }

    /// Запись уходит из журнала, влажность — на прежнюю, за вычетом того, что
    /// земля успела высохнуть за отсчёт.
    func unwater(_ pour: Pour) {
        if let index = log.lastIndex(of: Watering(plant: pour.plant,
                                                   when: pour.when)) {
            log.remove(at: index)
        }
        guard plant(id: pour.plant) != nil else {
            save()
            return
        }
        change(pour.plant) {
            $0.moisture = max(0, pour.moisture - (1 - $0.moisture))
        }
    }

    /// Ошибочная запись из истории. Влажность не трогаем: для свежей ошибки
    /// есть отмена, а старая давно высохла.
    func forget(_ entry: Watering) {
        guard let index = log.lastIndex(of: entry) else { return }
        log.remove(at: index)
        save()
    }

    func score(now: Date = Date(), calendar: Calendar = .current) -> Score {
        Score.of(log, rooms: rooms, now: now, calendar: calendar)
    }

    /// Нет такой комнаты — заводим и её.
    func add(_ plant: Plant, to room: String) {
        if let index = rooms.firstIndex(where: { $0.name == room }) {
            rooms[index].plants.append(plant)
        } else {
            rooms.append(Room(name: room, plants: [plant]))
        }
        roster += 1
        save()
    }

    /// Замена, а не слияние: номера у растений случайные, и слияние поставило
    /// бы второй комплект. Поэтому экран переспрашивает.
    func restore(_ state: GardenState) {
        owner = state.owner
        rooms = state.rooms
        log = state.log
        since = state.since
        roster += 1
        save()
    }

    /// Имя хозяина и день начала сада остаются: стирают сад, а не себя.
    func erase() {
        for shot in rooms.flatMap(\.plants).compactMap(\.shot) {
            Shots.drop(shot)
        }
        rooms = []
        log = []
        roster += 1
        save()
    }

    func rename(owner name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        owner = trimmed
        save()
    }

    /// Пустое имя не сохраняем: безымянная карточка — поломка.
    func rename(_ id: Plant.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        change(id) { $0.name = trimmed }
        roster += 1
    }

    /// Настройки растения. Пустые кличка и вид остаются прежними, срок
    /// пересчитывает влажность — см. `Plant.retime`.
    func tune(_ id: Plant.ID, name: String, species: String,
              dryingDays: Double) {
        guard let old = plant(id: id) else { return }
        let nickname = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = species.trimmingCharacters(in: .whitespacesAndNewlines)
        change(id) { plant in
            if !nickname.isEmpty { plant.name = nickname }
            if !kind.isEmpty { plant.species = kind }
            plant.retime(dryingDays)
        }
        if !nickname.isEmpty, nickname != old.name { roster += 1 }
    }

    /// Пустая заметка — её нет.
    func note(_ id: Plant.ID, _ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let kept: String? = trimmed.isEmpty ? nil : trimmed
        guard let plant = plant(id: id), plant.note != kept else { return }
        change(id) { $0.note = kept }
    }

    /// Растение занимает место другого, как на экране «Домой»: вперёд —
    /// встаёт за ним, назад — перед ним. Только в своей комнате.
    func move(_ id: Plant.ID, to target: Plant.ID) {
        guard id != target else { return }
        for room in rooms.indices {
            let plants = rooms[room].plants
            guard let from = plants.firstIndex(where: { $0.id == id })
            else { continue }
            guard let to = plants.firstIndex(where: { $0.id == target })
            else { return }
            let plant = rooms[room].plants.remove(at: from)
            rooms[room].plants.insert(plant, at: to)
            save()
            return
        }
    }

    /// Убрать, запомнив откуда. Снимок остаётся на диске — его выбрасывает
    /// тот, кто решит, что возврата не будет. Журнал не трогаем: поливы были,
    /// а вернётся растение — они снова его.
    @discardableResult
    func remove(_ id: Plant.ID) -> Removal? {
        for room in rooms.indices {
            guard let index = rooms[room].plants.firstIndex(where: {
                $0.id == id
            }) else { continue }
            let plant = rooms[room].plants.remove(at: index)
            roster += 1
            save()
            return Removal(plant: plant, room: rooms[room].name,
                           roomIndex: room, index: index)
        }
        return nil
    }

    /// Комнату за отсчёт могли удалить — тогда она заводится там, где стояла.
    /// Второй раз не встаёт.
    func putBack(_ gone: Removal) {
        guard plant(id: gone.plant.id) == nil else { return }
        if let room = rooms.firstIndex(where: { $0.name == gone.room }) {
            let index = min(gone.index, rooms[room].plants.count)
            rooms[room].plants.insert(gone.plant, at: index)
        } else {
            let index = min(gone.roomIndex, rooms.count)
            rooms.insert(Room(name: gone.room, plants: [gone.plant]),
                         at: index)
        }
        roster += 1
        save()
    }

    // MARK: - Комнаты

    /// Без оглядки на регистр: «Кухня» и «кухня» читались бы одной комнатой.
    private func taken(_ name: String, except old: String? = nil) -> Bool {
        rooms.contains {
            $0.name != old
                && $0.name.compare(name, options: .caseInsensitive) == .orderedSame
        }
    }

    /// Отвечает, завелась ли: пустое и занятое имя не годятся.
    @discardableResult
    func addRoom(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !taken(trimmed) else { return false }
        rooms.append(Room(name: trimmed, plants: []))
        roster += 1
        save()
        return true
    }

    /// Отвечает, получилось ли. Имя — личность комнаты (`Room.id`); своё же
    /// имя заново — не ошибка.
    @discardableResult
    func renameRoom(_ old: String, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = rooms.firstIndex(where: { $0.name == old })
        else { return false }
        guard trimmed != old else { return true }
        guard !taken(trimmed, except: old) else { return false }
        rooms[index].name = trimmed
        roster += 1
        save()
        return true
    }

    /// Как список iOS: взятые встают перед местом, куда их опустили. Своими
    /// руками — `move(fromOffsets:)` приходит из SwiftUI.
    func moveRooms(from source: IndexSet, to destination: Int) {
        let moving = source.sorted().filter(rooms.indices.contains)
            .map { rooms[$0] }
        guard !moving.isEmpty else { return }
        var rest = rooms.enumerated()
            .filter { !source.contains($0.offset) }
            .map(\.element)
        let before = source.filter { $0 < destination }.count
        let at = min(max(destination - before, 0), rest.count)
        rest.insert(contentsOf: moving, at: at)
        guard rest.map(\.name) != rooms.map(\.name) else { return }
        rooms = rest
        save()
    }

    func deleteRoom(_ name: String) {
        guard let index = rooms.firstIndex(where: { $0.name == name })
        else { return }
        let gone = rooms.remove(at: index)
        roster += 1
        save()
        for shot in gone.plants.compactMap(\.shot) { Shots.drop(shot) }
    }

    /// В конец новой комнаты: номер места там ничего не значит, а новосёла
    /// видно сразу.
    func relocate(_ id: Plant.ID, to room: String) {
        let target = room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, roomName(of: id) != target,
              let gone = remove(id) else { return }
        add(gone.plant, to: target)
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

    var state: GardenState {
        GardenState(owner: owner, rooms: rooms, savedAt: Date(),
                    log: log, since: since)
    }

    /// На действиях хозяина и при уходе в фон, но не на каждом такте часов.
    func save() {
        guard let file else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(state).write(to: file, options: .atomic)
        } catch {
            // Не сохранились — не повод падать: сад в памяти цел.
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
        // Битый файл — тоже «нет файла»: лучше макетный сад, чем не
        // запуститься.
        return try? JSONDecoder().decode(GardenState.self, from: data)
    }
}
