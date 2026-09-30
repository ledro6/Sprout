import Foundation

/// Снимки растений на диске.
///
/// В Documents, а не в Caches: вычищенный ради места снимок оставил бы
/// карточку без картинки. В файле сада — только имя, иначе каждый полив
/// переписывал бы мегабайты. `UIImage` здесь нет — сад, который зовёт `drop`,
/// собирается и без UIKit; картинки живут в `Snapshot`.
enum Shots {
    static func keep(_ data: Data) -> String? {
        guard let folder else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent(name),
                           options: .atomic)
        } catch {
            return nil
        }
        return name
    }

    static func url(_ name: String) -> URL? {
        folder?.appendingPathComponent(name)
    }

    static func drop(_ name: String) {
        guard let file = url(name) else { return }
        try? FileManager.default.removeItem(at: file)
    }

    /// Папка заводится, только когда в неё кладут: чтение и удаление её не
    /// создают — прогон модели на Linux, где Documents — настоящая домашняя
    /// папка, не оставит её там, и сад в ней не запишется.
    private static let folder: URL? = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Shots", isDirectory: true)
}
