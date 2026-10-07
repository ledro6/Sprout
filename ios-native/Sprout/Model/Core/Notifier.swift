import Foundation
import UserNotifications

/// Доставка напоминаний. Уведомления местные: срок считается из того, что уже
/// есть в телефоне, сервер не нужен. Арифметика отдельно — в `Reminder`, её
/// можно прогнать без телефона.
enum Notifier {
    /// Уведомлений два — полив и уход; новое заменяет прежнее по имени.
    private static let id = "watering"
    private static let careID = "care"
    private static let cureID = "treatment"
    /// «Земля ещё влажная» после «Полил» — нажатие открывает растение.
    private static let wetID = "wet"
    /// Номер растения, которое открыть по нажатию.
    static let open = "open"

    /// Кнопка «Полил» прямо в уведомлении — без захода в приложение.
    static let category = "watering"
    static let pour = "pour"

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
        centre.setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [water],
                                   intentIdentifiers: [], options: []),
        ])
    }

    /// Зовётся из настроек, когда включают переключатель, а не при запуске:
    /// отказ, полученный заранее, уже не переспросить.
    static func ask() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        do {
            return try await centre.requestAuthorization(
                options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Разрешение могут отозвать в настройках телефона, и приложению об этом
    /// не скажут — поэтому спрашиваем каждый раз.
    static func allowed() async -> Bool {
        let status = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    /// Зовётся, когда приложение уходит с экрана: пока на сад смотрят,
    /// напоминание было бы шумом.
    static func schedule(in rooms: [Room]) async {
        clear()
        guard await allowed() else { return }
        if let due = Reminder.next(in: rooms) {
            let note = UNMutableNotificationContent()
            note.title = Reminder.title
            note.body = Reminder.text(for: due)
            note.sound = .default
            note.categoryIdentifier = category
            note.userInfo = ["plants": due.ids]
            await post(note, id: id, after: due.after)
        }
        if let chore = Reminder.chore(in: rooms) {
            let note = UNMutableNotificationContent()
            note.title = Reminder.title(for: chore)
            note.body = Reminder.text(for: chore)
            note.sound = .default
            await post(note, id: careID, after: chore.after)
        }
        if let remedy = Reminder.remedy(in: rooms) {
            let note = UNMutableNotificationContent()
            note.title = Reminder.title(for: remedy)
            note.body = Reminder.text(for: remedy)
            note.sound = .default
            await post(note, id: cureID, after: remedy.after)
        }
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

    /// Зовётся при возвращении на экран: срок к этому времени всё равно
    /// устарел.
    static func clear() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id, careID,
                                                                  cureID])
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
        guard response.actionIdentifier == Notifier.pour,
              let ids = info["plants"] as? [String]
        else { return }
        let wet = await MainActor.run { () -> [Plant] in
            let garden = Garden.shared
            // Приложение могло стоять в фоне — сперва чужие правки (виджет),
            // потом прошедшее время.
            garden.reload()
            garden.advance()
            // Влажную землю «Полил» не поливает: подтвердить в уведомлении
            // нечем — растение откроется по следующему уведомлению.
            return ids.compactMap { id in
                garden.water(id) == nil ? garden.plant(id: id) : nil
            }
        }
        if let first = wet.first { await Notifier.wet(first) }
    }

    /// Пока приложение на экране, напоминания сняты; пришедшее всё же —
    /// показываем баннером.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
