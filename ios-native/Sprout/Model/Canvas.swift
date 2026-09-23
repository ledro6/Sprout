import Foundation

/// Цвет с прозрачностью, 0…1.
typealias Ink = SIMD4<Float>

extension Channels {
    /// Цвет каналами — в краску: доли и непрозрачность.
    func ink(_ alpha: Float = 1) -> Ink {
        Ink(Float(red / 255), Float(green / 255), Float(blue / 255), alpha)
    }
}

/// Картинка RGBA по байту на канал, ряды сверху вниз, прозрачность не
/// умножена на цвет. Рисуется своими руками, без CoreGraphics: так
/// текстуры одинаковы на телефоне и в проверке на Linux.
///
/// Рисуют в координатах текстуры: u — слева направо, v — снизу вверх, обе
/// 0…1. Толщина линий — в долях ширины.
struct Picture: Equatable, Sendable {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, fill: Ink = .zero) {
        self.width = width
        self.height = height
        let bytes = Picture.bytes(fill)
        pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0 ..< width * height {
            pixels[index * 4] = bytes.0
            pixels[index * 4 + 1] = bytes.1
            pixels[index * 4 + 2] = bytes.2
            pixels[index * 4 + 3] = bytes.3
        }
    }

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    private static func bytes(_ ink: Ink) -> (UInt8, UInt8, UInt8, UInt8) {
        func byte(_ value: Float) -> UInt8 {
            UInt8(min(max(value, 0), 1) * 255 + 0.5)
        }
        return (byte(ink.x), byte(ink.y), byte(ink.z), byte(ink.w))
    }

    func ink(at x: Int, _ y: Int) -> Ink {
        let at = (y * width + x) * 4
        return Ink(Float(pixels[at]), Float(pixels[at + 1]),
                   Float(pixels[at + 2]), Float(pixels[at + 3])) / 255
    }

    mutating func set(_ x: Int, _ y: Int, _ ink: Ink) {
        let at = (y * width + x) * 4
        let bytes = Picture.bytes(ink)
        pixels[at] = bytes.0
        pixels[at + 1] = bytes.1
        pixels[at + 2] = bytes.2
        pixels[at + 3] = bytes.3
    }

    /// Точка текстуры — в пиксели.
    func spot(_ uv: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2(uv.x * Float(width), (1 - uv.y) * Float(height))
    }

    /// Доля каждого пикселя, покрытая многоугольником, — по четыре строки
    /// на пиксель и точными краями по горизонтали. Правило чёт-нечет.
    static func coverage(_ polygon: [SIMD2<Float>], width: Int,
                         height: Int) -> [Float] {
        var cover = [Float](repeating: 0, count: width * height)
        guard polygon.count > 2 else { return cover }
        let ys = polygon.map(\.y)
        let top = max(Int(floor(ys.min()!)), 0)
        let bottom = min(Int(ceil(ys.max()!)), height - 1)
        guard top <= bottom else { return cover }
        let samples = 4
        var crossings: [Float] = []
        for row in top ... bottom {
            for sub in 0 ..< samples {
                let y = Float(row) + (Float(sub) + 0.5) / Float(samples)
                crossings.removeAll(keepingCapacity: true)
                for index in polygon.indices {
                    let a = polygon[index]
                    let b = polygon[(index + 1) % polygon.count]
                    guard (a.y <= y) != (b.y <= y) else { continue }
                    crossings.append(a.x + (y - a.y) / (b.y - a.y)
                        * (b.x - a.x))
                }
                crossings.sort()
                var pair = 0
                while pair + 1 < crossings.count {
                    let start = max(crossings[pair], 0)
                    let end = min(crossings[pair + 1], Float(width))
                    pair += 2
                    guard start < end else { continue }
                    let first = Int(start)
                    let last = min(Int(end), width - 1)
                    let weight = 1 / Float(samples)
                    if first == last {
                        cover[row * width + first] += (end - start) * weight
                        continue
                    }
                    cover[row * width + first] += (Float(first + 1) - start)
                        * weight
                    if last > first + 1 {
                        for column in first + 1 ..< last {
                            cover[row * width + column] += weight
                        }
                    }
                    if last < width {
                        cover[row * width + last] += (end - Float(last))
                            * weight
                    }
                }
            }
        }
        return cover.map { min($0, 1) }
    }

    enum Blend {
        /// Поверх, с прозрачностью.
        case over
        /// Стереть: прозрачность уходит.
        case erase
    }

    /// Закрасить многоугольник в координатах текстуры.
    mutating func fill(_ shape: [SIMD2<Float>], _ ink: Ink,
                       blend: Blend = .over) {
        let cover = Picture.coverage(shape.map(spot), width: width,
                                     height: height)
        apply(cover, ink, blend: blend)
    }

    mutating func apply(_ cover: [Float], _ ink: Ink, blend: Blend = .over) {
        for index in cover.indices where cover[index] > 0 {
            let x = index % width
            let y = index / width
            let old = self.ink(at: x, y)
            switch blend {
            case .erase:
                var kept = old
                kept.w = old.w * (1 - cover[index])
                set(x, y, kept)
            case .over:
                let a = ink.w * cover[index]
                let alpha = a + old.w * (1 - a)
                guard alpha > 0 else { continue }
                let color = (SIMD3(ink.x, ink.y, ink.z) * a
                    + SIMD3(old.x, old.y, old.z) * old.w * (1 - a)) / alpha
                set(x, y, Ink(color.x, color.y, color.z, alpha))
            }
        }
    }

    /// Линия переменной толщины: из пути строится полоса и закрашивается.
    /// Концы скруглены кружками — жилка не обрывается ступенькой.
    mutating func stroke(_ path: [SIMD2<Float>], width thickness: (Float) -> Float,
                         _ ink: Ink, blend: Blend = .over) {
        guard let band = Picture.band(path.map(spot), scale: Float(width),
                                      thickness: thickness)
        else { return }
        fill(band.map { SIMD2($0.x / Float(width),
                              1 - $0.y / Float(height)) }, ink, blend: blend)
    }

    /// Полоса вокруг пути в пикселях.
    static func band(_ points: [SIMD2<Float>], scale: Float,
                     thickness: (Float) -> Float) -> [SIMD2<Float>]? {
        guard points.count > 1 else { return nil }
        var left: [SIMD2<Float>] = []
        var right: [SIMD2<Float>] = []
        let last = points.count - 1
        for (index, point) in points.enumerated() {
            let ahead = points[min(index + 1, last)]
            let behind = points[max(index - 1, 0)]
            var way = ahead - behind
            let length = (way * way).sum().squareRoot()
            way = length > 0 ? way / length : SIMD2(1, 0)
            let normal = SIMD2(-way.y, way.x)
            let half = thickness(Float(index) / Float(last)) * scale / 2
            left.append(point + normal * half)
            right.append(point - normal * half)
        }
        return left + right.reversed()
    }

    /// Круг или эллипс в координатах текстуры; радиус — в долях ширины.
    mutating func disc(_ center: SIMD2<Float>, radius: Float,
                       squash: Float = 1, _ ink: Ink, blend: Blend = .over) {
        let aspect = Float(width) / Float(height)
        let shape = (0 ..< 20).map { step -> SIMD2<Float> in
            let angle = 2 * Float.pi * Float(step) / 20
            return center + SIMD2(cos(angle) * radius,
                                  sin(angle) * radius * aspect * squash)
        }
        fill(shape, ink, blend: blend)
    }

    /// Перекрасить каждый пиксель: функция получает точку текстуры и
    /// прежний цвет. Для переходов, шума и пятен.
    mutating func shade(_ paint: (SIMD2<Float>, Ink) -> Ink) {
        for y in 0 ..< height {
            for x in 0 ..< width {
                let uv = SIMD2((Float(x) + 0.5) / Float(width),
                               1 - (Float(y) + 0.5) / Float(height))
                set(x, y, paint(uv, ink(at: x, y)))
            }
        }
    }

    /// Прозрачность — по покрытию: всё, что нарисовано за контуром, уходит.
    mutating func clip(to cover: [Float]) {
        for index in cover.indices {
            pixels[index * 4 + 3] = UInt8(Float(pixels[index * 4 + 3])
                * min(max(cover[index], 0), 1) + 0.5)
        }
    }

    /// Увядший вариант: зелень уходит в солому, светлота остаётся. Сцена
    /// меняет рисунок ступенями — умножением цвета зелёное в жёлтое не
    /// перекрасить.
    func withered(_ amount: Float) -> Picture {
        guard amount > 0 else { return self }
        var out = self
        let straw = SIMD3<Float>(0.86, 0.72, 0.36)
        let strawLight = (straw * SIMD3(0.3, 0.59, 0.11)).sum()
        for index in 0 ..< width * height {
            let at = index * 4
            let color = SIMD3(Float(pixels[at]), Float(pixels[at + 1]),
                              Float(pixels[at + 2])) / 255
            let light = (color * SIMD3(0.3, 0.59, 0.11)).sum()
            let dry = straw * (light / strawLight) * 0.92
            let mixed = color * (1 - amount) + dry * amount
            out.pixels[at] = UInt8(min(max(mixed.x, 0), 1) * 255 + 0.5)
            out.pixels[at + 1] = UInt8(min(max(mixed.y, 0), 1) * 255 + 0.5)
            out.pixels[at + 2] = UInt8(min(max(mixed.z, 0), 1) * 255 + 0.5)
        }
        return out
    }

    /// Доля непрозрачного — для проверок.
    var opaque: Float {
        var sum: Float = 0
        for index in 0 ..< width * height {
            sum += Float(pixels[index * 4 + 3]) / 255
        }
        return sum / Float(width * height)
    }
}

