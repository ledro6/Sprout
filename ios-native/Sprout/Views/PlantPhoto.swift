import SwiftUI
import UIKit

/// Картинка растения: снимок хозяина, а если его нет — рисунок из макета.
///
/// Один тип на оба места, где растение показывают, — витрину и его
/// собственный экран. Порознь они разошлись бы: снимок надо кадрировать и
/// скруглять, рисунок — вписывать целиком, и повторять оба правила дважды
/// значит рано или поздно поправить только одно из них.
struct PlantPhoto: View {
    let plant: Plant

    /// Скругление кадра. У карточки оно меньше, чем у плашки на экране
    /// растения, — как и сама карточка.
    var radius: CGFloat = 16

    var body: some View {
        if let shot = plant.shot, let image = Snapshot.image(shot) {
            // Снимок кадрируется по квадрату: фотографируют и вдоль, и
            // поперёк, и вписанный целиком он оставлял бы на карточке
            // пустые поля сверху и снизу.
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: radius,
                                            style: .continuous))
        } else {
            // Рисунок вписывается целиком: он нарисован с полями и на
            // прозрачном фоне, кадрировать в нём нечего.
            Image(plant.photo)
                .resizable()
                .scaledToFit()
        }
    }
}

/// Снимок как картинка: ужать перед тем, как класть на диск, и достать
/// обратно, не ходя за ним на диск дважды.
///
/// Отдельно от `Shots`, потому что `UIImage` есть только на платформах
/// Apple, а `Shots` зовёт сад — и сад обязан собираться и без UIKit.
enum Snapshot {
    /// Наибольшая сторона снимка после ужатия.
    ///
    /// Карточка растения — примерно 160 пунктов, на трёхкратном экране это
    /// 480 точек; тысяча с запасом хватает и на экран растения во всю
    /// ширину. Снимок с камеры вчетверо больше по стороне и в двадцать раз
    /// тяжелее, и хранить его целиком незачем.
    static let side: CGFloat = 1024

    static func keep(_ image: UIImage) -> String? {
        guard let data = shrink(image).jpegData(compressionQuality: 0.85)
        else { return nil }
        return Shots.keep(data)
    }

    /// Взять снимок. С диска он читается один раз.
    ///
    /// Кэш здесь обязателен, а не в помощь. Спрашивают снимок из тела
    /// карточки, а сад сушится раз в секунду — значит, каждая видимая
    /// карточка ходила бы за своим файлом ежесекундно. `NSCache` заодно
    /// сам отдаёт память, когда её мало: картинки — первое, что не жалко
    /// перечитать.
    ///
    /// Удалённое растение оставляет за собой запись в кэше: сад про кэш не
    /// знает, а звать его оттуда нечем. Вреда в этом нет — имя снимка
    /// случайное и второй раз не выпадет, спрашивать его больше некому, а
    /// память заберёт система, как только она понадобится.
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

    /// Ужать до `side` по большей стороне, сохранив пропорции. Снимок
    /// меньше этого не трогаем: растягивать его незачем.
    private static func shrink(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > side else { return image }
        let scale = side / longest
        let size = CGSize(width: (image.size.width * scale).rounded(),
                          height: (image.size.height * scale).rounded())
        // Через `UIGraphicsImageRenderer`: он сам разбирается с поворотом
        // снимка из камеры — у снятых боком в метаданных стоит ориентация,
        // и нарисованные напрямую они выходили бы лежащими.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
    }
}
