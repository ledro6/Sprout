import Foundation

/// Общий сад на семью: что уходит в iCloud и как чужие правки ложатся на
/// свои. Здесь только арифметика — её проверяет прогон модели; CloudKit
/// ведёт `Kinship`.
///
/// Сад в iCloud — зона записей четырёх видов: комната, растение, полив и
/// снимок. Комнаты и растения сливаются по отметкам правки — поздняя
/// побеждает (`Plant.edited`, `Room.edited`); влажность и уход — по своим
/// отметкам (`Plant.wet`, `Plant.tended`): полил один, переименовал другой —
/// останется и то и другое. Поливы только добавляются и сливаются по
/// номеру. Снимок не меняется никогда: новый снимок — новое имя файла.
///
/// Что отправить, считается не из очереди правок, а сравнением: сад как он
/// есть против того, что известно о сервере (`Book.known`). Так правка не
/// потеряется, каким бы путём ни пришла — с экрана, из виджета, с часов.
enum Family {
    /// Вид записи — он же её тип в CloudKit.
    enum Kind: String, CaseIterable {
        case room = "Room"
        case plant = "Plant"
        case pour = "Pour"
        case photo = "Photo"

        /// Начало имени записи: по нему вид узнаётся и у удалённой записи.
        var prefix: String { rawValue.lowercased() }
    }

    /// Чем телефон занят в общем саду: ничем, своим садом в iCloud или
    /// чужим, куда пригласили.
    enum Mode: String, Codable {
        case off, own, guest
    }

    /// Комната в записи.
    struct RoomBody: Codable, Equatable {
        var key: String
        var name: String
        var dacha: Bool
        var rank: Double
        var edited: Date?
    }

    /// Растение в записи: само растение — влажность и уход на миг `at` — и
    /// где оно стоит. Имя комнаты — на случай, если сама комната ещё не
    /// пришла.
    struct PlantBody: Codable, Equatable {
        var plant: Plant
        var room: String
        var roomName: String
        var at: Date
    }

    /// Что известно о записи на сервере: системные поля CloudKit и отметки
    /// той версии, что там лежит. Отметка своя не такая — правка ещё не ушла.
    struct Mark: Codable, Equatable {
        var tag: Data?
        var edited: Date?
        var wet: Date?
        var tended: Date?
        var room: String?
        var rank: Double?
        var name: String?
        var dacha: Bool?
    }

    /// Всё, что телефон помнит об одной зоне сада в iCloud.
    struct Book: Codable, Equatable {
        /// Записи, какими их последний раз видел сервер, — по имени записи.
        var known: [String: Mark] = [:]
        /// Снимки, на которые сад ссылался в прошлый раз: с сервера уходит
        /// только тот, на который перестали ссылаться здесь.
        var shown: Set<String> = []
        /// Комнаты, которые удалили на другом телефоне, а здесь в них ещё
        /// растения: заново их не отправляем, опустеют — уйдут и отсюда.
        var gone: Set<String> = []
        /// Первый приём из iCloud прошёл — до него ничего не отправляем.
        var primed = false
        /// Состояние движка синхронизации — непрозрачные данные CloudKit.
        var engine: Data?

        init() {}

        /// Без ключа — значение по умолчанию: файл прежней сборки не должен
        /// сбрасывать синхронизацию.
        init(from decoder: any Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            known = try box.decodeIfPresent([String: Mark].self,
                                            forKey: .known) ?? [:]
            shown = try box.decodeIfPresent(Set<String>.self,
                                            forKey: .shown) ?? []
            gone = try box.decodeIfPresent(Set<String>.self,
                                           forKey: .gone) ?? []
            primed = try box.decodeIfPresent(Bool.self, forKey: .primed)
                ?? false
            engine = try box.decodeIfPresent(Data.self, forKey: .engine)
        }
    }

