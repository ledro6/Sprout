import CloudKit
import Foundation
import Observation
import UIKit
import UserNotifications

/// Общий сад на семью через iCloud. Свой сад — в приватной базе хозяина и на
/// всех его устройствах; пригласили — общий сад из базы «общее со мной».
/// Арифметика слияния — в `Family`; здесь CloudKit: движок синхронизации
/// (`CKSyncEngine`), приглашение (`CKShare` на всю зону сада), участники.
///
/// Телефон занят одной зоной за раз: своей или общей. Пока он в общем саду,
/// свой сад лежит в запасе (`garden-own.json`) и возвращается при выходе.
///
/// Возможность iCloud в проекте выключена нарочно, как WeatherKit и HomeKit
/// (README, «Общий сад»): без неё первое же обращение к CloudKit роняет
/// приложение. Поэтому всё здесь — за `enabled`, и до него ни одного
/// обращения к `CKContainer`.
@MainActor
@Observable
final class Kinship {
    static let shared = Kinship()

    /// Ключ `CKSharingSupported` в Info.plist ставят вместе с возможностями
    /// iCloud: без него система и приглашения в приложение не отдаёт. Нет
    /// ключа — нет группы «Семья» и ни одного обращения к CloudKit.
    nonisolated static let enabled =
        (Bundle.main.object(forInfoDictionaryKey: "CKSharingSupported")
            as? Bool) ?? false

    static let container = "iCloud.com.ledro6.sprout"

    /// Зона сада в приватной базе хозяина — она же уходит семье целиком.
    static let zone = "Garden"

    /// Что сказать в группе «Семья».
    enum Status: Equatable {
        case idle
        case syncing
        case joining
        case synced(Date)
        /// Что-то мешает — по-русски и что делать.
        case trouble(String)
        /// Просто новость: вышли из общего сада, сад закрыли.
        case note(String)

        /// Есть что сказать и при выключенном саде в iCloud.
        var speaks: Bool {
            switch self {
            case .trouble, .note: true
            default: false
            }
        }
    }

    /// Участник общего сада.
    struct Person: Identifiable, Equatable {
        var id: String
        var name: String
        var owner: Bool
        var accepted: Bool
        var me: Bool
    }

    private(set) var mode = Family.Mode.off
    private(set) var status = Status.idle
    private(set) var people: [Person] = []
    /// Своим садом делятся: в нём есть кто-то, кроме хозяина.
    private(set) var sharing = false
    /// Приглашение или выход в пути — кнопки ждут.
    private(set) var busy = false
    /// Имена участников по номеру в iCloud — подписать полив без имени.
    private(set) var names: [String: String] = [:]

    /// «Сообщать, когда полили другие» — по умолчанию да.
    var news = true {
        didSet { store.set(!news, forKey: Key.quiet) }
    }

    /// Как подписывать свои поливы; пусто — догадкой по имени.
    var she: Bool? = nil {
        didSet { store.set(she, forKey: Key.she) }
    }

    @ObservationIgnored private var ledger: Family.Ledger
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var priming = false
    @ObservationIgnored private var queued = false
    /// Сервер отказал так, что повтор не поможет (места нет, только
    /// просмотр): до следующего возвращения на экран не отправляем.
    @ObservationIgnored private var stalled = false
    /// Записи, которые сервер отверг не на время: повторяем их только после
    /// возвращения на экран, а не по кругу.
    @ObservationIgnored private var stuck: Set<String> = []
    @ObservationIgnored private var sharer: Sharer?
    @ObservationIgnored private let store = UserDefaults.standard

    private enum Key {
        static let quiet = "familyQuiet"
        static let she = "familyShe"
    }

    private static let body: CKRecord.FieldKey = "body"
    private static let file: CKRecord.FieldKey = "file"

    private init() {
        let defaults = UserDefaults.standard
        news = !defaults.bool(forKey: Key.quiet)
        she = defaults.object(forKey: Key.she) as? Bool
        let read = Self.read() ?? Family.Ledger()
        ledger = read
        mode = read.mode
    }

    // MARK: - Жизнь движка

    /// При запуске, раньше первого окна: движок должен быть готов к тихому
    /// пушу, с которым система будит приложение.
    func launch() {
        guard Self.enabled, ledger.mode != .off else { return }
        start()
    }

    /// Возвращение на экран: свежее из iCloud сразу, не дожидаясь пуша.
    func wake() {
        guard Self.enabled, ledger.mode != .off else { return }
        stalled = false
        stuck = []
        guard let engine else {
            start()
            return
        }
        guard ledger.book.primed else {
            Task { await prime() }
            return
        }
        pass()
        Task {
            await refresh()
            try? await engine.fetchChanges()
        }
    }

