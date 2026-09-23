import Foundation

/// Квадратный кадр, вырезанный из снимка, — в точках снимка, а не экрана.
/// Только квадрат: см. `Trim`.
struct Crop: Sendable, Equatable {
    var x: Double
    var y: Double

    var side: Double

    /// Дальше снимок рассыпается на точки.
    static let deepest: Double = 4

    /// Кадр, видимый в окне: снимок вписан «враспор», увеличен в `scale` раз
    /// и сдвинут на `offset`. Сдвиг удерживается в границах — пустого угла на
    /// карточке быть не должно.
    static func of(image: CGSize, window: Double, scale: Double,
                   offset: CGSize) -> Crop {
        let width = max(Double(image.width), 1)
        let height = max(Double(image.height), 1)
        let side = max(window, 1)
        // Увеличение, при котором снимок закрывает окно, — по стороне,
        // которой не хватает больше.
        let cover = max(side / width, side / height)
        let zoom = cover * min(max(scale, 1), deepest)

        let held = hold(offset, image: image, window: window, scale: scale)
        let shown = CGSize(width: width * zoom, height: height * zoom)
        let left = (Double(shown.width) - side) / 2 - Double(held.width)
        let top = (Double(shown.height) - side) / 2 - Double(held.height)
        return Crop(x: left / zoom, y: top / zoom, side: side / zoom)
    }

    static func hold(_ offset: CGSize, image: CGSize, window: Double,
                     scale: Double) -> CGSize {
        let room = slack(image: image, window: window, scale: scale)
        return CGSize(
            width: min(max(Double(offset.width), -room.width), room.width),
            height: min(max(Double(offset.height), -room.height), room.height))
    }

    /// Сколько снимок больше окна с каждой стороны; ноль — двигать некуда.
    static func slack(image: CGSize, window: Double,
                      scale: Double) -> (width: Double, height: Double) {
        let width = max(Double(image.width), 1)
        let height = max(Double(image.height), 1)
        let side = max(window, 1)
        let zoom = max(side / width, side / height)
            * min(max(scale, 1), deepest)
        return (max(0, (width * zoom - side) / 2),
                max(0, (height * zoom - side) / 2))
    }

    func inside(_ image: CGSize) -> Bool {
        let slip = 1e-6
        return x >= -slip && y >= -slip
            && x + side <= Double(image.width) + slip
            && y + side <= Double(image.height) + slip
    }
}
