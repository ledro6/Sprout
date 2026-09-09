import Foundation
import UserNotifications

/// Доставка напоминаний: разрешение и одно отложенное уведомление.
///
/// Уведомления местные, а не с сервера. Приложение никуда не ходит и
/// ходить не должно: срок полива считается из влажности и скорости
/// сушки, то есть из того, что у телефона уже есть. Ни учётной записи,
/// ни ключей, ни чужих машин между хозяином и его растением.
///
/// Отдельно от `Reminder` затем, что там одна арифметика и её можно
/// прогнать где угодно, а `UserNotifications` есть только на телефоне.
enum Notifier {
    /// Уведомление в очереди всегда одно, и опознаётся оно по этому
    /// имени: поставить новое — значит заменить прежнее, а не добавить
    /// второе.
    private static let id = "watering"

    /// Спросить разрешение. Зовётся из настроек, когда переключатель
    /// включают, — не при запуске: отказ, полученный до того, как человек
    /// чего-то захотел, переспросить уже нельзя.
    static func ask() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        do {
            return try await centre.requestAuthorization(
                options: [.alert, .sound])
        } catch {
            // Отказала система, а не хозяин. Считаем, что разрешения нет:
            // переключатель вернётся в исходное, и напоминаний не будет.
            return false
        }
    }

    /// Разрешены ли уведомления сейчас. Спрашивается перед тем, как
    /// ставить: разрешение отзывают в настройках телефона, и приложение
    /// об этом никто не извещает.
    static func allowed() async -> Bool {
        let status = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    /// Поставить ближайшее напоминание вместо прежнего.
    ///
    /// Зовётся, когда приложение уходит с экрана. Пока на сад смотрят,
    /// напоминать не о чем: подсыхающие проценты видны и так, а
    /// уведомление поверх открытого приложения — это шум.
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

    /// Снять отложенное напоминание.
    ///
    /// Зовётся, когда приложение возвращается на экран: раз хозяин
    /// смотрит на сад, будить его нечем, а срок к этому времени всё равно
    /// устарел — сад успел подсохнуть, пока приложение было закрыто.
    static func clear() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }
}