    private func start() {
        guard Self.enabled, engine == nil, ledger.mode != .off else { return }
        let garden = Garden.shared
        // Свой сад в iCloud есть, а на телефоне — нетронутый макет: файл сада
        // пропал. Принимаем сад из iCloud заново, а не стираем его макетом.
        if ledger.mode == .own, ledger.own.primed,
           !garden.rooms.flatMap(\.plants).isEmpty,
           Family.pristine(garden.rooms, garden.log),
           ledger.own.known.keys.contains(where: {
               Family.kind(of: $0) == .plant
           }) {
            ledger.own = Family.Book()
            persist()
        }
        let container = CKContainer(identifier: Self.container)
        let guest = ledger.mode == .guest
        let database = guest ? container.sharedCloudDatabase
            : container.privateCloudDatabase
        let saved = ledger.book.engine.flatMap {
            try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self,
                                      from: $0)
        }
        let made = CKSyncEngine(CKSyncEngine.Configuration(
            database: database, stateSerialization: saved, delegate: self))
        engine = made
        if !guest, !ledger.own.primed {
            made.state.add(pendingDatabaseChanges: [
                .saveZone(CKRecordZone(zoneID: zoneID)),
            ])
        }
        // Тихие пуши о чужих правках; без возможности Push Notifications
        // система просто откажет, не роняя приложение.
        Task { @MainActor in
            UIApplication.shared.registerForRemoteNotifications()
        }
        Task { await prime() }
    }

    private func stop() {
        let gone = engine
        engine = nil
        priming = false
        Task { await gone?.cancelOperations() }
    }

    /// Первый приём: сперва всё из iCloud, и только потом своё — так новый
    /// телефон не отправит в общий сад макет, а гость — свой прежний сад.
    private func prime() async {
        guard let engine, !ledger.book.primed, !priming else { return }
        priming = true
        defer { priming = false }
        let container = CKContainer(identifier: Self.container)
        do {
            switch try await container.accountStatus() {
            case .available:
                break
            case .noAccount:
                status = .trouble(Self.noAccount)
                return
            case .restricted:
                status = .trouble(Self.restricted)
                return
            default:
                status = .trouble(Self.unsure)
                return
            }
            if ledger.me == nil {
                ledger.me = try await container.userRecordID().recordName
                persist()
            }
            status = ledger.mode == .guest ? .joining : .syncing
            try await engine.fetchChanges()
        } catch {
            status = .trouble(Self.message(for: error))
            return
        }
        guard self.engine === engine, !ledger.book.primed else { return }
        var book = ledger.book
        book.primed = true
        ledger.book = book
        if ledger.mode == .own {
            let garden = Garden.shared
            let cloud = book.known.keys.contains {
                let kind = Family.kind(of: $0)
                return kind == .room || kind == .plant
            }
            // Сад целиком — с архивом: архивные растения тоже в iCloud.
            var rooms = garden.whole
            if cloud, Family.prune(&rooms, log: garden.log, book: book) {
                garden.adopt(rooms: rooms, log: garden.log, recast: true)
            }
        }
        persist()
        status = .synced(Date())
        pass()
        await refresh()
    }

    private var zoneID: CKRecordZone.ID {
        if ledger.mode == .guest, let zone = ledger.zone,
           let host = ledger.host {
            return CKRecordZone.ID(zoneName: zone, ownerName: host)
        }
        return CKRecordZone.ID(zoneName: Self.zone,
                               ownerName: CKCurrentUserDefaultName)
    }

    /// Своя ли зона: в общей базе бывают сады разных хозяев, и у всех она
    /// называется одинаково.
    private func ours(_ zone: CKRecordZone.ID) -> Bool {
        if ledger.mode == .guest {
            return zone.zoneName == ledger.zone && zone.ownerName == ledger.host
        }
        return zone.zoneName == Self.zone
    }

    // MARK: - Свои правки

    /// После каждой записи сада: свои правки — в очередь движка. Раз за
    /// проход очереди главного потока, сколько бы записей ни было.
    func nudge() {
        guard Self.enabled, ledger.mode != .off, !queued else { return }
        queued = true
        Task { @MainActor in
            self.queued = false
            self.pass()
        }
    }

    private var hand: Family.Hand? {
        guard let me = ledger.me else { return nil }
        let owner = Garden.shared.owner
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Family.Hand(id: me, name: owner.isEmpty ? nil : owner,
                           she: she ?? Family.she(owner))
    }

    /// Как подписаны свои поливы сейчас — для выбора в группе «Семья».
    var signsShe: Bool {
        she ?? Family.she(Garden.shared.owner)
    }

    private func pass() {
        guard let engine, ledger.book.primed else { return }
        let garden = Garden.shared
        var rooms = garden.whole
        var log = garden.log
        var book = ledger.book
        if Family.settle(&rooms, &log, book: book, hand: hand, now: Date()) {
            garden.adopt(rooms: rooms, log: log, recast: false)
        }
        guard !stalled else { return }
        var plan = Family.outgoing(rooms, log, book: book, has: Shots.has)
        plan.saves.removeAll { stuck.contains($0) }
        plan.deletes.removeAll { stuck.contains($0) }
        book.shown = Family.photos(rooms)
        if book != ledger.book {
            ledger.book = book
            persist()
        }
        let zone = zoneID
        let pending = engine.state.pendingRecordZoneChanges
        let waiting = Set(pending)
        let wanted = Set(plan.deletes)
        var add: [CKSyncEngine.PendingRecordZoneChange] = []
        // Удаление, которое больше не нужно, — вон из очереди: растение
        // вернули «Вернуть», пока удаление ещё не ушло.
        var drop = pending.filter { change in
            guard case .deleteRecord(let id) = change else { return false }
            return !wanted.contains(id.recordName)
        }
        for name in plan.saves {
            let id = CKRecord.ID(recordName: name, zoneID: zone)
            if !waiting.contains(.saveRecord(id)) { add.append(.saveRecord(id)) }
        }
        // Сохранение и удаление одной записи в одной отправке CloudKit не
        // примет — остаётся удаление.
        for name in plan.deletes {
            let id = CKRecord.ID(recordName: name, zoneID: zone)
            if waiting.contains(.saveRecord(id)) { drop.append(.saveRecord(id)) }
            if !waiting.contains(.deleteRecord(id)) {
                add.append(.deleteRecord(id))
            }
        }
        if !drop.isEmpty {
            engine.state.remove(pendingRecordZoneChanges: drop)
        }
        if !add.isEmpty { engine.state.add(pendingRecordZoneChanges: add) }
    }

    /// Запись для отправки — из сада, каким он стал к этому мигу. Того, что
    /// уже нет, не отправляем и из очереди убираем.
    private func record(for id: CKRecord.ID, at now: Date,
                        engine: CKSyncEngine) -> CKRecord? {
        let name = id.recordName
        guard let kind = Family.kind(of: name),
              let made = build(kind, id: id, at: now)
        else {
            engine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
            return nil
        }
        return made
    }

    private func build(_ kind: Family.Kind, id: CKRecord.ID,
                       at now: Date) -> CKRecord? {
        let name = id.recordName
        let garden = Garden.shared
        let record = blank(kind, id: id, tag: ledger.book.known[name]?.tag)
        let encoder = JSONEncoder()
        switch kind {
        case .room:
            guard let room = garden.whole.first(where: {
                $0.key.map { Family.name(.room, $0) } == name
            }), let data = try? encoder.encode(Family.body(room)) else {
                return nil
            }
            record.encryptedValues[Self.body] = data
        case .plant:
            var found: Data?
            for room in garden.whole {
                guard let plant = room.plants.first(where: {
                    Family.name(.plant, $0.id) == name
                }) else { continue }
                found = try? encoder.encode(Family.body(plant, in: room,
                                                        at: now))
                break
            }
            guard let data = found else { return nil }
            record.encryptedValues[Self.body] = data
        case .pour:
            guard let entry = garden.log.first(where: {
                $0.id.map { Family.name(.pour, $0) } == name
            }), let data = try? encoder.encode(entry) else { return nil }
            record.encryptedValues[Self.body] = data
        case .photo:
            let file = Family.id(of: name)
            guard Family.safe(file: file), Shots.has(file),
                  let url = Shots.url(file) else { return nil }
            record[Self.file] = CKAsset(fileURL: url)
        }
        return record
    }

    /// Запись поверх последней известной версии сервера — иначе он не
    /// примет её как правку той же записи.
    private func blank(_ kind: Family.Kind, id: CKRecord.ID,
                       tag: Data?) -> CKRecord {
        if let tag, let coder = try? NSKeyedUnarchiver(forReadingFrom: tag) {
            coder.requiresSecureCoding = true
            let record = CKRecord(coder: coder)
            coder.finishDecoding()
            if let record, record.recordID == id { return record }
        }
        return CKRecord(recordType: kind.rawValue, recordID: id)
    }

    private static func archive(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    // MARK: - Чужие правки

    private func fetched(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
        var arrival = Family.Arrival()
        for modification in changes.modifications
            where ours(modification.record.recordID.zoneID) {
            read(modification.record, into: &arrival)
        }
        for deletion in changes.deletions where ours(deletion.recordID.zoneID) {
            arrival.gone.append(deletion.recordID.recordName)
        }
        take(arrival)
    }

    /// Запись из iCloud — в пришедшее. Чужое проверяется: тело должно
    /// совпадать с именем записи, имя файла — быть простым.
    private func read(_ record: CKRecord, into arrival: inout Family.Arrival) {
        let name = record.recordID.recordName
        guard let kind = Family.kind(of: name) else { return }
        let data = record.encryptedValues[Self.body] as? Data
        let decoder = JSONDecoder()
        switch kind {
        case .room:
            guard let data,
                  let body = try? decoder.decode(Family.RoomBody.self,
                                                 from: data),
                  Family.name(.room, body.key) == name else { return }
            arrival.rooms.append(body)
            arrival.tags[name] = Self.archive(record)
        case .plant:
            guard let data,
                  let body = try? decoder.decode(Family.PlantBody.self,
                                                 from: data),
                  Family.name(.plant, body.plant.id) == name else { return }
            arrival.plants.append(body)
            arrival.tags[name] = Self.archive(record)
        case .pour:
            guard let data,
                  let entry = try? decoder.decode(Watering.self, from: data),
                  let id = entry.id, Family.name(.pour, id) == name
            else { return }
            arrival.pours.append(entry)
        case .photo:
            let file = Family.id(of: name)
            guard Family.safe(file: file),
                  let asset = record[Self.file] as? CKAsset,
                  let url = asset.fileURL, Shots.take(url, as: file)
            else { return }
            arrival.photos.append(file)
        }
    }

    /// Пришедшее — в сад. Сперва свои правки разобраны (`settle`): места
    /// своих растений должны отвечать их порядку, прежде чем пришедшие
    /// встанут по местам.
    private func take(_ arrival: Family.Arrival) {
        guard !arrival.isEmpty else { return }
        let garden = Garden.shared
        // Тихий пуш будит приложение из фона, как кнопка в уведомлении:
        // сперва правки с диска (виджет), потом прошедшее время. Иначе сад,
        // не досохший с ухода в фон, записался бы мигом «сейчас», и эти часы
        // высыхания пропали бы, а пришедшее (`Family.aged`) — к «сейчас» —
        // встало бы рядом со своим, застывшим раньше.
        garden.reload()
        garden.advance()
        var rooms = garden.whole
        var log = garden.log
        var book = ledger.book
        let primed = book.primed
        var recast = false
        if ledger.mode == .guest, !ledger.cleared {
            // Первое из общего сада: свой сад уже в запасе, здесь — общий.
            rooms = []
            log = []
            ledger.cleared = true
            recast = true
        }
        let now = Date()
        Family.settle(&rooms, &log, book: book, hand: hand, now: now)
        let outcome = Family.apply(arrival, to: &rooms, log: &log, book: &book,
                                   me: ledger.me, now: now)
        ledger.book = book
        persist()
        garden.adopt(rooms: rooms, log: log, recast: recast || outcome.recast)
        for file in outcome.dropped { Shots.drop(file) }
        // Пока сад принимается впервые, старые поливы — не новости.
        guard primed else { return }
        if !outcome.news.isEmpty {
            let news = outcome.news
            Task { await tell(news) }
        }
        if !outcome.wet.isEmpty { Task { await remind() } }
    }

    /// «Маша полила: Баксик и Шуба» — по уведомлению на поливавшего, только
    /// о свежих поливах и если хозяин не против.
    private func tell(_ news: [Watering]) async {
        guard self.news, await Notifier.allowed() else { return }
        let now = Date()
        let fresh = news.filter { now.timeIntervalSince($0.when) < 12 * 3_600 }
        let garden = Garden.shared
        let groups = Dictionary(grouping: fresh) { $0.hand ?? "" }
        for key in groups.keys.sorted() {
            guard let entries = groups[key], let first = entries.first
            else { continue }
            var plants: [String] = []
            for entry in entries {
                guard let name = garden.plant(id: entry.plant)?.name,
                      !plants.contains(name) else { continue }
                plants.append(name)
            }
            guard !plants.isEmpty else { continue }
            let by = first.by?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (by?.isEmpty == false ? by : nil) ?? names[key]
                ?? Lang.text("Кто-то из семьи")
            let note = UNMutableNotificationContent()
            note.title = Lang.text("Общий сад")
            note.body = Family.news(name: name, she: first.she ?? false,
                                    plants: plants)
            note.sound = .default
            let request = UNNotificationRequest(
                identifier: "family-" + UUID().uuidString, content: note,
                trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Полил кто-то другой — напоминание о его растениях больше не нужно.
    /// Пока на сад смотрят, напоминаний нет вовсе; в фоне их ставим заново
    /// по нынешнему саду, как при уходе с экрана.
    private func remind() async {
        guard UIApplication.shared.applicationState != .active else { return }
        let garden = Garden.shared
        await Dachnik.shared.post(garden.rooms)
        let settings = Settings.shared
        guard settings.reminders else { return }
        await Notifier.schedule(in: Dachnik.shared.reminded(garden.rooms))
    }

    /// Ответ сервера на отправку: что принято — то и известно о нём; что
    /// не принято — разбираем, и очередь пересчитывается заново.
    private func confirm(_ sent: CKSyncEngine.Event.SentRecordZoneChanges) {
        var book = ledger.book
        let decoder = JSONDecoder()
        for record in sent.savedRecords {
            let name = record.recordID.recordName
            guard let kind = Family.kind(of: name) else { continue }
            let data = record.encryptedValues[Self.body] as? Data
            switch kind {
            case .room:
                if let data, let body = try? decoder.decode(
                    Family.RoomBody.self, from: data) {
                    book.known[name] = Family.mark(of: body,
                                                   tag: Self.archive(record))
                }
            case .plant:
                if let data, let body = try? decoder.decode(
                    Family.PlantBody.self, from: data) {
                    book.known[name] = Family.mark(of: body,
                                                   tag: Self.archive(record))
                }
            case .pour, .photo:
                book.known[name] = Family.Mark()
            }
        }
        for id in sent.deletedRecordIDs { book.known[id.recordName] = nil }
        var conflicts = Family.Arrival()
        var lost = false
        var erased = false
        for failure in sent.failedRecordSaves {
            let name = failure.record.recordID.recordName
            switch failure.error.code {
            case .serverRecordChanged:
                // Кто-то успел раньше: его версия — как пришедшая, а своё,
                // если новее, уйдёт следующим заходом. Не разобрали версию
                // сервера — не спорим с ней по кругу.
                guard let server = failure.error.serverRecord else {
                    stuck.insert(name)
                    continue
                }
                switch Family.kind(of: name) {
                case .room?, .plant?:
                    read(server, into: &conflicts)
                    if conflicts.tags[name] == nil { stuck.insert(name) }
                case .pour?, .photo?:
                    book.known[name] = Family.Mark()
                case nil:
                    break
                }
            case .zoneNotFound:
                lost = true
            case .userDeletedZone:
                // Сад удалили из iCloud в Настройках — как в `zones`: зону
                // заново не заводим и сад обратно не отправляем.
                erased = true
            case .unknownItem:
                book.known[name] = nil
            case .permissionFailure:
                stalled = true
                status = .trouble(Self.readOnly)
            case .quotaExceeded:
                stalled = true
                status = .trouble(Self.full)
            case .networkFailure, .networkUnavailable, .zoneBusy,
                 .serviceUnavailable, .requestRateLimited, .notAuthenticated,
                 .operationCancelled, .accountTemporarilyUnavailable,
                 .batchRequestFailed:
                // Временное или чужая беда в той же отправке — повторится.
                break
            default:
                stuck.insert(name)
            }
        }
        for (id, error) in sent.failedRecordDeletes {
            switch error.code {
            case .unknownItem:
                book.known[id.recordName] = nil
            case .networkFailure, .networkUnavailable, .zoneBusy,
                 .serviceUnavailable, .requestRateLimited, .notAuthenticated,
                 .operationCancelled, .accountTemporarilyUnavailable,
                 .batchRequestFailed:
                break
            default:
                stuck.insert(id.recordName)
            }
        }
        ledger.book = book
        persist()
        if erased, ledger.mode == .own {
            turnOff(Self.erased)
            ledger.own = Family.Book()
            persist()
            return
        }
        if lost || erased {
            zoneLost()
            return
        }
        take(conflicts)
        nudge()
    }

    /// Зоны сада не стало. У гостя — общий сад закрыли; у хозяина зона
    /// заводится снова, и сад уходит в неё целиком.
    private func zoneLost() {
        guard ledger.mode == .own else {
            close(Self.closed)
            return
        }
        var book = ledger.own
        book.known = [:]
        book.shown = []
        book.gone = []
        ledger.own = book
        persist()
        engine?.state.add(pendingDatabaseChanges: [
            .saveZone(CKRecordZone(zoneID: zoneID)),
        ])
        nudge()
    }

    private func zones(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges) {
        for deletion in changes.deletions where ours(deletion.zoneID) {
            if ledger.mode == .guest {
                close(Self.closed)
                return
            }
            switch deletion.reason {
            case .encryptedDataReset:
                // Ключи шифрования iCloud сброшены — своё уходит заново.
                zoneLost()
            default:
                // Сад удалили из iCloud в Настройках: на телефоне он
                // остаётся, а синхронизация выключается. Книга — с нуля:
                // включат снова — сад уйдёт в новую зону целиком.
                turnOff(Self.erased)
                ledger.own = Family.Book()
                persist()
            }
            return
        }
    }

    private func account(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn(currentUser: let user):
            ledger.me = user.recordName
            persist()
        case .signOut, .switchAccounts:
            // Сад в iCloud — прежней учётной записи: свой остаётся на
            // телефоне, общий уходит вместе с ней. Синхронизация — выключена
            // и после выхода из общего сада: iCloud больше нет.
            if ledger.mode == .guest {
                ledger.before = .off
                close(Self.signedOut)
            } else {
                turnOff(Self.signedOut)
            }
            ledger.own = Family.Book()
            ledger.me = nil
            persist()
        @unknown default:
            break
        }
    }

    // MARK: - Свой сад в iCloud

    /// «Сад в iCloud» на этом телефоне.
    func setOwn(_ on: Bool) {
        guard Self.enabled, ledger.mode != .guest else { return }
        if on {
            guard ledger.mode == .off else { return }
            setMode(.own)
            status = .syncing
            persist()
            start()
        } else if ledger.mode == .own {
            turnOff(nil)
        }
    }

    private func turnOff(_ message: String?) {
        stop()
        setMode(.off)
        people = []
        sharing = false
        status = message.map(Status.note) ?? .idle
        persist()
    }

    private func setMode(_ new: Family.Mode) {
        ledger.mode = new
        mode = new
    }

    // MARK: - Приглашение

    /// «Пригласить в сад»: приглашение на всю зону сада и системный лист —
    /// кого позвать, как отправить, кто уже в саду.
    func invite() async {
        guard Self.enabled, ledger.mode != .guest, !busy else { return }
        busy = true
        defer { busy = false }
        if ledger.mode == .off { setOwn(true) }
        let container = CKContainer(identifier: Self.container)
        do {
            let share = try await Self.share(in: container.privateCloudDatabase,
                                             zone: zoneID)
            present(share, container: container)
        } catch {
            status = .trouble(Self.message(for: error))
        }
    }

    /// Приглашение на зону сада: есть — оно, нет — новое. Зона заводится
    /// здесь же: движок мог ещё не успеть.
    private static func share(in database: CKDatabase,
                              zone: CKRecordZone.ID) async throws -> CKShare {
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare,
                             zoneID: zone)
        do {
            if let share = try await database.record(for: id) as? CKShare {
                return share
            }
        } catch let error as CKError
            where error.code == .unknownItem || error.code == .zoneNotFound {
            // Приглашения ещё нет — заведём.
        }
        _ = try await database.save(CKRecordZone(zoneID: zone))
        let share = CKShare(recordZoneID: zone)
        share[CKShare.SystemFieldKey.title] = Lang.text("Наш сад")
        share.publicPermission = .none
        guard let saved = try await database.save(share) as? CKShare else {
            throw CKError(.internalError)
        }
        return saved
    }

    private func present(_ share: CKShare, container: CKContainer) {
        let controller = UICloudSharingController(share: share,
                                                  container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        let helper = Sharer(title: Lang.text("Наш сад")) {
            Task { @MainActor in
                await Kinship.shared.refresh()
                _ = await Notifier.ask(reminders: false)
            }
        }
        sharer = helper
        controller.delegate = helper
        Self.top()?.present(controller, animated: true)
    }

    private static func top() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?
            .rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    /// Участники — из приглашения на зону. Его нет — сад ни с кем не общий.
    func refresh() async {
        guard Self.enabled, ledger.mode != .off else {
            people = []
            sharing = false
            return
        }
        let container = CKContainer(identifier: Self.container)
        let database = ledger.mode == .guest ? container.sharedCloudDatabase
            : container.privateCloudDatabase
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare,
                             zoneID: zoneID)
        do {
            if let share = try await database.record(for: id) as? CKShare {
                show(share)
            }
        } catch let error as CKError
            where error.code == .unknownItem || error.code == .zoneNotFound {
            people = []
            sharing = false
        } catch {
            // Нет связи — участники прежние.
        }
    }

    private func show(_ share: CKShare) {
        let me = share.currentUserParticipant?.userIdentity.userRecordID?
            .recordName
        var found: [Person] = []
        for participant in share.participants
            where participant.acceptanceStatus != .removed {
            let user = participant.userIdentity.userRecordID?.recordName
            found.append(Person(
                id: user ?? UUID().uuidString, name: Self.name(of: participant),
                owner: participant.role == .owner,
                accepted: participant.acceptanceStatus == .accepted,
                me: user != nil && user == me))
        }
        found.sort { ($0.owner ? 0 : 1, $0.name) < ($1.owner ? 0 : 1, $1.name) }
        people = found
        sharing = found.contains { !$0.owner }
        names = Dictionary(found.map { ($0.id, $0.name) },
                           uniquingKeysWith: { first, _ in first })
    }

    private static func name(of participant: CKShare.Participant) -> String {
        let identity = participant.userIdentity
        if let parts = identity.nameComponents {
            let formatter = PersonNameComponentsFormatter()
            formatter.style = .short
            let text = formatter.string(from: parts)
            if !text.isEmpty { return text }
        }
        if let mail = identity.lookupInfo?.emailAddress { return mail }
        if let phone = identity.lookupInfo?.phoneNumber { return phone }
        return Lang.text("Без имени")
    }

    /// Хозяин общего сада, куда пригласили.
    var host: String? { people.first { $0.owner && !$0.me }?.name }

    /// «Перестать делиться»: приглашение удаляется, семья теряет доступ, а
    /// сад остаётся у хозяина как был.
    func stopSharing() async {
        guard Self.enabled, ledger.mode == .own, !busy else { return }
        busy = true
        defer { busy = false }
        let container = CKContainer(identifier: Self.container)
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare,
                             zoneID: zoneID)
        do {
            _ = try await container.privateCloudDatabase.deleteRecord(withID: id)
        } catch let error as CKError where error.code == .unknownItem {
            // Приглашения уже нет.
        } catch {
            status = .trouble(Self.message(for: error))
            return
        }
        people = []
        sharing = false
        names = [:]
    }

    // MARK: - Гость

    /// Приглашение приняли: ссылка из Сообщений открыла приложение — см.
    /// `FamilyScene`. Своё же приглашение хозяину принимать незачем.
    func accept(_ metadata: CKShare.Metadata) {
        guard Self.enabled, metadata.containerIdentifier == Self.container,
              metadata.participantRole != .owner else { return }
        status = .joining
        let zone = metadata.share.recordID.zoneID
        Task {
            do {
                let container = CKContainer(identifier: Self.container)
                _ = try await container.accept(metadata)
            } catch {
                status = .trouble(Self.message(for: error))
                return
            }
            join(zone)
            _ = await Notifier.ask(reminders: false)
        }
    }

    private func join(_ zone: CKRecordZone.ID) {
        if ledger.mode == .guest, ledger.zone == zone.zoneName,
           ledger.host == zone.ownerName {
            wake()
            return
        }
        if ledger.mode != .guest {
            // Свой сад — в запас: вернётся, когда из общего выйдут.
            guard Self.keep(Garden.shared.state) else {
                status = .trouble(Self.unsure)
                return
            }
            ledger.before = ledger.mode
        }
        stop()
        setMode(.guest)
        ledger.zone = zone.zoneName
        ledger.host = zone.ownerName
        ledger.guest = Family.Book()
        // Сразу пусто: даже если общий сад окажется пустым, свой прежний в
        // него не уйдёт.
        ledger.cleared = true
        Garden.shared.adopt(rooms: [], log: [], recast: true)
        people = []
        sharing = false
        persist()
        status = .joining
        start()
    }

    /// «Выйти из общего сада»: участник удаляет у себя приглашение — так
    /// CloudKit выводит его из сада.
    func leave() async {
        guard Self.enabled, ledger.mode == .guest, !busy else { return }
        busy = true
        defer { busy = false }
        let container = CKContainer(identifier: Self.container)
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare,
                             zoneID: zoneID)
        do {
            _ = try await container.sharedCloudDatabase.deleteRecord(withID: id)
        } catch let error as CKError
            where error.code == .unknownItem || error.code == .zoneNotFound {
            // Сада уже нет — просто уходим.
        } catch {
            status = .trouble(Self.message(for: error))
            return
        }
        close(Self.left)
    }

    // MARK: - Удалить все данные

    /// «Удалить все данные», облачная часть. Гость выходит из общего сада —
    /// сам сад остаётся у хозяина. Свой сад в iCloud удаляется зоной целиком:
    /// с ней уходит и приглашение, семья теряет доступ. Пусто — вышло;
    /// иначе — что помешало, и тогда на телефоне ничего не стирается.
    func wipe() async -> String? {
        guard Self.enabled else { return nil }
        if ledger.mode == .guest {
            await leave()
            if ledger.mode == .guest {
                return Lang.text("Не получилось выйти из общего сада. Проверьте интернет и попробуйте ещё раз.")
            }
        }
        guard ledger.mode == .own else { return nil }
        guard !busy else {
            return Lang.text("Сад сейчас синхронизируется. Попробуйте через минуту.")
        }
        busy = true
        defer { busy = false }
        stop()
        let container = CKContainer(identifier: Self.container)
        do {
            _ = try await container.privateCloudDatabase
                .deleteRecordZone(withID: zoneID)
        } catch let error as CKError
            where error.code == .zoneNotFound || error.code == .unknownItem {
            // Зоны уже нет — удалять нечего.
        } catch {
            start()
            return Self.message(for: error)
        }
        ledger = Family.Ledger()
        setMode(.off)
        people = []
        sharing = false
        names = [:]
        status = .idle
        persist()
        return nil
    }

    /// Из общего сада — назад к своему: он ждал в запасе и досох за время
    /// отсутствия. Запаса нет — общий сад остаётся на телефоне своим, но
    /// уже без iCloud: в свою зону его не смешиваем.
    private func close(_ message: String) {
        stop()
        let garden = Garden.shared
        var back = ledger.before
        if let spare = Self.spare() {
            garden.adopt(rooms: Garden.join(spare.rooms(at: Date()),
                                             spare.archive),
                         log: spare.log,
                         recast: true)
        } else {
            back = .off
        }
        Self.dropSpare()
        ledger.guest = Family.Book()
        ledger.zone = nil
        ledger.host = nil
        ledger.cleared = false
        ledger.before = .off
        setMode(back)
        people = []
        sharing = false
        names = [:]
        persist()
        status = .note(message)
        if back == .own { start() }
    }

    // MARK: - Подписи

    /// Подпись чужого полива на экране растения: «Полила Маша, 9:55».
    func credit(_ entry: Watering) -> String? {
        Family.credit(named(entry), me: ledger.me)
    }

    /// Чужой полив меньше часа назад — для подписи на карточке, приглушённой
    /// капли и вопроса «Всё равно полить?». Имя — из приглашения, если в
    /// записи его нет.
    func recent(_ plant: Plant.ID, in log: [Watering],
                now: Date = Date()) -> Watering? {
        guard Self.enabled, mode != .off,
              let last = log.last(where: { $0.plant == plant })
        else { return nil }
        return Family.recent(plant, in: [named(last)], me: ledger.me, now: now)
    }

    /// Полив ещё не в iCloud — значок «ожидает отправки» в журнале растения.
    /// Состояние читается ради наблюдения: ушло — экран перерисуется.
    func waiting(_ entry: Watering) -> Bool {
        guard Self.enabled, mode != .off else { return false }
        _ = status
        return Family.waiting(entry, book: ledger.book)
    }

    /// Гость общего сада: стереть сад ему нельзя (`Family.mayErase`).
    var guest: Bool { Self.enabled && !Family.mayErase(mode) }

    /// Подпись в записи журнала, где время уже есть: «Полила Маша».
    func signature(_ entry: Watering) -> String? {
        guard let hand = entry.hand, hand != ledger.me else { return nil }
        let entry = named(entry)
        return Family.verb(entry.by, she: entry.she)
    }

    /// Без имени в записи — имя участника из приглашения.
    private func named(_ entry: Watering) -> Watering {
        var entry = entry
        let by = entry.by?.trimmingCharacters(in: .whitespacesAndNewlines)
        if by?.isEmpty != false, let hand = entry.hand {
            entry.by = names[hand]
        }
        return entry
    }

    // MARK: - Слова

    private static let noAccount = Lang.text(
        "Нет входа в iCloud. Войдите в Настройках — в самом верху.")
    private static let restricted = Lang.text(
        "iCloud на этом телефоне ограничен — сад не синхронизируется.")
    private static let unsure = Lang.text(
        "Не вышло связаться с iCloud. Попробую ещё раз позже.")
    private static let offline = Lang.text(
        "Нет связи с iCloud. Сад обновится, когда появится интернет.")
    private static let readOnly = Lang.text(
        "Хозяин сада разрешил только смотреть — ваши правки остаются на телефоне.")
    private static let full = Lang.text(
        "В iCloud закончилось место — новые правки туда не уходят.")
    private static let erased = Lang.text(
        "Сад удалили из iCloud. Он остался на телефоне; включите «Сад в iCloud», чтобы сохранить его снова.")
    private static let closed = Lang.text(
        "Общий сад закрыли — вернулся ваш прежний сад.")
    private static let left = Lang.text(
        "Вы вышли из общего сада — вернулся ваш прежний сад.")
    private static let signedOut = Lang.text(
        "Вы вышли из iCloud — синхронизация выключена, сад остался на телефоне.")

    private static func message(for error: any Error) -> String {
        guard let error = error as? CKError else { return unsure }
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy:
            return offline
        case .notAuthenticated:
            return noAccount
        case .quotaExceeded:
            return full
        case .permissionFailure:
            return readOnly
        case .participantMayNeedVerification:
            return Lang.text("iCloud просит подтвердить приглашение: откройте ссылку ещё раз.")
        case .tooManyParticipants:
            return Lang.text("В саду уже столько участников, сколько разрешает iCloud.")
        default:
            return unsure
        }
    }

    // MARK: - Хранение

    /// Рядом с садом: книга синхронизации и запас своего сада.
    private static var folder: URL? { Store.garden?.deletingLastPathComponent() }

    private static var ledgerFile: URL? {
        folder?.appendingPathComponent("family.json")
    }

    private static var spareFile: URL? {
        folder?.appendingPathComponent("garden-own.json")
    }

    private static func read() -> Family.Ledger? {
        guard let file = ledgerFile, let data = try? Data(contentsOf: file)
        else { return nil }
        return try? JSONDecoder().decode(Family.Ledger.self, from: data)
    }

    private func persist() {
        guard let file = Self.ledgerFile,
              let data = try? JSONEncoder().encode(ledger) else { return }
        try? data.write(to: file, options: .atomic)
    }

    private static func keep(_ state: GardenState) -> Bool {
        guard let file = spareFile,
              let data = try? JSONEncoder().encode(state) else { return false }
        do {
            try data.write(to: file, options: .atomic)
        } catch {
            return false
        }
        return true
    }

    private static func spare() -> GardenState? {
        guard let file = spareFile, let data = try? Data(contentsOf: file)
        else { return nil }
        return try? JSONDecoder().decode(GardenState.self, from: data)
    }

    private static func dropSpare() {
        guard let file = spareFile else { return }
        try? FileManager.default.removeItem(at: file)
    }
}