    /// Книга телефона: чем он занят и что помнит о своей и чужой зоне.
    struct Ledger: Codable, Equatable {
        var mode = Mode.off
        /// Своя зона — сад хозяина в его приватной базе.
        var own = Book()
        /// Чужая зона — общий сад, куда пригласили.
        var guest = Book()
        /// Зона общего сада: имя и номер хозяина в iCloud.
        var zone: String?
        var host: String?
        /// Чем телефон был занят до общего сада — к этому он вернётся.
        var before = Mode.off
        /// Общий сад начали принимать: свой сад уже убран в запас.
        var cleared = false
        /// Свой номер в iCloud.
        var me: String?

        init() {}

        init(from decoder: any Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            mode = try box.decodeIfPresent(Mode.self, forKey: .mode) ?? .off
            own = try box.decodeIfPresent(Book.self, forKey: .own) ?? Book()
            guest = try box.decodeIfPresent(Book.self, forKey: .guest)
                ?? Book()
            zone = try box.decodeIfPresent(String.self, forKey: .zone)
            host = try box.decodeIfPresent(String.self, forKey: .host)
            before = try box.decodeIfPresent(Mode.self, forKey: .before)
                ?? .off
            cleared = try box.decodeIfPresent(Bool.self, forKey: .cleared)
                ?? false
            me = try box.decodeIfPresent(String.self, forKey: .me)
        }

        /// Книга той зоны, с которой телефон работает сейчас.
        var book: Book {
            get { mode == .guest ? guest : own }
            set {
                if mode == .guest { guest = newValue } else { own = newValue }
            }
        }
    }

    /// Кто поливает с этого телефона: номер в iCloud, имя из профиля и
    /// форма глагола.
    struct Hand: Equatable {
        var id: String
        var name: String?
        var she: Bool
    }

    /// Что пришло из iCloud за раз.
    struct Arrival {
        var rooms: [RoomBody] = []
        var plants: [PlantBody] = []
        var pours: [Watering] = []
        /// Снимки, чьи файлы уже лежат в `Shots`.
        var photos: [String] = []
        /// Имена удалённых записей.
        var gone: [String] = []
        /// Системные поля пришедших записей — по имени записи.
        var tags: [String: Data] = [:]

        var isEmpty: Bool {
            rooms.isEmpty && plants.isEmpty && pours.isEmpty
                && photos.isEmpty && gone.isEmpty
        }
    }

    /// Что вышло из пришедшего — для уведомлений, напоминаний и виджета.
    struct Outcome: Equatable {
        /// Чужие поливы, которых здесь ещё не было.
        var news: [Watering] = []
        /// Растения, чья влажность пришла извне.
        var wet: Set<Plant.ID> = []
        /// Сменились состав, клички или обложки — Siri и виджету.
        var recast = false
        /// Удалённые снимки, на которые здесь никто не ссылается, — с диска.
        /// Ушедшее растение снимок не уносит: его вернут «Вернуть» на
        /// другом телефоне, а запись снимка уходит отдельно.
        var dropped: [String] = []
    }

    /// Что отправить: имена записей к сохранению и к удалению.
    struct Plan: Equatable {
        var saves: [String] = []
        var deletes: [String] = []

        var isEmpty: Bool { saves.isEmpty && deletes.isEmpty }
    }

    // MARK: - Имена записей

    /// Имя записи: вид и номер. Номер, в котором есть что-то кроме латиницы,
    /// цифр, точки, дефиса и подчёркивания, заменяется отпечатком — CloudKit
    /// принимает только такие имена.
    static func name(_ kind: Kind, _ id: String) -> String {
        kind.prefix + "-" + (safe(id) ? id : "h" + hex(id))
    }

    static func kind(of record: String) -> Kind? {
        guard let dash = record.firstIndex(of: "-") else { return nil }
        let prefix = String(record[..<dash])
        return Kind.allCases.first { $0.prefix == prefix }
    }

    /// Номер из имени записи — для снимка это имя файла.
    static func id(of record: String) -> String {
        guard let dash = record.firstIndex(of: "-") else { return record }
        return String(record[record.index(after: dash)...])
    }

