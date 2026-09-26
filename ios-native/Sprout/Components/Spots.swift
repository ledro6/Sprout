import SwiftUI

/// Замеры кружков и клеток. Не состоянием: меняются каждый кадр прокрутки, а
/// нужны только в миг нажатия — откуда пустить волну.
final class Spots {
    private var rects: [Int: CGRect] = [:]

    func put(_ rect: CGRect, at key: Int) { rects[key] = rect }

    func rect(_ key: Int) -> CGRect { rects[key] ?? .zero }
}

