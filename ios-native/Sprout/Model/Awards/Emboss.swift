import Foundation

/// Медаль картинкой: металлический кружок с ободком и барельефом растения.
/// Барельеф — сама модель вида спереди: треугольники ложатся в z-буфер,
/// ближнее к зрителю выше. Рисуется своими руками, без CoreGraphics, — как
/// текстуры моделей: одинаково на телефоне и в проверке на Linux.
enum Emboss {
    /// Растение занимает такую долю стороны: вместе с горшком оно
    /// вписывается в поле внутри ободка.
    static let fill: Float = 0.56

    /// Поле — внутри ободка, доля радиуса.
    static let face: Float = 0.82

    /// Карта высот барельефа, ряды сверху вниз: 0 — фон, от 0.35 у дальних
    /// частей растения до 1 у ближних.
    static func relief(_ kit: Kit, size: Int) -> [Float] {
        var depth = [Float](repeating: -.infinity, count: size * size)
        var low = Vec3(repeating: .greatestFiniteMagnitude)
        var high = Vec3(repeating: -.greatestFiniteMagnitude)
        var triangles: [(Vec3, Vec3, Vec3)] = []
        for piece in kit.pieces where kit.meshes.indices.contains(piece.mesh) {
            let mesh = kit.meshes[piece.mesh]
            let placed = mesh.positions.map { piece.pose.place($0) }
            for point in placed {
                low = pointwiseMin(low, point)
                high = pointwiseMax(high, point)
            }
            var at = 0
            while at + 2 < mesh.indices.count {
                triangles.append((placed[Int(mesh.indices[at])],
                                  placed[Int(mesh.indices[at + 1])],
                                  placed[Int(mesh.indices[at + 2])]))
                at += 3
            }
        }
        guard !triangles.isEmpty else {
            return [Float](repeating: 0, count: size * size)
        }
        let span = high - low
        let scale = Float(size) * fill / max(span.x, span.y, 1e-6)
        let middle = (low + high) / 2
        let half = Float(size) / 2
        func pixel(_ point: Vec3) -> Vec3 {
            Vec3(half + (point.x - middle.x) * scale,
                 half - (point.y - middle.y) * scale, point.z)
        }
        func edge(_ u: Vec3, _ v: Vec3, _ x: Float, _ y: Float) -> Float {
            (v.x - u.x) * (y - u.y) - (v.y - u.y) * (x - u.x)
        }
        for (first, second, third) in triangles {
            let a = pixel(first), b = pixel(second), c = pixel(third)
            let area = edge(a, b, c.x, c.y)
            guard abs(area) > 1e-6 else { continue }
            let left = max(Int(min(a.x, b.x, c.x).rounded(.down)), 0)
            let right = min(Int(max(a.x, b.x, c.x).rounded(.up)), size - 1)
            let top = max(Int(min(a.y, b.y, c.y).rounded(.down)), 0)
            let bottom = min(Int(max(a.y, b.y, c.y).rounded(.up)), size - 1)
            guard left <= right, top <= bottom else { continue }
            for y in top ... bottom {
                let sy = Float(y) + 0.5
                for x in left ... right {
                    let sx = Float(x) + 0.5
                    // Доли вершин; тонкие листья в пиксель шириной не
                    // должны проваливаться между центрами — запас в тысячную.
                    let wa = edge(b, c, sx, sy) / area
                    let wb = edge(c, a, sx, sy) / area
                    let wc = 1 - wa - wb
                    guard wa >= -1e-3, wb >= -1e-3, wc >= -1e-3 else {
                        continue
                    }
                    let z = wa * a.z + wb * b.z + wc * c.z
                    let index = y * size + x
                    if z > depth[index] { depth[index] = z }
                }
            }
        }
        let near = max(span.z, 1e-6)
        return depth.map { z in
            z == -.infinity ? 0 : 0.35 + 0.65 * min(max((z - low.z) / near, 0), 1)
        }
    }