    static func safe(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 200 && !id.hasPrefix("_")
            && id.unicodeScalars.allSatisfy {
                $0.isASCII && (CharacterSet.alphanumerics.contains($0)
                               || "._-".unicodeScalars.contains($0))
            }
    }

    /// Имя файла из чужой записи идёт в путь на диске — только простое: без
    /// папок и без точки впереди.
    static func safe(file: String) -> Bool {
        safe(file) && !file.hasPrefix(".")
    }

    private static func hex(_ text: String) -> String {
        String(Seeded.hash(text), radix: 16)
    }

    /// Ключ комнаты — от имени: две «Кухни», заведённые на двух телефонах до
    /// общего сада, станут одной комнатой, а не двумя.
    static func roomKey(_ name: String) -> String {
        "n" + hex(name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased())
    }

    /// Номер полива — от растения и мига: одна и та же запись из резервной
    /// копии на двух телефонах получит один номер и не задвоится.
    static func pourID(_ entry: Watering) -> String {
        let plant = safe(entry.plant) ? entry.plant : "h" + hex(entry.plant)
        let milliseconds = Int64((entry.when.timeIntervalSince1970 * 1_000)
            .rounded())
        return plant + "-" + String(milliseconds)
    }

    /// Снимки и портреты сада.
    static func photos(_ rooms: [Room]) -> Set<String> {
        Set(rooms.flatMap(\.plants).flatMap(\.files))
    }

    // MARK: - Записи

    static func body(_ room: Room) -> RoomBody {
        RoomBody(key: room.key ?? roomKey(room.name), name: room.name,
                 dacha: room.atDacha, rank: room.rank ?? 0,
                 edited: room.edited)
    }

    /// Растение в запись — без датчика и скана: они живут на своём телефоне.
    static func body(_ plant: Plant, in room: Room, at now: Date) -> PlantBody {
        var sent = plant
        sent.sensor = nil
        sent.scan = nil
        return PlantBody(plant: sent, room: room.key ?? roomKey(room.name),
                         roomName: room.name, at: now)
    }

    static func mark(of body: RoomBody, tag: Data?) -> Mark {
        Mark(tag: tag, edited: body.edited, rank: body.rank, name: body.name,
             dacha: body.dacha)
    }

    static func mark(of body: PlantBody, tag: Data?) -> Mark {
        Mark(tag: tag, edited: body.plant.edited, wet: body.plant.wet,
             tended: body.plant.tended, room: body.room, rank: body.plant.rank)
    }

    // MARK: - Места

    /// Места по порядку: у кого место есть и порядку не противоречит —
    /// остаётся, остальным — новые, между соседями. Сменённое место — запись
    /// к отправке, поэтому меняется как можно меньше мест.
    static func rank(_ ranks: [Double?]) -> [Double] {
        let count = ranks.count
        guard count > 0 else { return [] }
        // Самая длинная возрастающая цепочка из уже стоящих — она остаётся.
        var length = [Int](repeating: 0, count: count)
        var previous = [Int](repeating: -1, count: count)
        var best = -1
        for i in 0 ..< count {
            guard let value = ranks[i], value.isFinite else { continue }
            length[i] = 1
            for j in 0 ..< i {
                guard let before = ranks[j], length[j] > 0, before < value,
                      length[j] + 1 > length[i]
                else { continue }
                length[i] = length[j] + 1
                previous[i] = j
            }
            if best < 0 || length[i] > length[best] { best = i }
        }
        var keep = Set<Int>()
        var at = best
        while at >= 0 {
            keep.insert(at)
            at = previous[at]
        }
        var result = [Double](repeating: 0, count: count)
        var left: Double?
        var i = 0
        while i < count {
            if keep.contains(i), let value = ranks[i] {
                result[i] = value
                left = value
                i += 1
                continue
            }
            var j = i
            while j < count, !keep.contains(j) { j += 1 }
            let right = j < count ? ranks[j] : nil
            let run = j - i
            for k in 0 ..< run {
                switch (left, right) {
                case let (low?, high?):
                    result[i + k] = low + (high - low) * Double(k + 1)
                        / Double(run + 1)
                case let (low?, nil):
                    result[i + k] = low + Double(k + 1)
                case let (nil, high?):
                    result[i + k] = high - Double(run - k)
                case (nil, nil):
                    result[i + k] = Double(k + 1)
                }
            }
            i = j
        }
        // Между соседями не осталось чисел — всех по порядку заново.
        for k in 1 ..< count where !(result[k - 1] < result[k]) {
            return (0 ..< count).map { Double($0 + 1) }
        }
        return result
    }

