import CoreNFC
import SwiftUI
import UIKit

// NFC-метки на горшках: «Привязать метку» в меню растения пишет на наклейку
// ссылку на растение, «Приложить к метке» в меню «ещё» на главной читает её
// — растение открывается, полив отмечается сразу или после вопроса (см.
// `PotTag`, настройка «Полив по метке»).
//
// Сама, без приложения, метку iPhone не прочтёт: фоновое чтение меток
// открывает приложения только универсальными ссылками, то есть своим
// сайтом и Associated Domains. Своя схема `sprout://` работает только из
// приложения — так и задумано.

/// Сеансы NFC. Чтение меток — возможность Apple Developer, как iCloud и
/// WeatherKit: без неё в подписи сеанс не начнётся, а без пояснения в
/// Info.plist приложение упадёт на первом же сеансе. Поэтому всё здесь — за
/// `enabled`, и пока его нет, пунктов меню нет вовсе.
@MainActor
@Observable
final class Tags {
    static let shared = Tags()

    /// Включено в сборке: ключ `SproutNFCTags` в Info.plist ставит хозяин
    /// вместе с возможностью, см. README «NFC-метки на горшках». И пояснение
    /// для системы на месте — без него сеанс роняет приложение.
    nonisolated static let enabled =
        ((Bundle.main.object(forInfoDictionaryKey: "SproutNFCTags") as? Bool)
            ?? false)
        && Bundle.main.object(forInfoDictionaryKey: "NFCReaderUsageDescription")
            != nil

    /// Включено и телефон умеет читать метки: на iPad NFC нет.
    static var ready: Bool { enabled && NFCNDEFReaderSession.readingAvailable }

    /// Приложили метку, а полив — с вопросом: о каком растении спросить.
    var asking: Plant.ID?

    /// Что сказать после сеанса: растения нет, полив уже отмечен.
    var notice: String?

    @ObservationIgnored private var session: NFCNDEFReaderSession?
    @ObservationIgnored private var scout: Scout?

    private init() {}

    /// Записать на метку ссылку на растение. Итог — в листе системы:
    /// «Метка записана» или что помешало.
    func write(_ id: Plant.ID) {
        guard Self.ready, let url = PotTag.link(id),
              let plant = Garden.shared.plant(id: id) else { return }
        begin(Scout(job: .write(url)),
              prompt: Lang.format("Поднесите iPhone к метке для «%@».",
                                  plant.name))
    }

    /// Прочитать метку и сделать, что она просит.
    func read() {
        guard Self.ready else { return }
        begin(Scout(job: .read),
              prompt: Lang.text("Поднесите iPhone к метке на горшке."))
    }

    /// Прежний сеанс, если он ещё висит, закрываем: два листа NFC сразу
    /// система не покажет.
    private func begin(_ scout: Scout, prompt: String) {
        session?.invalidate()
        let session = NFCNDEFReaderSession(delegate: scout, queue: nil,
                                           invalidateAfterFirstRead: false)
        session.alertMessage = prompt
        self.scout = scout
        self.session = session
        session.begin()
    }

    // MARK: - Ответы сеанса — на главной очереди

    fileprivate func ended(_ scout: Scout) {
        // Поздний ответ старого сеанса не должен закрыть новый.
        guard scout === self.scout else { return }
        session = nil
        self.scout = nil
    }

    fileprivate func wrote() { Feel.done() }

    /// Прочитали ссылку — растение открывается, дальше по настройке.
    fileprivate func landed(_ url: URL) {
        let garden = Garden.shared
        let reaction = PotTag.react(to: url, rooms: garden.rooms,
                                    log: garden.log,
                                    mode: Settings.shared.tagPour, now: Date())
        switch reaction {
        case .foreign:
            notice = Lang.text("На метке нет растения Sprout.")
            Feel.wrong()
        case .gone:
            notice = Lang.text("Этого растения в саду больше нет.")
            Feel.wrong()
        case .water(let id):
            Summon.shared.plant = id
            water(id)
        case .ask(let id):
            Summon.shared.plant = id
            // Земля влажная — сразу вопрос о ней, без «Полить?» перед ним:
            // два листа подряд.
            if Garden.shared.wetCheck(id) != nil {
                water(id)
            } else {
                asking = id
            }
        case .fresh(let id, let when):
            Summon.shared.plant = id
            notice = Lang.format("Полив уже отмечен в %@ — второй раз не записываю.",
                                 when.formatted(date: .omitted, time: .shortened))
        }
    }