/// Рельеф — высота на пиксель. Из него получается карта нормалей: жилки
/// под светом утоплены, середина приподнята, хотя сетка плоская.
struct Relief: Sendable {
    let width: Int
    let height: Int
    var values: [Float]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        values = [Float](repeating: 0, count: width * height)
    }

    func spot(_ uv: SIMD2<Float>) -> SIMD2<Float> {
        SIMD2(uv.x * Float(width), (1 - uv.y) * Float(height))
    }

    mutating func raise(_ shape: [SIMD2<Float>], by amount: Float) {
        let cover = Picture.coverage(shape.map(spot), width: width,
                                     height: height)
        for index in cover.indices { values[index] += cover[index] * amount }
    }

    mutating func stroke(_ path: [SIMD2<Float>], width thickness: (Float) -> Float,
                         by amount: Float) {
        guard let band = Picture.band(path.map(spot), scale: Float(width),
                                      thickness: thickness)
        else { return }
        let cover = Picture.coverage(band, width: width, height: height)
        for index in cover.indices { values[index] += cover[index] * amount }
    }

    /// Размыть коробкой — края жилок мягче.
    mutating func soften(_ radius: Int) {
        guard radius > 0 else { return }
        var out = values
        for y in 0 ..< height {
            for x in 0 ..< width {
                var sum: Float = 0
                var count: Float = 0
                for dy in -radius ... radius {
                    let row = min(max(y + dy, 0), height - 1)
                    for dx in -radius ... radius {
                        let column = min(max(x + dx, 0), width - 1)
                        sum += values[row * width + column]
                        count += 1
                    }
                }
                out[y * width + x] = sum / count
            }
        }
        values = out
    }

    /// Карта нормалей: наклон рельефа в цвет, плоское — (0.5, 0.5, 1).
    func normals(strength: Float) -> Picture {
        var picture = Picture(width: width, height: height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let left = values[y * width + max(x - 1, 0)]
                let right = values[y * width + min(x + 1, width - 1)]
                let up = values[max(y - 1, 0) * width + x]
                let down = values[min(y + 1, height - 1) * width + x]
                // Ряды идут сверху вниз, а v — снизу вверх: знак у dy другой.
                let normal = Vec3((left - right) * strength,
                                  (down - up) * strength, 1).unit
                picture.set(x, y, Ink(normal.x * 0.5 + 0.5,
                                      normal.y * 0.5 + 0.5,
                                      normal.z * 0.5 + 0.5, 1))
            }
        }
        return picture
    }
}

