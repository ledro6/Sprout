import Foundation

/// Откуда по узору расходится переход — черёд каждой фигурки, 0…1. Что с
/// фигуркой делать, когда черёд настал, решает сам переход.
enum Front: Equatable, Sendable {
    /// Общая мерка на все переходы: при своей у каждого волна из середины и
    /// из угла шли бы с разной скоростью. Больше диагонали экрана.
    static let reach: Double = 900

    /// Из точки наружу — туда, куда нажал палец.
    case point(CGPoint)

    /// В точку снаружи — волна, пущенная вспять. Мерка своя, до дальнего угла
    /// холста: с общей первые полсекунды ничего бы не двигалось. «С краёв
    /// внутрь» не годится — фронт шёл бы стягивающейся рамкой.
    case collapse(CGPoint)

    /// Полосой; угол — куда фронт идёт.
    case sweep(Double)

    func turn(at middle: CGPoint, over size: CGSize) -> Double {
        let width = max(Double(size.width), 1)
        let height = max(Double(size.height), 1)
        let x = Double(middle.x), y = Double(middle.y)

        switch self {
        case let .point(from):
            return Self.away(from, x, y)

        case let .collapse(into):
            let dx = Double(into.x), dy = Double(into.y)
            let corner = max(hypot(dx, dy), hypot(width - dx, dy),
                             hypot(dx, height - dy),
                             hypot(width - dx, height - dy))
            let far = hypot(x - dx, y - dy)
            return 1 - min(far / max(corner, 1), 1)

        case let .sweep(angle):
            let dx = cos(angle), dy = sin(angle)
            // У косого направления размах шире — растягиваем проекцию на весь
            // ход.
            let reach = (abs(dx) + abs(dy)) / 2
            let along = (x / width - 0.5) * dx + (y / height - 0.5) * dy
            return min(max(along / (2 * reach) + 0.5, 0), 1)
        }
    }

    private static func away(_ from: CGPoint, _ x: Double,
                             _ y: Double) -> Double {
        let far = hypot(x - Double(from.x), y - Double(from.y))
        return min(far / Self.reach, 1)
    }
}
