import Foundation
import UserNotifications

/// «Удалить все данные», часть на телефоне: сад, журнал, снимки, модели,
/// настройки, друзья, награды, место дачи — всё, что Sprout записал.
/// Облачную часть делает `Kinship.wipe`, и раньше: не вышло там — здесь не
/// трогаем ничего. События в календаре — календаря человека, их не трогаем.
@MainActor
enum Wipe {
    static func local() {
        // Сад в памяти — пустой и без имени: если приложение ещё что-то
        // сохранит до закрытия, это будет пустой сад, а не прежний.
        let garden = Garden.shared
        garden.owner = ""
        _ = garden.erase(guest: false)

        let files = FileManager.default
        let folders = [
            files.urls(for: .documentDirectory, in: .userDomainMask).first,
            files.urls(for: .applicationSupportDirectory,
                       in: .userDomainMask).first,
            files.urls(for: .cachesDirectory, in: .userDomainMask).first,
            Store.shared,
        ]
        for folder in folders.compactMap({ $0 }) {
            let items = (try? files.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil)) ?? []
            for item in items {
                // Настройки группы система держит здесь же — их стирает
                // `removePersistentDomain` ниже.
                if item.lastPathComponent == "Library" { continue }
                try? files.removeItem(at: item)
            }
        }

        if let bundle = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundle)
        }
        UserDefaults(suiteName: Store.group)?
            .removePersistentDomain(forName: Store.group)

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
