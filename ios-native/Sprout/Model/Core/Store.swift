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

    /// Картинка растения для виджета. Имя — от растения и его обложки: новый
    /// снимок или портрет — новый файл, и виджет не покажет старый.
    static func thumb(for plant: Plant) -> URL? {
        let key = Seeded.hash(plant.id + "|" + (plant.cover ?? plant.photo))
        return thumbs?.appendingPathComponent(String(key, radix: 16) + ".jpg")
    }

    /// Копия прежнего хорошего файла: перед каждой записью. Из неё сад
    /// восстанавливают, если основной файл повредился.
    static let copyName = "garden-backup.json"

    static var copy: URL? {
        garden?.deletingLastPathComponent().appendingPathComponent(copyName)
    }

    /// Что взять из файлов сада при запуске.
    enum Pick {
        /// Основной файл читается.
        case main(GardenState)
        /// Основной битый, копия читается — сад берём из неё.
        case copy(GardenState)
        /// Основного файла нет: сад начинается заново, как и раньше.
        case absent
        /// Оба не читаются: сад не заменяем молча, спрашиваем хозяина.
        case broken
    }

    static func decode(_ data: Data) -> GardenState? {
        try? JSONDecoder().decode(GardenState.self, from: data)
    }

    /// Чистое решение, что брать. Файлы передаются данными — тесты берут
    /// свои.
    static func pick(main: Data?, copy: Data?) -> Pick {
        guard let main else { return .absent }
        if let state = decode(main) { return .main(state) }
        if let copy, let state = decode(copy) { return .copy(state) }
        return .broken
    }

    /// Читает сад при запуске. Битый основной файл не стирается: он уходит в
    /// `garden-broken-<дата>.json`, а при читаемой копии её содержимое
    /// встаёт на его место.
    static func load() -> Pick {
        guard let file = garden else { return .absent }
        let main = try? Data(contentsOf: file)
        let kept = copy.flatMap { try? Data(contentsOf: $0) }
        let picked = pick(main: main, copy: kept)
        switch picked {
        case .main, .absent:
            break
        case .copy:
            // Не убрали битый — его не затираем копией.
            if quarantine(file) != nil {
                try? kept?.write(to: file, options: .atomic)
            }
        case .broken:
            quarantine(file)
        }
        return picked
    }

    /// Прежний хороший файл — в копию, перед тем как писать новый. Битый
    /// копию не затирает.
    static func keep(_ file: URL) {
        guard let copy, let data = try? Data(contentsOf: file),
              decode(data) != nil else { return }
        try? data.write(to: copy, options: .atomic)
    }

    /// Файл убирается с дороги, но не удаляется: имя с датой, и если такое
    /// уже есть — с номером.
    @discardableResult
    static func quarantine(_ file: URL) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = formatter.string(from: Date())
        let folder = file.deletingLastPathComponent()
        let files = FileManager.default
        var target = folder.appendingPathComponent(
            "garden-broken-\(stamp).json")
        var number = 2
        while files.fileExists(atPath: target.path) {
            target = folder.appendingPathComponent(
                "garden-broken-\(stamp)-\(number).json")
            number += 1
        }
        do {
            try files.moveItem(at: file, to: target)
            return target
        } catch {
            return nil
        }
    }

    /// Битый файл — тоже «нет файла» для тех, кто читает без решения: виджет
    /// и перечитывание не должны заменять сад. Решает `load`.
    static func read() -> GardenState? {
        guard let file = garden, let data = try? Data(contentsOf: file)
        else { return nil }
        return decode(data)
    }
}