/// Шум: гладкие пятна для мраморности, пор терракоты, зерна земли. От
/// координат и зерна, без случайности — одна и та же текстура каждый раз.
/// С периодом по u: текстура горшка сходится на шве.
enum Noise {
    private static func hash(_ x: Int, _ y: Int, _ seed: UInt32) -> Float {
        var h = UInt32(truncatingIfNeeded: x) &* 374_761_393
            &+ UInt32(truncatingIfNeeded: y) &* 668_265_263 &+ seed &* 2_654_435_761
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Float(h & 0xffff) / 65_535
    }

    static func value(_ u: Float, _ v: Float, cells: Int, seed: UInt32) -> Float {
        let x = u * Float(cells)
        let y = v * Float(cells)
        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let fx = x - Float(x0)
        let fy = y - Float(y0)
        let sx = fx * fx * (3 - 2 * fx)
        let sy = fy * fy * (3 - 2 * fy)
        func corner(_ cx: Int, _ cy: Int) -> Float {
            hash(((cx % cells) + cells) % cells, cy, seed)
        }
        let top = corner(x0, y0) + (corner(x0 + 1, y0) - corner(x0, y0)) * sx
        let bottom = corner(x0, y0 + 1)
            + (corner(x0 + 1, y0 + 1) - corner(x0, y0 + 1)) * sx
        return top + (bottom - top) * sy
    }

    /// Несколько слоёв мельче и мельче — от 0 до 1.
    static func fractal(_ u: Float, _ v: Float, cells: Int, seed: UInt32,
                        layers: Int = 4) -> Float {
        var sum: Float = 0
        var weight: Float = 0.5
        var total: Float = 0
        var scale = cells
        for layer in 0 ..< layers {
            sum += value(u, v, cells: scale, seed: seed &+ UInt32(layer)) * weight
            total += weight
            weight *= 0.5
            scale *= 2
        }
        return sum / total
    }
}