// MARK: - Движок синхронизации

extension Kinship: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event,
                     syncEngine: CKSyncEngine) async {
        guard syncEngine === engine else { return }
        switch event {
        case .stateUpdate(let update):
            var book = ledger.book
            book.engine = try? JSONEncoder().encode(update.stateSerialization)
            ledger.book = book
            persist()
        case .accountChange(let change):
            account(change)
        case .fetchedDatabaseChanges(let changes):
            zones(changes)
        case .fetchedRecordZoneChanges(let changes):
            fetched(changes)
        case .sentRecordZoneChanges(let sent):
            confirm(sent)
        case .sentDatabaseChanges(let sent):
            if sent.failedZoneSaves.contains(where: {
                $0.error.code == .quotaExceeded
            }) {
                status = .trouble(Self.full)
            }
        case .willFetchChanges, .willSendChanges:
            if case .trouble = status { break }
            status = ledger.mode == .guest && !ledger.book.primed
                ? .joining : .syncing
        case .didFetchChanges, .didSendChanges:
            if status == .syncing || status == .joining,
               ledger.book.primed {
                status = .synced(Date())
            }
        case .willFetchRecordZoneChanges, .didFetchRecordZoneChanges:
            break
        @unknown default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard syncEngine === engine else { return nil }
        let scope = context.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges
            .filter { scope.contains($0) }
        guard !changes.isEmpty else { return nil }
        let now = Date()
        return await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: changes
        ) { id in
            await self.record(for: id, at: now, engine: syncEngine)
        }
    }
}

// MARK: - Системный лист приглашения

/// Делегат `UICloudSharingController`: заголовок приглашения и отклик на
/// перемены — участники в группе «Семья» пересчитываются.
@MainActor
private final class Sharer: NSObject, UICloudSharingControllerDelegate {
    let title: String
    let done: () -> Void

    init(title: String, done: @escaping () -> Void) {
        self.title = title
        self.done = done
        super.init()
    }

    func itemTitle(for csc: UICloudSharingController) -> String? { title }

    func cloudSharingController(_ csc: UICloudSharingController,
                                failedToSaveShareWithError error: any Error) {
        done()
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        done()
    }

    func cloudSharingControllerDidStopSharing(
        _ csc: UICloudSharingController
    ) {
        done()
    }
}