    /// По местам: комнаты и растения в них. Без места — в хвосте, как стояли.
    static func order(_ rooms: inout [Room]) {
        rooms = sorted(rooms, rank: \.rank, tie: { $0.key ?? $0.name })
        for index in rooms.indices {
            rooms[index].plants = sorted(rooms[index].plants, rank: \.rank,
                                         tie: \.id)
        }
    }

    private static func sorted<Item>(_ items: [Item], rank: (Item) -> Double?,
                                     tie: (Item) -> String) -> [Item] {
        items.enumerated().sorted { a, b in
            let x = rank(a.element) ?? .infinity
            let y = rank(b.element) ?? .infinity
            if x != y { return x < y }
            if x == .infinity { return a.offset < b.offset }
            let s = tie(a.element)
            let t = tie(b.element)
            return s != t ? s < t : a.offset < b.offset
        }.map(\.element)
    }

    /// Две комнаты с одним именем экраны не различат: вторая получает номер.
    static func dedupe(_ rooms: inout [Room]) {
        var seen = Set<String>()
        for index in rooms.indices {
            let base = rooms[index].name
            var name = base
            var number = 2
            while seen.contains(name.lowercased()) {
                name = base + " " + String(number)
                number += 1
            }
            if name != base { rooms[index].name = name }
            seen.insert(name.lowercased())
        }
    }

    // MARK: - Свои правки

    static func newer(_ a: Date?, than b: Date?) -> Bool {
        (a ?? .distantPast) > (b ?? .distantPast)
    }

    /// Своё остаётся, только если оно ещё не ушло на сервер и новее
    /// пришедшего. Не ушедшего нет — верх берёт сервер: так все телефоны
    /// сходятся к одному.
    static func keeps(_ mine: Date?, over theirs: Date?, base: Date?) -> Bool {
        mine != base && newer(mine, than: theirs)
    }

    /// Отметка новее и мига, и версии сервера: часы телефонов чуть врут, а
    /// своя правка должна обогнать ту, от которой сделана.
    private static func stamp(after base: Date?, now: Date) -> Date {
        max(now, (base ?? .distantPast).addingTimeInterval(0.001))
    }

    /// Свои правки — к отправке: ключи комнатам, места комнатам и растениям,
    /// отметки тем, кого передвинули или переименовали мимо `Garden.change`,
    /// номера и подписи поливам. Повторный вызов ничего не меняет. Отвечает,
    /// поменялось ли что-нибудь.
    @discardableResult
    static func settle(_ rooms: inout [Room], _ log: inout [Watering],
                       book: Book, hand: Hand?, now: Date) -> Bool {
        var changed = false
        var keys = Set(rooms.compactMap(\.key))
        for index in rooms.indices where rooms[index].key == nil {
            var key = roomKey(rooms[index].name)
            if keys.contains(key) { key = "u" + UUID().uuidString }
            keys.insert(key)
            rooms[index].key = key
            changed = true
        }
        let places = rank(rooms.map(\.rank))
        for index in rooms.indices where rooms[index].rank != places[index] {
            rooms[index].rank = places[index]
            changed = true
        }
        for r in rooms.indices {
            let key = rooms[r].key ?? ""
            if let mark = book.known[name(.room, key)],
               rooms[r].edited == mark.edited,
               rooms[r].name != mark.name
                || rooms[r].atDacha != (mark.dacha ?? false)
                || rooms[r].rank != mark.rank {
                rooms[r].edited = stamp(after: mark.edited, now: now)
                changed = true
            }
            let ranks = rank(rooms[r].plants.map(\.rank))
            for p in rooms[r].plants.indices {
                if rooms[r].plants[p].rank != ranks[p] {
                    rooms[r].plants[p].rank = ranks[p]
                    changed = true
                }
                let plant = rooms[r].plants[p]
                if let mark = book.known[name(.plant, plant.id)],
                   plant.edited == mark.edited,
                   mark.room != key || mark.rank != plant.rank {
                    rooms[r].plants[p].edited = stamp(after: mark.edited,
                                                      now: now)
                    changed = true
                }
            }
        }
        if let hand {
            for index in log.indices where log[index].id == nil {
                log[index].id = pourID(log[index])
                if log[index].hand == nil, log[index].by == nil {
                    log[index].hand = hand.id
                    log[index].by = hand.name
                    log[index].she = hand.she
                }
                changed = true
            }
        }
        return changed
    }

