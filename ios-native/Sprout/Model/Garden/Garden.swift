import Foundation
import Observation

/// Живой сад: комнаты, растения, время и файл. Влажность сохнет по часам, а
/// не по числу тактов: такт может задержаться.
@Observable
final class Garden {
    /// Во сколько раз время сада быстрее настоящего. Единица — настоящее
    /// время: «через 3 дня» на карточке — это три настоящих дня, и так же
    /// считают виджет, напоминания, Календарь и план лечения. Ускоренного
    /// режима в сборке нет; число оставлено одно — на случай показа.
    static let speed: Double = 1

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

    /// Миг последнего такта часов — планетарий досчитывает от него, чтобы
    /// планеты плыли, а не прыгали раз в секунду.
    var ticked: Date { lastTick }

    /// Где файл — см. `Store`.
    @ObservationIgnored private lazy var file: URL? = Store.garden

    /// Метка слепка, что сейчас в памяти: другая в файле — его записал
    /// виджет или кнопка в уведомлении, пока приложение спало.
    @ObservationIgnored private var written: String?

    /// После записи — виджету пора перерисоваться. Ставит приложение: модель
    /// о WidgetKit не знает.
    nonisolated(unsafe) static var saved: (() -> Void)?

    /// Первый запуск — пустой сад (`first`): выдуманные растения с
    /// выдуманными процентами в настоящий сад не попадают. Пример — по
    /// кнопке «Показать пример», см. `showSample`. Файл на диске есть — он и
    /// читается, как прежде.
    init(first: GardenState = Seed.blank) {
        let state = Store.read() ?? first
        owner = state.owner
        rooms = state.rooms
        log = state.log
        since = state.since
        written = state.stamp
        // Время шло и пока приложение было выгружено: отсчёт — с записи.
        // Нового сада на диске нет, и его отсчёт — с запуска.
        lastTick = min(state.savedAt, Date())
    }

    /// Файл поменяли без нас — берём его. Зовётся при возвращении на экран и
    /// перед командами, которые могут прийти, пока приложение спит.
    func reload() {
        guard let state = Store.read(), state.stamp != written else { return }
        owner = state.owner
        rooms = state.rooms
        log = state.log
        since = state.since
        written = state.stamp
        // Файл записан тогда-то — с того мига и сохнет.
        lastTick = min(state.savedAt, Date())
        roster += 1
    }

    // MARK: - Время

    func advance(to now: Date = Date()) {
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        guard elapsed > 0 else { return }
        Self.dry(&rooms, days: elapsed * Self.speed / 86_400)
    }

