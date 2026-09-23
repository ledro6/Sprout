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

    /// Сад приложения — один на всех, кто с ним говорит.
    ///
    /// Один, а не у корня интерфейса свой, и это ради Siri. Команда
    /// «Полей Баксика» исполняется в том же процессе, что и приложение, но
    /// не на его экранах: приложение может быть закрыто, и тогда система
    /// поднимает его в фоне, без единого окна. Сад, живущий в корне
    /// интерфейса, в этом случае не создался бы вовсе, а создайся команда
    /// свой — поливала бы копию, и открытое приложение этого не увидело
    /// бы. Общий заводится при первом обращении, откуда бы оно ни пришло.
    static let shared = Garden()

    var owner: String
    var rooms: [Room]

    /// Журнал поливов. Из него считается вся статистика — см. `Score`.
    private(set) var log: [Watering]

    /// Сколько раз менялся состав сада: растения, их клички, комнаты.
    ///
    /// Не для показа. По нему корень узнаёт, что пора пересказать Siri,
    /// какие растения есть в саду. Следить ради этого за самими комнатами
    /// нельзя: влажность в них меняется ежесекундно, и корень
    /// пересобирался бы каждую секунду. Счётчик же трогают только
    /// действия хозяина.
    private(set) var roster = 0

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
        roster += 1
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
        roster += 1
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
        roster += 1
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
        roster += 1
    }

    /// Переставить растение на место другого — в той же комнате.
    ///
    /// Не «вставить перед», а «занять место»: так ведёт себя перестановка
    /// на экране «Домой». Тащишь вперёд — растение встаёт за тем, над кем
    /// его держат, и сосед отступает назад; тащишь назад — встаёт перед
    /// ним, и сосед отступает вперёд. Сетка при этом перекладывается
    /// прямо под пальцем, на каждом переходе через соседа, а не одним
    /// махом в конце.
    ///
    /// Между комнатами не переносит: комнату на главной видно одну, и
    /// тащить растению некуда, кроме как по ней. Переезд в другую комнату
    /// — другое действие, и прятать его в перетаскивание незачем.
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

    /// Удалить растение насовсем — вместе со снимком.
    ///
    /// С экранов так больше не удаляют: там растение сперва убирают
    /// (`remove`), и пять секунд его можно вернуть. Насовсем — это то, что
    /// происходит по истечении этих секунд, и то, чем пользуется проверка
    /// модели.
    func delete(_ id: Plant.ID) {
        guard let gone = remove(id) else { return }
        // Снимок уходит вместе с растением: иначе Documents копил бы
        // картинки, на которые больше никто не смотрит.
        if let shot = gone.plant.shot { Shots.drop(shot) }
    }

    /// Убрать растение из сада, запомнив, откуда его взяли.
    ///
    /// Снимок остаётся на диске: убранное ещё могут вернуть, а снимок —
    /// единственное в растении, чего из памяти не восстановить. Его
    /// выбрасывает тот, кто решает, что возврата уже не будет.
    ///
    /// Журнал поливов не трогаем. Статистика — это история, и поливы
    /// удалённого растения в ней были; а вернись растение — его поливы
    /// оказываются на месте сами.
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

    /// Вернуть убранное — на то же место в той же комнате.
    ///
    /// Комнаты за это время могло не стать — её удалили, пока шёл отсчёт.
    /// Тогда она заводится заново там, где стояла: возвращают растение, а
    /// не повод его искать. Уже вернувшееся второй раз не встаёт.
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

    /// Занято ли имя комнаты. Без оглядки на регистр: «Кухня» и «кухня»
    /// в одном саду читались бы одной комнатой, раздвоившейся по ошибке.
    private func taken(_ name: String, except old: String? = nil) -> Bool {
        rooms.contains {
            $0.name != old
                && $0.name.compare(name, options: .caseInsensitive) == .orderedSame
        }
    }

    /// Завести пустую комнату. Отвечает, завелась ли: пустое имя и имя,
    /// которое уже занято, не годятся.
    @discardableResult
    func addRoom(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !taken(trimmed) else { return false }
        rooms.append(Room(name: trimmed, plants: []))
        roster += 1
        save()
        return true
    }

    /// Переименовать комнату. Отвечает, получилось ли, — экран по ответу
    /// решает, оставить ли вписанное или вернуть прежнее имя.
    ///
    /// Имя комнаты — её личность (`Room.id`), поэтому пустым или чужим
    /// оно быть не может. Своё же имя, вписанное заново, — не ошибка.
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

    /// Переставить комнаты — так, как это делает список iOS: взятые
    /// встают перед тем местом, куда их опустили.
    ///
    /// Своими руками, а не через `move(fromOffsets:toOffset:)`: тот
    /// приходит из SwiftUI, а модель собирается и без него.
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

    /// Удалить комнату со всем, что в ней растёт, — и снимки с ними.
    func deleteRoom(_ name: String) {
        guard let index = rooms.firstIndex(where: { $0.name == name })
        else { return }
        let gone = rooms.remove(at: index)
        roster += 1
        save()
        for shot in gone.plants.compactMap(\.shot) { Shots.drop(shot) }
    }

    /// Перевезти растение в другую комнату — в конец её ряда.
    ///
    /// В конец, а не на то же место: номер места в другой комнате ничего
    /// не значит, а в конце новосёла видно сразу. Такой комнаты нет —
    /// заводим, как при посадке.
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