    /// Что отправить: всё, чего сервер не знает или знает старым, и удаления
    /// того, чего в саду больше нет. Растения и комнаты без ключа или места
    /// ещё не разобраны `settle` — их не отправляем, но и не удаляем.
    static func outgoing(_ rooms: [Room], _ log: [Watering], book: Book,
                         has: (String) -> Bool) -> Plan {
        var plan = Plan()
        var alive = Set<String>()
        for room in rooms {
            // Растения в комнате без ключа живы, хоть и не разобраны.
            for plant in room.plants { alive.insert(name(.plant, plant.id)) }
            guard let key = room.key else { continue }
            let record = name(.room, key)
            alive.insert(record)
            if let rank = room.rank, !book.gone.contains(record) {
                let mark = book.known[record]
                if mark == nil || room.edited != mark?.edited
                    || room.name != mark?.name
                    || room.atDacha != (mark?.dacha ?? false)
                    || rank != mark?.rank {
                    plan.saves.append(record)
                }
            }
            for plant in room.plants {
                let record = name(.plant, plant.id)
                guard let rank = plant.rank else { continue }
                let mark = book.known[record]
                if mark == nil || plant.edited != mark?.edited
                    || plant.wet != mark?.wet || plant.tended != mark?.tended
                    || key != mark?.room || rank != mark?.rank {
                    plan.saves.append(record)
                }
            }
        }
        for entry in log {
            guard let id = entry.id else { continue }
            let record = name(.pour, id)
            alive.insert(record)
            if book.known[record] == nil { plan.saves.append(record) }
        }
        for file in photos(rooms).sorted() where safe(file: file) {
            let record = name(.photo, file)
            alive.insert(record)
            if book.known[record] == nil, has(file) {
                plan.saves.append(record)
            }
        }
        for record in book.known.keys.sorted() where !alive.contains(record) {
            guard let sort = kind(of: record) else { continue }
            // Чужой снимок, на который здесь ещё не ссылались, не трогаем:
            // растение с ним может прийти следом.
            if sort == .photo, !book.shown.contains(id(of: record)) {
                continue
            }
            plan.deletes.append(record)
        }
        return plan
    }

    // MARK: - Чужие правки

    /// Слепок растения на миг `from` — к мигу `now`: земля сохла и там.
    static func aged(_ plant: Plant, from: Date, to now: Date,
                     outdoor: Bool) -> Plant {
        var aged = plant
        let seconds = now.timeIntervalSince(from)
        guard seconds > 0 else { return aged }
        let boost = outdoor && Climate.boost != 1 ? Climate.boost : 1
        aged.dry(days: seconds * Garden.speed / 86_400 * boost)
        return aged
    }

