import Foundation

/// Снимки растений на диске: где они лежат и как называются.
///
/// В Documents, рядом с самим садом, а не в Caches: снимок — это лицо
/// растения, и вычищенный ради места он оставил бы карточку без картинки.
/// Оттуда же он попадает в резервную копию телефона.
///
/// В файле сада лежит только имя снимка, а не он сам. Сад пишется на диск
/// на каждое действие хозяина, и таскать в нём мегабайты картинок значило
/// бы переписывать их все ради одного полива.
///
/// Здесь одни файлы и никаких картинок: сад зовёт `drop`, когда растение
/// удаляют, а сад должен собираться и там, где UIKit нет вовсе, — на нём
/// держится весь прогон модели. Всё, что про `UIImage`, живёт в
/// `Snapshot`.
enum Shots {
    /// Положить готовый снимок и вернуть его имя.
    static func keep(_ data: Data) -> String? {
        guard let folder else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
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

    /// Папка со снимками. Заводится при первом обращении.
    private static let folder: URL? = {
        guard let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let shots = documents.appendingPathComponent("Shots",
                                                     isDirectory: true)
        try? FileManager.default.createDirectory(
            at: shots, withIntermediateDirectories: true)
        return shots
    }()
}
