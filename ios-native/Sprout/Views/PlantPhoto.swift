import SwiftUI
import UIKit

/// Картинка растения: снимок хозяина или рисунок из макета. Один тип на
/// карточку и экран растения, чтобы правила кадрирования не разошлись.
struct PlantPhoto: View {
    let plant: Plant

    var radius: CGFloat = 16

    var body: some View {
        if let shot = plant.shot, let image = Snapshot.image(shot) {
            // Снимок — наложением на пустой цвет: `scaledToFill` сообщает
            // размер больше предложенного и расталкивал бы сетку.
            Color.clear
                // Запасной размер для предпросмотра контекстного меню: там
                // размера не предлагают, и пустой цвет сжался бы в точку.
                .frame(idealWidth: Metrics.photoIdeal,
                       idealHeight: Metrics.photoIdeal)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: radius,
                                            style: .continuous))
        } else {
            Image(plant.photo)
                .resizable()
                .scaledToFit()
        }
    }
}

/// Снимок как `UIImage`: ужать перед диском и держать в кэше. Отдельно от
/// `Shots`, потому что сад собирается без UIKit.
enum Snapshot {
    /// Тысячи точек хватает и на экран растения во всю ширину; снимок с
    /// камеры в двадцать раз тяжелее.
    static let side: CGFloat = 1024

    /// Рисованием, а не `CGImage.cropping`: у снимка с камеры поворот в
    /// метаданных.
    static func cut(_ image: UIImage, to crop: Crop) -> UIImage {
        // Не больше нашего предела и не меньше 600: крошечный кусок на
        // карточке — мыло.
        let out = min(max(crop.side, 600), Double(side))
        let size = CGSize(width: out, height: out)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in
                let zoom = out / crop.side
                image.draw(in: CGRect(
                    x: -crop.x * zoom, y: -crop.y * zoom,
                    width: Double(image.size.width) * zoom,
                    height: Double(image.size.height) * zoom))
            }
    }

    static func keep(_ image: UIImage) -> String? {
        guard let data = shrink(image).jpegData(compressionQuality: 0.85)
        else { return nil }
        return Shots.keep(data)
    }

    /// Кэш обязателен: снимок спрашивают из тела карточки, а сад сушится раз
    /// в секунду. Запись удалённого растения в кэше безвредна — память
    /// заберёт система.
    static func image(_ name: String) -> UIImage? {
        let key = name as NSString
        if let kept = cache.object(forKey: key) { return kept }
        guard let file = Shots.url(name),
              let image = UIImage(contentsOfFile: file.path)
        else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    private static let cache = NSCache<NSString, UIImage>()

    private static func shrink(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > side else { return image }
        let scale = side / longest
        let size = CGSize(width: (image.size.width * scale).rounded(),
                          height: (image.size.height * scale).rounded())
        // `UIGraphicsImageRenderer` сам учитывает поворот из метаданных.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
    }
}