    /// Пришедшее из iCloud — поверх своего. Порядок такой: комнаты, растения,
    /// поливы, снимки, удаления; комнаты удаляются последними — их растения
    /// могли уйти тем же разом.
    static func apply(_ arrival: Arrival, to rooms: inout [Room],
                      log: inout [Watering], book: inout Book, me: String?,
                      now: Date) -> Outcome {
        var outcome = Outcome()
        let before = cast(rooms)

        for body in arrival.rooms where safe(body.key) {
            let record = name(.room, body.key)
            let mark = book.known[record]
            if let index = rooms.firstIndex(where: { $0.key == body.key }) {
                if !keeps(rooms[index].edited, over: body.edited,
                          base: mark?.edited) {
                    rooms[index].name = body.name
                    rooms[index].dacha = body.dacha ? true : nil
                    rooms[index].rank = body.rank
                    rooms[index].edited = body.edited
                }
            } else {
                rooms.append(Room(name: body.name, plants: [],
                                  dacha: body.dacha ? true : nil,
                                  key: body.key, edited: body.edited,
                                  rank: body.rank))
            }
            book.known[record] = self.mark(of: body,
                                           tag: arrival.tags[record])
            book.gone.remove(record)
        }

        for body in arrival.plants where safe(body.room) {
            let record = name(.plant, body.plant.id)
            let mark = book.known[record]
            book.known[record] = self.mark(of: body, tag: arrival.tags[record])
            var remote = body.plant
            remote.sensor = nil
            remote.scan = nil
            if let shot = remote.shot, !safe(file: shot) { remote.shot = nil }
            if let portrait = remote.portrait, !safe(file: portrait) {
                remote.portrait = nil
            }
            let roomName = rooms.first { $0.key == body.room }?.name
                ?? body.roomName
            remote = aged(remote, from: body.at, to: now,
                          outdoor: Climate.outdoor(roomName))
            guard let found = find(remote.id, in: rooms) else {
                let to = home(body.room, named: body.roomName, in: &rooms)
                rooms[to].plants.append(remote)
                outcome.wet.insert(remote.id)
                continue
            }
            let (r, p) = found
            let mine = rooms[r].plants[p]
            let keepBody = keeps(mine.edited, over: remote.edited,
                                 base: mark?.edited)
            let keepWet = mine.wet == remote.wet
                || keeps(mine.wet, over: remote.wet, base: mark?.wet)
            let keepCare = mine.tended == remote.tended
                || keeps(mine.tended, over: remote.tended, base: mark?.tended)
            var merged = keepBody ? mine : remote
            merged.sensor = mine.sensor
            merged.scan = mine.scan
            let water = keepWet ? mine : remote
            merged.moisture = water.moisture
            merged.wet = water.wet
            let care = keepCare ? mine : remote
            merged.care = care.care
            merged.tended = care.tended
            if !keepWet { outcome.wet.insert(mine.id) }
            if !keepBody, rooms[r].key != body.room {
                rooms[r].plants.remove(at: p)
                let to = home(body.room, named: body.roomName, in: &rooms)
                rooms[to].plants.append(merged)
            } else {
                rooms[r].plants[p] = merged
            }
        }

        if !arrival.pours.isEmpty {
            var have = Set(log.compactMap(\.id))
            // Своя запись без номера — та же, что пришла с номером от неё же:
            // резервная копия на двух телефонах не должна задвоить журнал.
            var unsigned: [String: Int] = [:]
            for index in log.indices where log[index].id == nil {
                unsigned[pourID(log[index])] = index
            }
            var added = false
            for entry in arrival.pours {
                guard let id = entry.id else { continue }
                let record = name(.pour, id)
                book.known[record] = Mark(tag: arrival.tags[record])
                guard !have.contains(id) else { continue }
                have.insert(id)
                if let index = unsigned[id] {
                    log[index] = entry
                    continue
                }
                log.append(entry)
                added = true
                if let hand = entry.hand, hand != me {
                    outcome.news.append(entry)
                }
            }
            if added {
                log = log.enumerated().sorted {
                    ($0.element.when, $0.offset) < ($1.element.when, $1.offset)
                }.map(\.element)
            }
        }

        for file in arrival.photos where safe(file: file) {
            let record = name(.photo, file)
            book.known[record] = Mark(tag: arrival.tags[record])
        }

        var candidates: [String] = []
        for record in arrival.gone {
            book.known[record] = nil
            switch kind(of: record) {
            case .plant?:
                for r in rooms.indices {
                    guard let p = rooms[r].plants.firstIndex(where: {
                        name(.plant, $0.id) == record
                    }) else { continue }
                    rooms[r].plants.remove(at: p)
                    break
                }
            case .pour?:
                log.removeAll { $0.id.map { name(.pour, $0) } == record }
            case .photo?:
                candidates.append(id(of: record))
            case .room?:
                if rooms.contains(where: {
                    $0.key.map { name(.room, $0) } == record
                }) {
                    book.gone.insert(record)
                }
            case nil:
                break
            }
        }
        // Удалённая на другом телефоне комната уходит, когда опустеет.
        let emptied = Set(rooms.compactMap { room -> String? in
            guard let key = room.key, room.plants.isEmpty else { return nil }
            let record = name(.room, key)
            return book.gone.contains(record) ? record : nil
        })
        if !emptied.isEmpty {
            rooms.removeAll { room in
                room.key.map { emptied.contains(name(.room, $0)) } ?? false
            }
            book.gone.subtract(emptied)
        }

        order(&rooms)
        dedupe(&rooms)
        outcome.dropped = Set(candidates).subtracting(photos(rooms)).sorted()
        outcome.recast = cast(rooms) != before
        return outcome
    }

