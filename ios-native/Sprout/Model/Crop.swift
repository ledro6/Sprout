import Foundation

/// Квадратный кадр, вырезанный из снимка.
///
/// Считается в точках самого снимка, а не в пикселях экрана: снимок с
/// камеры больше окна в несколько раз, и вырезать из него надо по его
/// собственным меркам.
///
/// Квадрат, и только квадрат. Карточки растений в сетке обязаны быть
/// одного размера — иначе сетка едет, и ряд с высокой карточкой
/// расталкивает соседние, — а один размер у них будет ровно тогда, когда
/// у всех снимков одно соотношение сторон. Выбирать его хозяину не дают
/// намеренно: это не украшение, а условие, на котором держится вёрстка.
struct Crop: Sendable, Equatable {
    /// Левый верхний угол кадра в точках снимка.
    var x: Double
    var y: Double

    /// Сторона квадрата, тоже в точках снимка.
    var side: Double

    /// Наибольшее увеличение. Дальше снимок рассыпается на точки, и
    /// подпускать к этому незачем.
    static let deepest: Double = 4

    /// Кадр, который сейчас виден в окне.
    ///
    /// Окно квадратное со стороной `window`. Снимок лежит в нём «враспор»
    /// — вписан так, чтобы закрыть окно целиком, — а сверх того увеличен
    /// в `scale` раз и сдвинут на `offset`.
    ///
    /// Сдвиг здесь же и удерживается в границах: за них снимок обнажил бы
    /// угол окна, а пустого угла на карточке быть не должно.
    static func of(image: CGSize, window: Double, scale: Double,
                   offset: CGSize) -> Crop {
        let width = max(Double(image.width), 1)
        let height = max(Double(image.height), 1)
        let side = max(window, 1)
        // Во сколько раз снимок увеличен, чтобы закрыть окно без увеличения
        // хозяина: по той стороне, которой не хватает больше.
        let cover = max(side / width, side / height)
        let zoom = cover * min(max(scale, 1), deepest)

        let held = hold(offset, image: image, window: window, scale: scale)
        let shown = CGSize(width: width * zoom, height: height * zoom)
        // Левый край окна относительно левого края снимка — в точках
        // экрана, потом в точках снимка.
        let left = (Double(shown.width) - side) / 2 - Double(held.width)
        let top = (Double(shown.height) - side) / 2 - Double(held.height)
        return Crop(x: left / zoom, y: top / zoom, side: side / zoom)
    }

    /// Сдвиг, подрезанный до границ, за которыми окно перестанет быть
    /// закрытым снимком.
    static func hold(_ offset: CGSize, image: CGSize, window: Double,
                     scale: Double) -> CGSize {
        let room = slack(image: image, window: window, scale: scale)
        return CGSize(
            width: min(max(Double(offset.width), -room.width), room.width),
            height: min(max(Double(offset.height), -room.height), room.height))
    }

    /// Насколько снимок больше окна — по половине с каждой стороны.
    /// Ноль значит, что двигать в эту сторону некуда.
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

    /// Кадр целиком внутри снимка? Должен быть всегда — на этом держится
    /// обещание, что пустого угла на карточке не бывает.
    func inside(_ image: CGSize) -> Bool {
        let slip = 1e-6
        return x >= -slip && y >= -slip
            && x + side <= Double(image.width) + slip
            && y + side <= Double(image.height) + slip
    }
}
