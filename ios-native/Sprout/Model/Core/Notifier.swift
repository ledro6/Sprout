import Foundation
import UserNotifications

/// Доставка напоминаний. Уведомления местные: срок считается из того, что уже
/// есть в телефоне, сервер не нужен. Арифметика отдельно — в `Plan` и `Reminder`, её
/// можно прогнать без телефона.
enum Notifier {
    /// Расписание (`Plan`) ставится под номерами `plan.0` … `plan.31`: новое
    /// заменяет прежнее целиком. Прежние имена снимаются, чтобы не остаться
    /// после обновления.
    private static let planned = (0 ..< 32).map { "plan.\($0)" }
    private static let legacy = ["watering", "care", "treatment"]
    /// «Земля ещё влажная» после «Полил» — нажатие открывает растение.
    private static let wetID = "wet"
    /// Номер растения, которое открыть по нажатию.
    static let open = "open"

    /// Кнопка «Полил» прямо в уведомлении — без захода в приложение. У дачи.
    static let category = "watering"
    static let pour = "pour"

    /// Утреннее: «Полил всех» и «Завтра».
    static let morning = "morning"
    static let pourAll = "pourAll"
    static let tomorrow = "tomorrow"

    /// Кто разбирает нажатия. Держим сами: центр уведомлений держит его
    /// слабо.
    private static let postman = Postman()

    /// При запуске, до первого уведомления: иначе кнопка не появится, а
    /// нажатие по ней не дойдёт.
    @MainActor
    static func register() {
        let centre = UNUserNotificationCenter.current()
        centre.delegate = postman
        let water = UNNotificationAction(identifier: pour,
                                         title: Lang.text("Полил"),
                                         options: [],
                                         icon: UNNotificationActionIcon(
                                             systemImageName: "drop.fill"))
        let all = UNNotificationAction(identifier: pourAll,
                                       title: Lang.text("Полил всех"),
                                       options: [],
                                       icon: UNNotificationActionIcon(
                                           systemImageName: "drop.fill"))
        let later = UNNotificationAction(identifier: tomorrow,
                                         title: Lang.text("Завтра"),
                                         options: [],
                                         icon: UNNotificationActionIcon(
                                             systemImageName: "moon.zzz"))
        centre.setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [water],
                                   intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: morning, actions: [all, later],
                                   intentIdentifiers: [], options: []),
        ])
    }

    /// Зовётся, когда напоминания включают или предлагают (настройки,
    /// знакомство, вопрос после первого растения), а не при запуске: отказ,
    /// полученный заранее, уже не переспросить. Разрешили — утреннее
    /// напоминание включается; `reminders: false` — для остальных (новости
    /// общего сада): им полив включать не нужно.
    static func ask(reminders: Bool = true) async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await centre.requestAuthorization(
                options: [.alert, .sound])
        } catch {
            granted = false
        }
        await MainActor.run {
            Journal.shared.note(.permissionResult,
                                granted ? "notifications:granted"
                                    : "notifications:denied")
        }
        if reminders {
            await MainActor.run {
                Settings.shared.reminderAsked = true
                if granted { Settings.shared.reminders = true }
            }
        }
        return granted
    }

    /// Спросить «Напоминать, когда пора полить?» после первого растения:
    /// флаг `Plan.askAfterFirstPlant` включён, напоминаний нет и вопрос ещё
    /// не задавали (в знакомстве, настройках или раньше).
    static var shouldOffer: Bool {
        Plan.askAfterFirstPlant && !Settings.shared.reminders
            && !Settings.shared.reminderAsked
    }

    /// Разрешение могут отозвать в настройках телефона, и приложению об этом
    /// не скажут — поэтому спрашиваем каждый раз.
    static func allowed() async -> Bool {
        let status = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    /// Зовётся, когда приложение уходит с экрана: пока на сад смотрят,
    /// напоминание было бы шумом. Что и когда — решает `Plan`; `notBefore` —
    /// «Завтра».
    static func schedule(in rooms: [Room], notBefore: Date? = nil) async {
        clear()
        guard await allowed() else { return }
        let rules = await MainActor.run { () -> Plan.Rules in
            let settings = Settings.shared
            var rules = Plan.Rules()
            rules.morning = settings.morning
            rules.quietFrom = settings.quietFrom
            rules.quietTo = settings.quietTo
            // Приезд на дачу — тоже пуш, и день на него оставлен.
            rules.reserve = Dachnik.shared.armed ? 1 : 0
            return rules
        }
        let slots = Plan.slots(in: rooms, now: Date(), rules: rules,
                               notBefore: notBefore)
        for (index, slot) in slots.prefix(planned.count).enumerated() {
            let note = UNMutableNotificationContent()
            note.title = slot.title
            note.body = slot.body
            note.sound = .default
            if slot.kind == .morning {
                note.categoryIdentifier = morning
                note.userInfo = ["plants": slot.ids]
            }
            await post(note, id: planned[index], at: slot.at)
        }
    }

    /// После «Полил всех» и «Завтра» — без открытия приложения: расписание
    /// считается заново по нынешнему саду.
    static func replan(notBefore: Date? = nil) async {
        let rooms = await MainActor.run { () -> [Room]? in
            guard Settings.shared.reminders else { return nil }
            return Dachnik.shared.reminded(Garden.shared.rooms)
        }
        guard let rooms else { return }
        await schedule(in: rooms, notBefore: notBefore)
    }

    /// «Полил» нажали, а земля у растения ещё влажная — полив не записан
    /// (защита от перелива). Говорим об этом сразу; нажатие откроет
    /// растение — посмотреть самому.
    static func wet(_ plant: Plant) async {
        let note = UNMutableNotificationContent()
        note.title = Lang.format("Земля ещё влажная (%@)", MoistureStatus.percent(
            plant.moisture, estimated: plant.estimated))
        note.body = Lang.format("«%@»: полив не записан. Лишний полив вреден корням — откройте растение и проверьте землю.",
                                plant.name)
        note.userInfo = [open: plant.id]
        await post(note, id: wetID, after: 1)
    }

    private static func post(_ note: UNMutableNotificationContent, id: String,
                             after: TimeInterval) async {
        let when = UNTimeIntervalNotificationTrigger(timeInterval: after,
                                                     repeats: false)
        let request = UNNotificationRequest(identifier: id, content: note,
                                            trigger: when)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// В заданный час и минуту, по часам телефона.
    private static func post(_ note: UNMutableNotificationContent, id: String,
                             at date: Date) async {
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        let when = UNCalendarNotificationTrigger(dateMatching: parts,
                                                 repeats: false)
        let request = UNNotificationRequest(identifier: id, content: note,
                                            trigger: when)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Зовётся при возвращении на экран: срок к этому времени всё равно
    /// устарел.
    static func clear() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: planned + legacy)
    }
}