    private static func find(_ id: Plant.ID, in rooms: [Room])
        -> (Int, Int)? {
        for r in rooms.indices {
            if let p = rooms[r].plants.firstIndex(where: { $0.id == id }) {
                return (r, p)
            }
        }
        return nil
    }

    /// Комната растения; не пришла ещё — заводится по имени из его записи.
    private static func home(_ key: String, named name: String,
                             in rooms: inout [Room]) -> Int {
        if let index = rooms.firstIndex(where: { $0.key == key }) {
            return index
        }
        rooms.append(Room(name: name, plants: [], key: key))
        return rooms.count - 1
    }

    /// Что видят Siri и виджет: комнаты, клички, обложки.
    private static func cast(_ rooms: [Room]) -> [String] {
        rooms.map { room in
            room.name + "|" + room.plants.map {
                $0.id + ":" + $0.name + ":" + ($0.cover ?? "")
            }.joined(separator: ",")
        }
    }

    // MARK: - Новый телефон

    /// Нетронутые макетные растения, которых нет в iCloud, — долой: иначе
    /// новый телефон вернул бы в сад макет, который хозяин давно убрал.
    /// Нетронутое — не правленное и ни разу не политое; пустые макетные
    /// комнаты уходят вслед. Отвечает, убрал ли что-нибудь.
    @discardableResult
    static func prune(_ rooms: inout [Room], log: [Watering],
                      book: Book) -> Bool {
        let seeded = Set(Seed.rooms.flatMap(\.plants).map(\.id))
        let named = Set(Seed.rooms.map(\.name))
        let watered = Set(log.map(\.plant))
        var changed = false
        for index in rooms.indices {
            let count = rooms[index].plants.count
            rooms[index].plants.removeAll { plant in
                seeded.contains(plant.id) && plant.edited == nil
                    && !watered.contains(plant.id)
                    && book.known[name(.plant, plant.id)] == nil
            }
            if rooms[index].plants.count != count { changed = true }
        }
        let count = rooms.count
        rooms.removeAll { room in
            room.plants.isEmpty && named.contains(room.name)
                && room.edited == nil
                && book.known[name(.room, room.key ?? roomKey(room.name))]
                    == nil
        }
        return changed || rooms.count != count
    }

    /// Сад только что поставлен: ни одного полива, а растения — нетронутые
    /// макетные или их нет вовсе. Такой сад нечего беречь, а свой сад в
    /// iCloud при нём — повод принять его заново: файл сада мог пропасть.
    static func pristine(_ rooms: [Room], _ log: [Watering]) -> Bool {
        guard log.isEmpty else { return false }
        let seeded = Set(Seed.rooms.flatMap(\.plants).map(\.id))
        return rooms.flatMap(\.plants).allSatisfy {
            seeded.contains($0.id) && $0.edited == nil
        }
    }