    /// Как полив из Siri: с волной и отменой на плашке.
    /// Влажную землю — сперва вопрос, см. `Overflow`.
    func water(_ id: Plant.ID) {
        Overflow.shared.water(id, in: Garden.shared, source: .tag) {
            let spot = Cards.shared.rect(id)
            Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
            Feel.water()
        }
    }
}

/// Делегат сеанса. Не на главной очереди: система зовёт его на своей, а
/// ответы уходят в `Tags` задачами на главную.
private final class Scout: NSObject, NFCNDEFReaderSessionDelegate {
    enum Job {
        case write(URL)
        case read
    }

    let job: Job

    init(job: Job) {
        self.job = job
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    /// Закрыли лист, вышло время, сеанс закончился сам — всё сюда.
    func readerSession(_ session: NFCNDEFReaderSession,
                       didInvalidateWithError error: any Error) {
        Task { @MainActor in Tags.shared.ended(self) }
    }

    /// Обязателен протоколом, но при `didDetect tags` система его не зовёт.
    func readerSession(_ session: NFCNDEFReaderSession,
                       didDetectNDEFs messages: [NFCNDEFMessage]) {}

    func readerSession(_ session: NFCNDEFReaderSession,
                       didDetect tags: [any NFCNDEFTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = Lang.text("Рядом несколько меток — поднесите к одной.")
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(600)) {
                session.restartPolling()
            }
            return
        }
        session.connect(to: tag) { error in
            if error != nil {
                session.invalidate(errorMessage: Lang.text(
                    "Не получилось связаться с меткой. Попробуйте ещё раз."))
                return
            }
            switch self.job {
            case .write(let url): self.write(url, to: tag, in: session)
            case .read: self.read(tag, in: session)
            }
        }
    }

    private func write(_ url: URL, to tag: any NFCNDEFTag,
                       in session: NFCNDEFReaderSession) {
        tag.queryNDEFStatus { status, capacity, error in
            guard error == nil else {
                session.invalidate(errorMessage: Lang.text(
                    "Не получилось связаться с меткой. Попробуйте ещё раз."))
                return
            }
            switch status {
            case .readWrite:
                break
            case .readOnly:
                session.invalidate(errorMessage: Lang.text(
                    "Метка защищена от записи."))
                return
            default:
                session.invalidate(errorMessage: Lang.text(
                    "Эта метка не подходит: на неё не записать ссылку."))
                return
            }
            guard let record = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
            else {
                session.invalidate(errorMessage: Lang.text(
                    "Не получилось записать метку."))
                return
            }
            let message = NFCNDEFMessage(records: [record])
            guard message.length <= capacity else {
                session.invalidate(errorMessage: Lang.text(
                    "На метке не хватает места."))
                return
            }
            tag.writeNDEF(message) { error in
                guard error == nil else {
                    session.invalidate(errorMessage: Lang.text(
                        "Не получилось записать метку."))
                    return
                }
                session.alertMessage = Lang.text("Метка записана")
                session.invalidate()
                Task { @MainActor in Tags.shared.wrote() }
            }
        }
    }

    /// Пустая метка тоже отвечает ошибкой — для человека это «не наша».
    private func read(_ tag: any NFCNDEFTag, in session: NFCNDEFReaderSession) {
        tag.readNDEF { message, _ in
            let url = message?.records
                .compactMap { $0.wellKnownTypeURIPayload() }
                .first { PotTag.plant(in: $0) != nil }
            guard let url else {
                session.invalidate(errorMessage: Lang.text(
                    "На метке нет растения Sprout."))
                return
            }
            session.alertMessage = Lang.text("Готово")
            session.invalidate()
            Task { @MainActor in Tags.shared.landed(url) }
        }
    }
}

/// Вопрос «Полить?» и сообщения после метки — над всеми вкладками.
struct TagPrompt: ViewModifier {
    private let tags = Tags.shared

    func body(content: Content) -> some View {
        content
            .alert("Полить?",
                   isPresented: Binding(get: { tags.asking != nil },
                                        set: { if !$0 { tags.asking = nil } }),
                   presenting: tags.asking.flatMap { Garden.shared.plant(id: $0) }) { plant in
                Button("Полил") { tags.water(plant.id) }
                Button("Не сейчас", role: .cancel) {}
            } message: { plant in
                Text(Lang.format("Метка на горшке «%@». Отметить полив?", plant.name))
            }
            .alert("Метка на горшке",
                   isPresented: Binding(get: { tags.notice != nil },
                                        set: { if !$0 { tags.notice = nil } })) {
                Button("Готово", role: .cancel) {}
            } message: {
                Text(tags.notice ?? "")
            }
    }
}
