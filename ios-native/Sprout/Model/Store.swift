import Foundation

/// Где лежит сад. В общей папке приложения и виджета (App Group), чтобы
/// виджет видел сад и мог полить; без неё — в Documents, как раньше. Сад
/// прежних сборок при первом запуске копируется в общую папку, а старый
/// файл остаётся на месте — запасной копией.
enum Store {
    static let group = "group.com.ledro6.sprout"

    static let name = "garden.json"

    /// Общая папка. Пусто — приложение подписано без App Group или идёт
    /// прогон без телефона.
    static var shared: URL? {
        #if canImport(Darwin)
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: group)
        #else
        nil
        #endif
    }

    /// Documents, а не Caches: данные хозяина нельзя вычищать ради места, и
    /// так файл попадает в резервную копию.
    static var documents: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first
    }

    /// Своя папка для прогона без телефона: на Linux Documents не идёт за
    /// подменённой домашней папкой.
    nonisolated(unsafe) static var testing: URL?

    static var garden: URL? {
        if let testing { return testing.appendingPathComponent(name) }
        guard let shared else { return documents?.appendingPathComponent(name) }
        let target = shared.appendingPathComponent(name)
        let files = FileManager.default
        if !files.fileExists(atPath: target.path),
           let old = documents?.appendingPathComponent(name),
           files.fileExists(atPath: old.path) {
            try? files.copyItem(at: old, to: target)
        }
        return target
    }

    /// Картинки растений для виджета: свои снимки он не прочтёт — они в
    /// Documents приложения.
    static var thumbs: URL? {
        shared?.appendingPathComponent("thumbs", isDirectory: true)
    }

    /// Картинка растения для виджета. Имя — от растения и его снимка: новый
    /// снимок — новый файл, и виджет не покажет старый.
    static func thumb(for plant: Plant) -> URL? {
        let key = Seeded.hash(plant.id + "|" + (plant.shot ?? plant.photo))
        return thumbs?.appendingPathComponent(String(key, radix: 16) + ".jpg")
    }

    /// Битый файл — тоже «нет файла»: лучше макетный сад, чем не
    /// запуститься.
    static func read() -> GardenState? {
        guard let file = garden, let data = try? Data(contentsOf: file)
        else { return nil }
        return try? JSONDecoder().decode(GardenState.self, from: data)
    }
}
