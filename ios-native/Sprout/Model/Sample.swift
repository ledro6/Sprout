import Foundation

/// Разбор снимка для объёмной модели: годится ли он и какие на нём цвета.
/// Только арифметика над пикселями: сам снимок и маску растения даёт
/// `Eye.study`, а здесь всё проверяется без телефона.
enum Sample {
    enum Verdict: Equatable, Sendable {
        case fine
        /// Мыльный: смазан или не в фокусе.
        case blurry
        case dark
        case bright
        /// Растения на снимке не видно.
        case empty

        var line: String {
            switch self {
            case .fine: Lang.text("Модель построю по снимку.")
            case .blurry: Lang.text("Снимок мыльный — снимите почётче.")
            case .dark: Lang.text("Снимок тёмный — снимите при свете.")
            case .bright: Lang.text("Снимок пересвечен — снимите без прямого солнца.")
            case .empty: Lang.text("Растения на снимке не видно — снимите его целиком.")
            }
        }
    }

    struct Reading: Equatable, Sendable {
        var verdict: Verdict
        var traits: Traits? = nil
    }

    /// Резкость ниже этого — мыльный снимок. Порог мягкий: отсеять надо
    /// смазанное, а не просто не идеальное.
    static let sharpEnough: Float = 40

    /// Пиксели RGBA рядами сверху вниз; маска — байт на пиксель, растение
    /// ярче половины. Нет маски — растение ищется в середине кадра.
    static func read(rgba: [UInt8], mask: [UInt8]?, width: Int,
                     height: Int) -> Reading {
        guard width > 8, height > 8, rgba.count >= width * height * 4 else {
            return Reading(verdict: .empty)
        }
        let inside: [Bool]
        if let mask, mask.count >= width * height {
            inside = mask.map { $0 > 127 }
        } else {
            inside = centre(width, height)
        }
        var box = (left: width, right: -1, top: height, bottom: -1)
        var count = 0
        var light: Float = 0
        for y in 0 ..< height {
            for x in 0 ..< width where inside[y * width + x] {
                count += 1
                box.left = min(box.left, x)
                box.right = max(box.right, x)
                box.top = min(box.top, y)
                box.bottom = max(box.bottom, y)
                let at = (y * width + x) * 4
                light += (0.3 * Float(rgba[at]) + 0.59 * Float(rgba[at + 1])
                    + 0.11 * Float(rgba[at + 2])) / 255
            }
        }
        guard count > width * height / 50 else {
            return Reading(verdict: .empty)
        }
        let mean = light / Float(count)
        if mean < 0.08 { return Reading(verdict: .dark) }
        if mean > 0.93 { return Reading(verdict: .bright) }
        if sharpness(rgba, width: width, height: height, box: box)
            < sharpEnough {
            return Reading(verdict: .blurry)
        }

        var leaves: [[UInt8]] = [[], [], []]
        var pale: [[UInt8]] = [[], [], []]
        var petals: [Int: [[UInt8]]] = [:]
        var pot: [[UInt8]] = [[], [], []]
        let boxHeight = max(box.bottom - box.top, 1)
        for y in box.top ... box.bottom {
            // Нижняя треть — горшок; цветы ищутся только выше него.
            let low = Float(y - box.top) / Float(boxHeight) > 0.65
            for x in box.left ... box.right where inside[y * width + x] {
                let at = (y * width + x) * 4
                let (hue, saturation, value) = hsv(rgba[at], rgba[at + 1],
                                                    rgba[at + 2])
                let green = hue >= 55 && hue <= 175 && saturation >= 0.18
                    && value >= 0.12
                func keep(_ bucket: inout [[UInt8]]) {
                    bucket[0].append(rgba[at])
                    bucket[1].append(rgba[at + 1])
                    bucket[2].append(rgba[at + 2])
                }
                if green {
                    keep(&leaves)
                } else if low {
                    keep(&pot)
                } else if saturation < 0.2 && value > 0.72 {
                    keep(&pale)
                } else if saturation >= 0.35 && value >= 0.3 {
                    let bin = Int(hue / 30) % 12
                    var bucket = petals[bin] ?? [[], [], []]
                    keep(&bucket)
                    petals[bin] = bucket
                }
            }
        }
        guard leaves[0].count > count / 50 else {
            return Reading(verdict: .empty)
        }
        let leaf = median(leaves)
        let variegation = pale[0].count > leaves[0].count / 8
            ? median(pale) : nil
        let bloom = petals.max { $0.value[0].count < $1.value[0].count }
        let flower = (bloom?.value[0].count ?? 0) > count / 100
            ? bloom.map { median($0.value) } : nil
        let pottery = pot[0].count > count * 3 / 100 ? median(pot) : nil
        let area = Float((box.right - box.left + 1) * (box.bottom - box.top + 1))
        let thick = Float(leaves[0].count) / area
        let density = 0.75 + 0.6 * Double(min(max((thick - 0.15) / 0.45, 0), 1))
        let ratio = Double(box.bottom - box.top + 1)
            / Double(box.right - box.left + 1)
        let stretch = min(max(ratio / 1.15, 0.8), 1.3)
        return Reading(verdict: .fine, traits: Traits(
            leaf: leaf, variegation: variegation, flower: flower,
            pot: pottery, density: density, stretch: stretch))
    }

