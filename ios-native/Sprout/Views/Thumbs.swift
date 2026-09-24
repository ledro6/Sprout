import UIKit
import WidgetKit

/// Картинки растений для виджета — в общую папку: снимки хозяина лежат в
/// Documents приложения, и виджет их не прочтёт. Ужаты до клетки виджета:
/// у него своя, маленькая память. Пишутся только недостающие; ушедшие
/// растения уносят свои.
enum Thumbs {
    static let side: CGFloat = 200

    static func export(_ rooms: [Room]) async {
        guard let folder = Store.thumbs else { return }
        let files = FileManager.default
        try? files.createDirectory(at: folder, withIntermediateDirectories: true)
        var keep: Set<String> = []
        for plant in rooms.flatMap(\.plants) {
            guard let file = Store.thumb(for: plant) else { continue }
            keep.insert(file.lastPathComponent)
            guard !files.fileExists(atPath: file.path) else { continue }
            let picture = await MainActor.run {
                plant.shot.flatMap { Snapshot.image($0) }
                    ?? UIImage(named: plant.photo)
            }
            guard let picture,
                  let data = shrink(picture).jpegData(compressionQuality: 0.82)
            else { continue }
            try? data.write(to: file, options: .atomic)
        }
        for name in (try? files.contentsOfDirectory(atPath: folder.path)) ?? []
            where !keep.contains(name) {
            try? files.removeItem(at: folder.appendingPathComponent(name))
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Квадрат из середины: в виджете картинка — кружок или скруглённый
    /// квадрат.
    private static func shrink(_ image: UIImage) -> UIImage {
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let scale = max(side / image.size.width, side / image.size.height)
            let width = image.size.width * scale
            let height = image.size.height * scale
            image.draw(in: CGRect(x: (side - width) / 2, y: (side - height) / 2,
                                  width: width, height: height))
        }
    }
}

/// Виджету пора перерисоваться. Не на каждую запись: сад пишется на каждом
/// действии, а перерисовка у виджета не бесплатная.
@MainActor
enum Widgets {
    private static var pending = false

    static func nudge() {
        guard !pending else { return }
        pending = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            pending = false
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
