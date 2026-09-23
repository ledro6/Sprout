import Foundation
import UserNotifications

/// Доставка напоминаний. Уведомления местные: срок считается из того, что уже
/// есть в телефоне, сервер не нужен. Арифметика отдельно — в `Reminder`, её
/// можно прогнать без телефона.
enum Notifier {
    /// Уведомление всегда одно: новое заменяет прежнее по этому имени.
    private static let id = "watering"

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
        guard await allowed(),
              let due = Reminder.next(in: rooms, threshold: threshold)
        else { return }

        let note = UNMutableNotificationContent()
        note.title = Reminder.title
        note.body = Reminder.text(for: due)
        note.sound = .default

        let when = UNTimeIntervalNotificationTrigger(
            timeInterval: due.after, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: note,
                                            trigger: when)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Зовётся при возвращении на экран: срок к этому времени всё равно
    /// устарел.
    static func clear() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