/// Нажатия по уведомлениям. «Полил» приходит и к закрытому приложению —
/// система поднимает его в фоне, и полив ложится в тот же `Garden.shared`,
/// что видят экраны и Siri.
private final class Postman: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse)
        async {
        let info = response.notification.request.content.userInfo
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let id = info[Notifier.open] as? String {
            await MainActor.run { Summon.shared.plant = id }
            return
        }
        let action = response.actionIdentifier
        await MainActor.run {
            Journal.shared.note(.notificationAction,
                                action == Notifier.tomorrow ? "tomorrow"
                                    : action == Notifier.pourAll ? "pour_all"
                                    : action == Notifier.pour ? "pour"
                                    : "other")
        }
        switch response.actionIdentifier {
        case Notifier.tomorrow:
            // Отложить: расписание заново, но не раньше завтрашнего утра.
            let calendar = Calendar.current
            let next = calendar.date(byAdding: .day, value: 1,
                                     to: calendar.startOfDay(for: Date()))
            await Notifier.replan(notBefore: next)
        case Notifier.pour, Notifier.pourAll:
            guard let ids = info["plants"] as? [String] else { return }
            let wet = await MainActor.run { () -> Plant? in
                let garden = Garden.shared
                // Приложение могло стоять в фоне — сперва чужие правки
                // (виджет), потом прошедшее время.
                garden.reload()
                garden.advance()
                // Поливает только тех, кому пора пить (`waterNeeded`):
                // влажную землю «Полил» не трогает.
                guard garden.waterNeeded(ids).isEmpty else { return nil }
                return ids.first { garden.wetCheck($0) != nil }
                    .flatMap { garden.plant(id: $0) }
            }
            if let wet { await Notifier.wet(wet) }
            await Notifier.replan()
        default:
            return
        }
    }

    /// Пока приложение на экране, напоминания сняты; пришедшее всё же —
    /// показываем баннером.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