    // MARK: - Кто полил

    /// «Полила Маша»; без имени — пусто.
    static func verb(_ name: String?, she: Bool?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return she == true ? Lang.format("Полила %@", name)
            : Lang.format("Полил %@", name)
    }

    /// Подпись чужого полива: «Полила Маша, 9:55», вчерашний — «Полила
    /// Маша, вчера», раньше — с датой. Свой полив и полив без подписи —
    /// пусто.
    static func credit(_ entry: Watering, me: String?, now: Date = Date(),
                       calendar: Calendar = .current) -> String? {
        guard let hand = entry.hand, hand != me,
              let verb = verb(entry.by, she: entry.she) else { return nil }
        if calendar.isDate(entry.when, inSameDayAs: now) {
            let time = entry.when.formatted(
                Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
                    .hour(.defaultDigits(amPM: .abbreviated))
                    .minute(.twoDigits).locale(Lang.locale))
            return Lang.format("%1$@, %2$@", verb, time)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(entry.when, inSameDayAs: yesterday) {
            return Lang.format("%@, вчера", verb)
        }
        var style = Date.FormatStyle(calendar: calendar,
                                     timeZone: calendar.timeZone)
            .day().month(.wide).locale(Lang.locale)
        if calendar.component(.year, from: entry.when)
            != calendar.component(.year, from: now) {
            style = style.year()
        }
        return Lang.format("%1$@, %2$@", verb, entry.when.formatted(style))
    }

    /// «Маша полила: Баксик и Шуба» — одно уведомление на поливавшего.
    /// Клички — после двоеточия: так их не нужно склонять.
    static func news(name: String, she: Bool, plants: [String]) -> String {
        let list: String
        switch plants.count {
        case 0:
            list = ""
        case 1:
            list = plants[0]
        case 2 ... 3:
            list = Lang.format("%1$@ и %2$@",
                               plants.dropLast().joined(separator: ", "),
                               plants[plants.count - 1])
        default:
            list = Lang.format("%1$@ и ещё %2$@",
                               plants.prefix(2).joined(separator: ", "),
                               Lang.format("%lld растений", plants.count - 2))
        }
        return she ? Lang.format("%1$@ полила: %2$@", name, list)
            : Lang.format("%1$@ полил: %2$@", name, list)
    }

    /// Женское ли имя — по последней букве, с исключениями: Никита, Илья и
    /// уменьшительные мужские тоже кончаются на «а» и «я». Только догадка по
    /// умолчанию — в группе «Семья» её можно поправить.
    static func she(_ name: String) -> Bool {
        let first = name.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .split { !$0.isLetter }.first.map(String.init) ?? ""
        guard let last = first.last, endings.contains(last) else {
            return false
        }
        return !men.contains(first)
    }

    private static let endings: Set<Character> = ["а", "я", "a"]

    private static let men: Set<String> = [
        "никита", "илья", "фома", "лука", "кузьма", "савва", "данила",
        "гаврила", "добрыня", "миша", "саша", "женя", "паша", "петя", "ваня",
        "дима", "коля", "вова", "леша", "алеша", "сережа", "гоша", "гриша",
        "слава", "валера", "толя", "юра", "федя", "сеня", "степа", "боря",
        "костя", "витя", "леня", "вася", "яша", "митя", "гена", "лева",
        "жора", "кеша", "сема", "тема", "рома", "андрюша", "антоша", "ванюша",
        "илюша", "саня", "леха", "тоха", "миха", "даня", "тоша", "кузя",
        "nikita", "ilya", "ilia", "misha", "sasha", "luca", "luka", "andrea",
        "joshua", "dima", "kolya", "vanya", "petya", "pasha", "zhenya", "yura",
        "tolya", "vova", "slava", "kostya", "vitya", "vasya", "mitya", "roma",
    ]
}
