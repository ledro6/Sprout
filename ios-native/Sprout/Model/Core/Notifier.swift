import Foundation
import UserNotifications

/// Доставка напоминаний. Уведомления местные: срок считается из того, что уже
/// есть в телефоне, сервер не нужен. Арифметика отдельно — в `Reminder`, её
/// можно прогнать без телефона.
enum Notifier {
    /// Уведомлений два — полив и уход; новое заменяет прежнее по имени.
    private static let id = "watering"
    private static let careID = "care"

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
    static func schedule(in rooms: [Room], threshold: Double) async {
        clear()
        guard await allowed() else { return }
        if let due = Reminder.next(in: rooms, threshold: threshold) {
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
            .removePendingNotificationRequests(withIdentifiers: [id, careID])
    }
}

/// Нажатия по уведомлениям. «Полил» приходит и к закрытому приложению —
/// система поднимает его в фоне, и полив ложится в тот же `Garden.shared`,
/// что видят экраны и Siri.
private final class Postman: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse)
        async {
        guard response.actionIdentifier == Notifier.pour,
              let ids = response.notification.request.content
                  .userInfo["plants"] as? [String]
        else { return }
        await MainActor.run {
            let garden = Garden.shared
            // Приложение могло стоять в фоне — сперва чужие правки (виджет),
            // потом прошедшее время.
            garden.reload()
            garden.advance()
            for id in ids { _ = garden.water(id) }
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