    /// Медаль целиком: ободок валиком, матовое поле и блестящий барельеф.
    /// Свет слева сверху, отблеск — от неба: верхние склоны светлее. Не
    /// полученная — сталь без блеска.
    static func medal(_ relief: [Float], size: Int, alloy: Alloy,
                      earned: Bool = true) -> Picture {
        let light = earned ? alloy.light : Alloy.steelLight
        let dark = earned ? alloy.dark : Alloy.steelDark
        let unit = Float(size) / 192
        let half = Float(size) / 2
        let outer = half - 1
        let rim = outer * face
        let soft = blur(relief, size: size)
        var heights = [Float](repeating: 0, count: size * size)
        for y in 0 ..< size {
            for x in 0 ..< size {
                let dx = Float(x) + 0.5 - half, dy = Float(y) + 0.5 - half
                let r = (dx * dx + dy * dy).squareRoot()
                let index = y * size + x
                if r > rim {
                    // Валик: полукруг от края поля до края медали.
                    let t = min((r - rim) / (outer - rim), 1)
                    heights[index] = 7 * unit * sin(.pi * t).squareRoot()
                } else {
                    // Барельеф гаснет у ободка: растение не наезжает на него.
                    let fade = min(max((rim - r) / (3 * unit), 0), 1)
                    heights[index] = unit * (1 + 5 * soft[index] * fade)
                }
            }
        }
        let sun = Vec3(-0.45, -0.55, 0.7).unit
        let half3 = (sun + Vec3(0, 0, 1)).unit
        var picture = Picture(width: size, height: size)
        for y in 0 ..< size {
            for x in 0 ..< size {
                let dx = Float(x) + 0.5 - half, dy = Float(y) + 0.5 - half
                let r = (dx * dx + dy * dy).squareRoot()
                let alpha = min(max(outer + 0.5 - r, 0), 1)
                guard alpha > 0 else { continue }
                let index = y * size + x
                let h = heights[index]
                let hl = heights[y * size + max(x - 1, 0)]
                let hr = heights[y * size + min(x + 1, size - 1)]
                let hu = heights[max(y - 1, 0) * size + x]
                let hd = heights[min(y + 1, size - 1) * size + x]
                // Ряды — сверху вниз, как и свет: y у нормали растёт вниз.
                let normal = Vec3((hl - hr) / 2, (hu - hd) / 2, 1).unit
                let diffuse = max(normal.dotted(sun), 0)
                let sky = 0.5 + 0.5 * normal.dotted(Vec3(0, -0.8, 0.6).unit)
                let raised = r <= rim && h > unit * 1.2
                let polish: Float = earned ? (r > rim || raised ? 1 : 0.55) : 0.3
                let shine = pow(max(normal.dotted(half3), 0), 48) * polish
                let sheen = pow(max(normal.dotted(half3), 0), 6) * 0.2 * polish
                // Отблеск по полю: свет сверху слева, тень снизу справа —
                // ровное поле без него читалось бы краской, а не металлом.
                let sweep = -(dx * 0.6 + dy * 0.8) / outer
                // Поле — матовое, с тонкими кольцами, как у гильошированной
                // медали; барельеф и ободок гладкие.
                let rings: Float = r <= rim && !raised
                    ? 0.025 * sin(r * 0.9 / unit) : 0
                let flat: Float = r <= rim && !raised ? 0.08 : 0
                let tone = min(max(0.06 + 0.48 * sky + 0.36 * diffuse
                                   + 0.18 * sweep + rings - flat + sheen, 0),
                               1)
                let base = Channels.mix(dark, light, Double(tone)).ink()
                let white = Ink(1, 1, 1, 1)
                var ink = base + (white - base) * min(shine * 0.9, 1)
                // Лёгкая тень у ободка: поле утоплено.
                if r <= rim {
                    let shade = 1 - 0.22 * max(0, 1 - (rim - r) / (6 * unit))
                    ink = Ink(ink.x * shade, ink.y * shade, ink.z * shade, 1)
                }
                ink.w = alpha
                picture.set(x, y, ink)
            }
        }
        return picture
    }

    /// Барельеф для объёмной медали — картой нормалей поля: сама медаль —
    /// настоящий диск с ободком, а растение на поле рельефом под светом
    /// сцены.
    static func normals(_ relief: [Float], size: Int) -> Picture {
        let soft = blur(relief, size: size)
        let unit = Float(size) / 192
        var picture = Picture(width: size, height: size,
                              fill: Ink(0.5, 0.5, 1, 1))
        for y in 0 ..< size {
            for x in 0 ..< size {
                let at = { (x: Int, y: Int) in
                    soft[min(max(y, 0), size - 1) * size + min(max(x, 0), size - 1)]
                        * 5 * unit
                }
                // Ряды сверху вниз, а v текстуры — снизу вверх.
                let normal = Vec3(at(x - 1, y) - at(x + 1, y),
                                  at(x, y + 1) - at(x, y - 1), 2).unit
                picture.set(x, y, Ink(normal.x * 0.5 + 0.5,
                                      normal.y * 0.5 + 0.5,
                                      normal.z * 0.5 + 0.5, 1))
            }
        }
        return picture
    }

    /// Ряды задом наперёд. Поле объёмной медали смотрит на зрителя, повёрнутое
    /// от пола: v текстуры там идёт вниз, и без переворота растение стояло бы
    /// вверх ногами.
    static func flipped(_ values: [Float], size: Int) -> [Float] {
        (0 ..< size).flatMap { row in
            values[(size - 1 - row) * size ..< (size - row) * size]
        }
    }

    /// Смягчение в пиксель: края листьев — фаской, а не обрывом.
    private static func blur(_ values: [Float], size: Int) -> [Float] {
        var out = values
        for y in 0 ..< size {
            for x in 0 ..< size {
                var sum: Float = 0
                var count: Float = 0
                for oy in -1 ... 1 {
                    for ox in -1 ... 1 {
                        let nx = x + ox, ny = y + oy
                        guard nx >= 0, ny >= 0, nx < size, ny < size else {
                            continue
                        }
                        sum += values[ny * size + nx]
                        count += 1
                    }
                }
                out[y * size + x] = sum / count
            }
        }
        return out
    }
}