    /// Разброс лапласиана по яркости: у резкого снимка края рвутся, у
    /// мыльного плавные.
    static func sharpness(_ rgba: [UInt8], width: Int, height: Int,
                          box: (left: Int, right: Int, top: Int,
                                bottom: Int)) -> Float {
        func gray(_ x: Int, _ y: Int) -> Float {
            let at = (y * width + x) * 4
            return 0.3 * Float(rgba[at]) + 0.59 * Float(rgba[at + 1])
                + 0.11 * Float(rgba[at + 2])
        }
        let left = max(box.left, 1)
        let right = min(box.right, width - 2)
        let top = max(box.top, 1)
        let bottom = min(box.bottom, height - 2)
        guard left < right, top < bottom else { return 0 }
        var sum: Float = 0
        var square: Float = 0
        var count: Float = 0
        for y in top ... bottom {
            for x in left ... right {
                let edge = gray(x - 1, y) + gray(x + 1, y) + gray(x, y - 1)
                    + gray(x, y + 1) - 4 * gray(x, y)
                sum += edge
                square += edge * edge
                count += 1
            }
        }
        let mean = sum / count
        return square / count - mean * mean
    }

    /// Средний по порядку — не среднее: пара бликов цвет не сдвинет.
    static func median(_ channels: [[UInt8]]) -> Channels {
        func middle(_ values: [UInt8]) -> Double {
            let sorted = values.sorted()
            return Double(sorted[sorted.count / 2])
        }
        return Channels(middle(channels[0]), middle(channels[1]),
                        middle(channels[2]))
    }

    /// Тон в градусах, насыщенность и яркость 0…1.
    static func hsv(_ r: UInt8, _ g: UInt8, _ b: UInt8)
        -> (hue: Float, saturation: Float, value: Float) {
        let red = Float(r) / 255
        let green = Float(g) / 255
        let blue = Float(b) / 255
        let top = max(red, green, blue)
        let bottom = min(red, green, blue)
        let spread = top - bottom
        guard spread > 1e-5 else { return (0, 0, top) }
        var hue: Float
        if top == red {
            hue = (green - blue) / spread
        } else if top == green {
            hue = (blue - red) / spread + 2
        } else {
            hue = (red - green) / spread + 4
        }
        hue *= 60
        if hue < 0 { hue += 360 }
        return (hue, spread / top, top)
    }

    /// Без маски растение ищется в середине кадра — эллипс на семь десятых.
    private static func centre(_ width: Int, _ height: Int) -> [Bool] {
        var inside = [Bool](repeating: false, count: width * height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let dx = (Float(x) / Float(width) - 0.5) / 0.35
                let dy = (Float(y) / Float(height) - 0.5) / 0.35
                inside[y * width + x] = dx * dx + dy * dy <= 1
            }
        }
        return inside
    }
}