    /// Все растения теряют свою долю влаги за `days` дней сада.
    static func dry(_ rooms: inout [Room], days: Double) {
        for room in rooms.indices {
            // Под открытым небом погода чувствуется целиком, а не вполовину.
            let open = Climate.boost != 1 && Climate.outdoor(rooms[room].name)
            for plant in rooms[room].plants.indices {
                rooms[room].plants[plant].dry(
                    days: open ? days * Climate.boost : days)
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
        log.append(Watering(plant: id, when: moment, left: before.moisture))
        change(id) { $0.moisture = 1 }
        return Pour(plant: id, name: before.name, moisture: before.moisture,
                    when: moment)
    }

    /// Запись уходит из журнала, влажность — на прежнюю, за вычетом того, что
    /// земля успела высохнуть за отсчёт.
    func unwater(_ pour: Pour) {
        let entry = Watering(plant: pour.plant, when: pour.when)
        if let index = log.lastIndex(where: { $0.same(entry) }) {
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
        guard let index = log.lastIndex(where: { $0.same(entry) })
        else { return }
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

    /// «Показать пример» на пустом саду: комнаты и растения макета. Только
    /// пока растений нет — свой сад пример не трогает; пустые комнаты
    /// хозяина остаются после примера.
    func showSample() {
        guard plantCount == 0 else { return }
        let names = Set(Seed.rooms.map(\.name))
        rooms = Seed.rooms + rooms.filter { !names.contains($0.name) }
        roster += 1
        save()
    }

    /// Имя хозяина и день начала сада остаются: стирают сад, а не себя.
    func erase() {
        for file in rooms.flatMap(\.plants).flatMap(\.files) {
            Shots.drop(file)
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
            if !kind.isEmpty, kind != plant.species {
                plant.species = kind
                // Черты со снимка остаются, меняется только вид модели.
                plant.plan?.preset = .of(kind)
            }
            plant.retime(dryingDays)
        }
        if !nickname.isEmpty, nickname != old.name { roster += 1 }
    }

    /// Своя модель по снимку: черты со снимка — в чертёж, зерно — номер
    /// растения, чтобы модель собиралась одинаковой. Прежний скан уходит:
    /// в силе последний выбор.
    /// Вид модели — по названию; не узнали — тот, что узнал на снимке
    /// классификатор (`kind`).
    func imagine(_ id: Plant.ID, traits: Traits, kind: Preset? = nil) {
        guard let plant = plant(id: id) else { return }
        let preset = Preset.known(plant.species) ?? kind ?? .of(plant.species)
        change(id) {
            $0.plan = Blueprint(preset: preset, traits: traits, seed: id)
            $0.scan = nil
        }
    }

    /// Скан растения — файл уже лежит в `Scans`. Чертёж по снимку уходит.
    func scanned(_ id: Plant.ID, file: String) {
        guard plant(id: id) != nil else { return }
        change(id) {
            $0.scan = file
            $0.plan = nil
        }
    }

    /// Портрет — обложка растения вместо снимка; файл уже лежит в `Shots`.
    /// Прежний портрет уходит с диска: в силе последний. Счётчик состава —
    /// ради виджета: его картинки пересобираются тем же поводом.
    func portray(_ id: Plant.ID, file: String) {
        guard let old = plant(id: id) else {
            Shots.drop(file)
            return
        }
        change(id) { $0.portrait = file }
        roster += 1
        if let gone = old.portrait, gone != file { Shots.drop(gone) }
    }

    /// «Вернуть фото»: портрет уходит и с карточки, и с диска.
    func unportray(_ id: Plant.ID) {
        guard let gone = plant(id: id)?.portrait else { return }
        change(id) { $0.portrait = nil }
        roster += 1
        Shots.drop(gone)
    }

    /// Назад к готовой модели вида.
    func unmodel(_ id: Plant.ID) {
        guard let plant = plant(id: id),
              plant.plan != nil || plant.scan != nil
        else { return }
        change(id) {
            $0.plan = nil
            $0.scan = nil
        }
    }

    /// Подкормили: счёт до следующей — заново.
    func feed(_ id: Plant.ID) {
        guard plant(id: id) != nil else { return }
        change(id) {
            var tended = $0.tending
            tended.sinceFed = 0
            $0.care = tended
        }
    }

    /// Пересадили: свежая земля кормит сама — счёт подкормки тоже заново.
    func repot(_ id: Plant.ID) {
        guard plant(id: id) != nil else { return }
        change(id) {
            var tended = $0.tending
            tended.sinceRepot = 0
            tended.sinceFed = 0
            $0.care = tended
        }
    }

    // MARK: - Датчики

    /// Привязали датчик — или отвязали, пусто.
    func link(_ id: Plant.ID, sensor: Sensor?) {
        guard plant(id: id) != nil else { return }
        change(id) { $0.sensor = sensor }
    }

    /// Метка шкалы датчика по последнему показанию: «сейчас сухо» или
    /// «только что полили».
    func mark(_ id: Plant.ID, dry: Bool) {
        guard var sensor = plant(id: id)?.sensor,
              let now = sensor.last?.moisture else { return }
        if dry { sensor.dry = now } else { sensor.wet = now }
        change(id) {
            $0.sensor = sensor
            $0.moisture = sensor.level(now)
        }
    }

    /// Показание пришло: влажность растения — по датчику. Подскочила —
    /// значит, полили, пока приложение не смотрело: полив сам ложится в
    /// журнал, если его не записали кнопкой за последние два часа.
    @discardableResult
    func sense(_ id: Plant.ID, _ reading: Reading) -> Bool {
        guard let plant = plant(id: id), var sensor = plant.sensor else {
            return false
        }
        let before = sensor.last?.moisture
        sensor.last = reading
        var poured = false
        if let before, sensor.poured(from: before, to: reading.moisture),
           !log.contains(where: {
               $0.plant == id
                   && abs($0.when.timeIntervalSince(reading.when)) < 2 * 3_600
           }) {
            log.append(Watering(plant: id, when: reading.when,
                                left: sensor.level(before)))
            poured = true
        }
        change(id) {
            $0.sensor = sensor
            $0.moisture = sensor.level(reading.moisture)
        }
        return poured
    }

    /// Опрыскали, повернули, протёрли: счёт этого дела — заново.
    func did(_ duty: Duty, on id: Plant.ID) {
        guard plant(id: id) != nil else { return }
        change(id) {
            var tended = $0.tending
            tended.did(duty)
            $0.care = tended
        }
    }

    /// Сроки ухода из настроек растения; прошедшие дни сохраняются. Мелкий
    /// уход не передали — остаётся, как был.
    func tend(_ id: Plant.ID, feedEvery: Double?, repotEvery: Double?,
              duties: [Duty: Double?]? = nil) {
        guard let old = plant(id: id) else { return }
        var tended = old.tending
        tended.feedEvery = feedEvery
        tended.repotEvery = repotEvery
        for (duty, every) in duties ?? [:] {
            tended.set(duty, every: every)
        }
        guard tended != old.care else { return }
        change(id) { $0.care = tended }
    }

    // MARK: - Лечение

    /// Новый план лечения — вместо прежнего; снимки прежнего, которых нет в
    /// новом, уходят с диска.
    func treat(_ id: Plant.ID, _ plan: Treatment) {
        let old = plant(id: id)?.treatment?.files ?? []
        change(id) { $0.treatment = plan }
        for file in old where !plan.files.contains(file) { Shots.drop(file) }
    }

    /// Шаг плана сделан — или отметку сняли.
    func step(_ id: Plant.ID, _ step: Treatment.Step.ID, done: Bool,
              at now: Date = Date()) {
        guard var plan = plant(id: id)?.treatment else { return }
        plan.mark(step, done: done, at: now)
        change(id) { $0.treatment = plan }
    }

    /// «Вылечено».
    func cure(_ id: Plant.ID, at now: Date = Date()) {
        guard var plan = plant(id: id)?.treatment, plan.active else { return }
        plan.cure(at: now)
        change(id) { $0.treatment = plan }
    }

    /// План убрали — со снимками «до» и «после».
    func untreat(_ id: Plant.ID) {
        guard let gone = plant(id: id)?.treatment else { return }
        change(id) { $0.treatment = nil }
        for file in gone.files { Shots.drop(file) }
    }

    /// Снимок «до» или «после»; файл уже лежит в `Shots`. Прежний — с диска.
    func treatmentShot(_ id: Plant.ID, file: String, after: Bool) {
        guard var plan = plant(id: id)?.treatment else {
            Shots.drop(file)
            return
        }
        let old = after ? plan.after : plan.before
        if after { plan.after = file } else { plan.before = file }
        change(id) { $0.treatment = plan }
        if let old, old != file { Shots.drop(old) }
    }

    /// Предложение срока отклонили — это же больше не предлагать.
    func quiet(_ id: Plant.ID, _ days: Double) {
        guard plant(id: id) != nil else { return }
        change(id) { $0.quiet = days }
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

    /// Комната встаёт в порядке с экрана: взявшись тащить в сортировке,
    /// двигают то, что видят. Кого нет в списке — остаются в хвосте, как
    /// стояли.
    func line(_ ids: [Plant.ID]) {
        guard let first = ids.first, let room = rooms.firstIndex(where: {
            $0.plants.contains { $0.id == first }
        }) else { return }
        let plants = rooms[room].plants
        var rank: [Plant.ID: Int] = [:]
        for (place, id) in ids.enumerated() where rank[id] == nil {
            rank[id] = place
        }
        let lined = plants.enumerated().sorted { a, b in
            let x = rank[a.element.id] ?? ids.count + a.offset
            let y = rank[b.element.id] ?? ids.count + b.offset
            return x < y
        }.map(\.element)
        guard lined.map(\.id) != plants.map(\.id) else { return }
        rooms[room].plants = lined
        save()
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
        for file in gone.plants.flatMap(\.files) { Shots.drop(file) }
    }

    /// В конец новой комнаты: номер места там ничего не значит, а новосёла
    /// видно сразу.
    func relocate(_ id: Plant.ID, to room: String) {
        let target = room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, roomName(of: id) != target,
              let gone = remove(id) else { return }
        add(gone.plant, to: target)
    }

    /// Правка ставит отметки сама (`Plant.stamp`): общий сад по ним решает,
    /// чья правка новее, а каждому методу помнить о них не нужно.
    private func change(_ id: Plant.ID, _ edit: (inout Plant) -> Void) {
        for room in rooms.indices {
            if let index = rooms[room].plants.firstIndex(where: { $0.id == id }) {
                let before = rooms[room].plants[index]
                edit(&rooms[room].plants[index])
                rooms[room].plants[index].stamp(since: before)
                save()
                return
            }
        }
    }

    /// Сад из iCloud: семья полила, переименовала, добавила — см. `Family`.
    /// Сменился состав, клички или обложки — пересказываем Siri и виджету.
    func adopt(rooms: [Room], log: [Watering], recast: Bool) {
        self.rooms = rooms
        self.log = log
        if recast { roster += 1 }
        save()
    }

    // MARK: - Файл

    var state: GardenState {
        GardenState(owner: owner, rooms: rooms, savedAt: Date(),
                    log: log, since: since, stamp: written,
                    season: Season.stretch, climate: Climate.current)
    }

    /// На действиях хозяина и при уходе в фон, но не на каждом такте часов.
    func save() {
        guard let file else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            var snapshot = state
            snapshot.stamp = UUID().uuidString
            try encoder.encode(snapshot).write(to: file, options: .atomic)
            written = snapshot.stamp
            Self.saved?()
        } catch {
            // Не сохранились — не повод падать: сад в памяти цел.
        }
    }
}
