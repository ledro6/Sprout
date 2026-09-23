import Foundation

/// Фигурки плавают в вязкой среде, пока узор едет за наклоном.
///
/// Общий сдвиг делает `Tilt`, одним куском — а кусок читается наклеенной
/// плёнкой. Здесь фигурки разложены по слоям, и каждый слой догоняет наклон
/// со своей вязкостью: лёгкий обгоняет, тяжёлый отстаёт и доплывает, когда
/// телефон уже замер. Слой достаётся фигурке жребием, который перебрасывается
/// в покое.
enum Sway {
    /// Доля пути к цели за кадр. Середина — вязкость самого узора
    /// (`Tilt.ease`), поэтому разъезд идёт в обе стороны. Тяжёлый слой
    /// успокаивается за 1/0.045 ≈ 22 кадра — это и есть доплывание.
    static let eases: [Double] = [0.24, 0.17, 0.12, 0.075, 0.045]

    /// Упор: между соседями 45 pt, и без него резкий взмах развалил бы узор.
    static let limit: CGFloat = 7

    /// Жребий перебрасывается только в покое: смена вязкости на ходу дёрнула
    /// бы фигурку.
    static let shuffleSeconds = 0.9

    /// Жребий — от места в сетке и номера захода: внутри захода неизменен,
    /// иначе фигурка дрожала бы.
    static func layer(column: Int, row: Int, slot: Int, era: Int) -> Int {
        let part = (noise(column, row, slot, axis: era &* 2 &+ 7) + 1) / 2
        return min(max(Int(part * CGFloat(eases.count)), 0), eases.count - 1)
    }

    /// Цель у всех слоёв одна; разъезд — из разной скорости.
    static func settle(_ places: [CGSize], toward target: CGSize) -> [CGSize] {
        var next = places
        for i in next.indices where i < eases.count {
            let ease = CGFloat(eases[i])
            next[i] = CGSize(
                width: next[i].width + (target.width - next[i].width) * ease,
                height: next[i].height + (target.height - next[i].height) * ease)
        }
        return next
    }

    static func lag(_ places: [CGSize], behind common: CGSize) -> [CGSize] {
        places.map { place in
            CGSize(width: hold(place.width - common.width),
                   height: hold(place.height - common.height))
        }
    }

    static func rest(at place: CGSize) -> [CGSize] {
        Array(repeating: place, count: eases.count)
    }

    private static func hold(_ value: CGFloat) -> CGFloat {
        min(max(value, -limit), limit)
    }

    /// Детерминированный шум −1…1: жребий у фигурки один и тот же во всех
    /// кадрах захода.
    static func noise(_ column: Int, _ row: Int, _ slot: Int,
                      axis: Int) -> CGFloat {
        var mix = column &* 73_856_093
        mix ^= row &* 19_349_663
        mix ^= slot &* 83_492_791
        mix ^= axis &* 2_654_435_761
        mix ^= mix >> 13
        mix = mix &* 1_274_126_177
        mix ^= mix >> 16
        return CGFloat(mix & 0xFFFF) / CGFloat(0xFFFF) * 2 - 1
    }
}
