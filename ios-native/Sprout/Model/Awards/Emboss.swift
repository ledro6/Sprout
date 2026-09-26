import Foundation

/// Медаль картинкой: металлический кружок с ободком и барельефом растения.
/// Барельеф — сама модель вида спереди: треугольники ложатся в z-буфер,
/// ближнее к зрителю выше. Вокруг — чеканка уровня: жемчужный ободок,
/// звёзды по числу уровней, с третьего — лавровый венок, с четвёртого —
/// лучи по полю, на пятом — ягоды в венке. Поле — гильошированное, с
/// тонким зерном, как у настоящей медали. Рисуется своими руками, без
/// CoreGraphics, — как текстуры моделей: одинаково на телефоне и в проверке
/// на Linux. Высоты — в пикселях; единица чеканки `unit` — сторона на 192.
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

    /// Поле медали: высоты и маска выпуклого — растения и чеканки. По маске
    /// картинка решает, где металл полирован, а где матовый.
    struct Field: Sendable {
        var heights: [Float]
        var raised: [Float]
    }

    /// Поле радиусом `radius` пикселей по середине картинки: растение,
    /// чеканка уровня и гильош с зерном под ними. Выпуклое не суммируется, а
    /// берётся выше из слоёв: венок не вспухает там, где задел лист.
    static func field(_ relief: [Float], size: Int, level: Int,
                      radius: Float) -> Field {
        let unit = Float(size) / 192
        let half = Float(size) / 2
        let soft = blur(relief, size: size)
        let marks = ornament(level: level, size: size, radius: radius)
        var heights = [Float](repeating: 0, count: size * size)
        var raised = [Float](repeating: 0, count: size * size)
        for y in 0 ..< size {
            for x in 0 ..< size {
                let dx = Float(x) + 0.5 - half, dy = Float(y) + 0.5 - half
                let r = (dx * dx + dy * dy).squareRoot()
                let index = y * size + x
                // Барельеф гаснет у ободка: растение не наезжает на него.
                let fade = min(max((radius - r) / (3 * unit), 0), 1)
                let plant = 5 * unit * soft[index] * fade
                let texture = guilloche(x, y, dx: dx, dy: dy, r: r,
                                        radius: radius, unit: unit,
                                        level: level)
                let mark = marks[index]
                heights[index] = unit + max(texture, plant, mark)
                raised[index] = max(plant, mark) > 0.35 * unit ? 1 : 0
            }
        }
        return Field(heights: heights, raised: raised)
    }

    /// Гильош: тонкие кольца, с четвёртого уровня — ещё и лучи, сплетаются
    /// в сетку; поверх — зерно пескоструя. Всё — доли пикселя: узор ловит
    /// свет, а не спорит с растением.
    private static func guilloche(_ x: Int, _ y: Int, dx: Float, dy: Float,
                                  r: Float, radius: Float, unit: Float,
                                  level: Int) -> Float {
        var out = 0.22 * unit + 0.14 * unit * sin(r * 0.9 / unit)
        if level >= 4 {
            let angle = atan2(dy, dx)
            let reach = min(max((r - 0.12 * radius) / (0.25 * radius), 0), 1)
            out += 0.12 * unit * cos(angle * 60) * reach
        }
        return out + (grain(x, y) - 0.5) * 0.12 * unit
    }

    /// Шум без случайных чисел: одна и та же медаль — пиксель в пиксель.
    private static func grain(_ x: Int, _ y: Int) -> Float {
        var mixed = UInt32(truncatingIfNeeded: x &* 73_856_093 ^ y &* 19_349_663)
        mixed ^= mixed >> 13
        mixed = mixed &* 0x5BD1_E995
        mixed ^= mixed >> 15
        return Float(mixed & 0xFFFF) / Float(0xFFFF)
    }

    /// Чеканка уровня — высоты в пикселях, ноль вне её. Места — доли
    /// радиуса поля: на маленькой картинке и на большой текстуре медаль
    /// одна и та же.
    static func ornament(level: Int, size: Int, radius: Float) -> [Float] {
        let unit = Float(size) / 192
        let middle = SIMD2<Float>(repeating: Float(size) / 2)
        var out = [Float](repeating: 0, count: size * size)
        // Жемчужный ободок по краю поля.
        let beads = 72
        let bead = 0.021 * radius
        for index in 0 ..< beads {
            let angle = 2 * Float.pi * Float(index) / Float(beads)
            let spot = middle + 0.935 * radius * SIMD2(cos(angle), sin(angle))
            stamp(&out, size: size, at: spot, reach: bead) { point in
                dome(point, bead, 1.5 * unit)
            }
        }
        // Звёзды — по числу уровней, дугой над растением, лучом наружу.
        let count = max(level, 1)
        for index in 0 ..< count {
            let angle = -Float.pi / 2 + (Float(index) - Float(count - 1) / 2) * 0.24
            let spot = middle + 0.82 * radius * SIMD2(cos(angle), sin(angle))
            stamp(&out, size: size, at: spot, reach: 0.085 * radius) { point in
                star(point, turn: angle, outer: 0.085 * radius,
                     inner: 0.036 * radius, height: 2.2 * unit)
            }
        }
        guard level >= 3 else { return out }
        // Венок: две ветви снизу вверх, к звёздам. Бант — там, где ветви
        // сходятся.
        let ring = 0.8 * radius
        let leaves = 6
        for side: Float in [1, -1] {
            func along(_ t: Float) -> Float { .pi / 2 + side * (0.16 + 1.05 * t) }
            var t: Float = 0
            while t <= 1 {
                let angle = along(t)
                let spot = middle + ring * SIMD2(cos(angle), sin(angle))
                stamp(&out, size: size, at: spot, reach: 0.011 * radius) {
                    dome($0, 0.011 * radius, 0.9 * unit)
                }
                t += 0.004
            }
            for index in 0 ..< leaves {
                let t = (Float(index) + 0.6) / Float(leaves)
                let angle = along(t)
                let outward = SIMD2(cos(angle), sin(angle))
                let ahead = SIMD2(-sin(angle), cos(angle)) * side
                let spot = middle + ring * outward
                let length = 0.16 * radius * (1 - 0.3 * t)
                let width = 0.062 * radius * (1 - 0.25 * t)
                for lean: Float in [1, -1] {
                    let tilt: Float = 0.62
                    let way = normalized(ahead * cos(tilt) + outward * sin(tilt) * lean)
                    let heart = spot + way * (length * 0.5)
                    stamp(&out, size: size, at: heart, reach: length * 0.5) {
                        leaf($0, way: way, length: length, width: width,
                             unit: unit)
                    }
                }
                if level >= 5 {
                    let berry = spot + outward * (0.05 * radius)
                        - ahead * (0.02 * radius)
                    stamp(&out, size: size, at: berry,
                          reach: 0.022 * radius) {
                        dome($0, 0.022 * radius, 1.6 * unit)
                    }
                }
            }
            // Верхушка ветви — лист вдоль неё.
            let tip = along(1)
            let way = SIMD2(-sin(tip), cos(tip)) * side
            let length = 0.11 * radius
            let heart = middle + ring * SIMD2(cos(tip), sin(tip))
                + way * (length * 0.5)
            stamp(&out, size: size, at: heart, reach: length * 0.5) {
                leaf($0, way: way, length: length, width: 0.045 * radius,
                     unit: unit)
            }
        }
        let bow = middle + SIMD2(0, ring)
        stamp(&out, size: size, at: bow, reach: 0.07 * radius) { point in
            // Узел — две петли и середина.
            let knot = dome(point, 0.026 * radius, 1.9 * unit)
            let loops = max(dome(point - SIMD2(0.042 * radius, 0), 0.03 * radius,
                                 1.4 * unit),
                            dome(point + SIMD2(0.042 * radius, 0), 0.03 * radius,
                                 1.4 * unit))
            return max(knot, loops)
        }
        return out
    }

    /// Оборот объёмной медали: кольца, как на пластинке, и жемчужный
    /// ободок. Надпись — снаружи: буквы рисует телефон, см. `MedalCraft`.
    static func back(size: Int) -> [Float] {
        let unit = Float(size) / 192
        let half = Float(size) / 2
        let radius = half - 1
        var out = ornament(level: 0, size: size, radius: radius)
        // Без звезды: на обороте ей не место.
        let middle = SIMD2<Float>(repeating: half)
        let top = middle + 0.835 * radius * SIMD2(0, -1)
        clear(&out, size: size, at: top, reach: 0.07 * radius)
        for y in 0 ..< size {
            for x in 0 ..< size {
                let dx = Float(x) + 0.5 - half, dy = Float(y) + 0.5 - half
                let r = (dx * dx + dy * dy).squareRoot()
                let index = y * size + x
                let rings = 0.2 * unit + 0.1 * unit * sin(r * 1.6 / unit)
                    + (grain(x, y) - 0.5) * 0.12 * unit
                out[index] = unit + max(out[index], rings)
            }
        }
        return out
    }

    /// Медаль целиком: ободок валиком с насечкой, матовое поле и блестящий
    /// барельеф с чеканкой. Свет слева сверху, отблеск — от неба: верхние
    /// склоны светлее. Не полученная — сталь без блеска.
    static func medal(_ relief: [Float], size: Int, level: Int,
                      earned: Bool = true) -> Picture {
        let alloy = Alloy.of(level)
        let light = earned ? alloy.light : Alloy.steelLight
        let dark = earned ? alloy.dark : Alloy.steelDark
        let unit = Float(size) / 192
        let half = Float(size) / 2
        let outer = half - 1
        let rim = outer * face
        let plate = field(relief, size: size, level: level, radius: rim)
        var heights = plate.heights
        for y in 0 ..< size {
            for x in 0 ..< size {
                let dx = Float(x) + 0.5 - half, dy = Float(y) + 0.5 - half
                let r = (dx * dx + dy * dy).squareRoot()
                guard r > rim else { continue }
                // Валик: полукруг от края поля до края медали; по внешнему
                // склону — насечка, как на гурте монеты.
                let t = min((r - rim) / (outer - rim), 1)
                let knurl = max(t - 0.6, 0) / 0.4
                    * (0.5 + 0.5 * cos(atan2(dy, dx) * 100))
                heights[y * size + x] = 7 * unit * sin(.pi * t).squareRoot()
                    - 0.7 * unit * knurl
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
                let hl = heights[y * size + max(x - 1, 0)]
                let hr = heights[y * size + min(x + 1, size - 1)]
                let hu = heights[max(y - 1, 0) * size + x]
                let hd = heights[min(y + 1, size - 1) * size + x]
                // Ряды — сверху вниз, как и свет: y у нормали растёт вниз.
                let normal = Vec3((hl - hr) / 2, (hu - hd) / 2, 1).unit
                let diffuse = max(normal.dotted(sun), 0)
                let sky = 0.5 + 0.5 * normal.dotted(Vec3(0, -0.8, 0.6).unit)
                let raised = r <= rim && plate.raised[index] > 0
                let polish: Float = earned ? (r > rim || raised ? 1 : 0.55) : 0.3
                let shine = pow(max(normal.dotted(half3), 0), 48) * polish
                let sheen = pow(max(normal.dotted(half3), 0), 6) * 0.2 * polish
                // Отблеск по полю: свет сверху слева, тень снизу справа —
                // ровное поле без него читалось бы краской, а не металлом.
                let sweep = -(dx * 0.6 + dy * 0.8) / outer
                let flat: Float = r <= rim && !raised ? 0.08 : 0
                let tone = min(max(0.06 + 0.48 * sky + 0.36 * diffuse
                                   + 0.18 * sweep - flat + sheen, 0), 1)
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

    /// Карта нормалей по высотам в пикселях — для объёмной медали: сама
    /// медаль — настоящий диск с ободком, а растение и чеканка на поле —
    /// рельефом под светом сцены. Ряды сверху вниз, а v текстуры — снизу
    /// вверх.
    static func normals(_ heights: [Float], size: Int) -> Picture {
        var picture = Picture(width: size, height: size,
                              fill: Ink(0.5, 0.5, 1, 1))
        func at(_ x: Int, _ y: Int) -> Float {
            heights[min(max(y, 0), size - 1) * size + min(max(x, 0), size - 1)]
        }
        for y in 0 ..< size {
            for x in 0 ..< size {
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

    /// Студия для отражений объёмной медали — развёртка сферы, ширина вдвое
    /// больше высоты: светлый купол сверху, тёплый софтбокс слева, холодный
    /// контровой сзади, вертикальные полосы по кругу и тёмный пол. Металл
    /// отражает окружение, и полосы бегут по нему, пока медаль крутится.
    static func studio(width: Int) -> Picture {
        let height = max(width / 2, 1)
        var picture = Picture(width: width, height: height)
        func soft(_ distance: Float, _ edge: Float) -> Float {
            min(max(1 - distance / edge, 0), 1)
        }
        for y in 0 ..< height {
            let latitude = (0.5 - (Float(y) + 0.5) / Float(height)) * .pi
            for x in 0 ..< width {
                let longitude = ((Float(x) + 0.5) / Float(width) - 0.5) * 2 * .pi
                var ink = latitude > 0
                    ? Vec3(repeating: 0.32 + 0.22 * sin(latitude))
                    : Vec3(repeating: 0.12 + 0.08 * sin(latitude))
                let dome = soft(max(0.95 - latitude, 0), 0.35)
                ink += Vec3(repeating: 0.9 * dome)
                for strip: Float in [-2.2, -0.75, 0.75, 2.2] {
                    var gap = abs(longitude - strip)
                    gap = min(gap, 2 * .pi - gap)
                    let upright = latitude > -0.15 && latitude < 0.85 ? 1 : 0
                    ink += Vec3(repeating: 0.85 * soft(gap, 0.14) * Float(upright))
                }
                func spot(_ at: SIMD2<Float>, _ reach: Float) -> Float {
                    var gap = abs(longitude - at.x)
                    gap = min(gap, 2 * .pi - gap)
                    let d = (gap * gap + (latitude - at.y) * (latitude - at.y))
                        .squareRoot()
                    return soft(d, reach)
                }
                ink += Vec3(1, 0.9, 0.76) * spot(SIMD2(-0.6, 0.42), 0.45)
                ink += Vec3(0.72, 0.84, 1) * spot(SIMD2(2.6, 0.25), 0.4) * 0.8
                picture.set(x, y, Ink(min(ink.x, 1), min(ink.y, 1),
                                      min(ink.z, 1), 1))
            }
        }
        return picture
    }

    // MARK: - Чеканка

    /// Форма оттиска вокруг точки `at`: высота в каждом пикселе квадрата
    /// `reach`, выше прежней — остаётся.
    private static func stamp(_ out: inout [Float], size: Int,
                              at spot: SIMD2<Float>, reach: Float,
                              _ shape: (SIMD2<Float>) -> Float) {
        let left = max(Int((spot.x - reach).rounded(.down)), 0)
        let right = min(Int((spot.x + reach).rounded(.up)), size - 1)
        let top = max(Int((spot.y - reach).rounded(.down)), 0)
        let bottom = min(Int((spot.y + reach).rounded(.up)), size - 1)
        guard left <= right, top <= bottom else { return }
        for y in top ... bottom {
            for x in left ... right {
                let point = SIMD2(Float(x) + 0.5, Float(y) + 0.5) - spot
                let value = shape(point)
                let index = y * size + x
                if value > out[index] { out[index] = value }
            }
        }
    }

    private static func clear(_ out: inout [Float], size: Int,
                              at spot: SIMD2<Float>, reach: Float) {
        let left = max(Int(spot.x - reach), 0)
        let right = min(Int(spot.x + reach) + 1, size - 1)
        let top = max(Int(spot.y - reach), 0)
        let bottom = min(Int(spot.y + reach) + 1, size - 1)
        guard left <= right, top <= bottom else { return }
        for y in top ... bottom {
            for x in left ... right { out[y * size + x] = 0 }
        }
    }

    /// Полусфера: жемчужина, ягода, узел банта.
    private static func dome(_ point: SIMD2<Float>, _ radius: Float,
                             _ height: Float) -> Float {
        let d = (point * point).sum().squareRoot()
        guard d < radius else { return 0 }
        return height * (1 - (d / radius) * (d / radius)).squareRoot()
    }

    /// Пятиконечная звезда гранями: рёбра от середины к лучам, как у
    /// чеканной. `turn` — куда смотрит луч.
    private static func star(_ point: SIMD2<Float>, turn: Float, outer: Float,
                             inner: Float, height: Float) -> Float {
        let d = (point * point).sum().squareRoot()
        guard d < outer else { return 0 }
        let sector = 2 * Float.pi / 5
        var angle = (atan2(point.y, point.x) - turn)
            .truncatingRemainder(dividingBy: sector)
        if angle < 0 { angle += sector }
        let tip = abs(angle / sector * 2 - 1)
        let edge = inner + (outer - inner) * tip
        guard d < edge else { return 0 }
        return height * (1 - d / edge)
    }

    /// Лист венка: острый с обоих концов, выпуклый, с прожилкой посередине.
    private static func leaf(_ point: SIMD2<Float>, way: SIMD2<Float>,
                             length: Float, width: Float,
                             unit: Float) -> Float {
        let along = (point * way).sum()
        let across = point.x * way.y - point.y * way.x
        let half = length / 2
        guard abs(along) < half else { return 0 }
        let span = width / 2 * cos(.pi / 2 * along / half)
        guard abs(across) < span, span > 0 else { return 0 }
        let body = 1.6 * unit * (1 - (across / span) * (across / span))
            .squareRoot()
        let vein = 0.35 * unit * max(0, 1 - abs(across) / (0.12 * width))
        return max(body - vein, 0.05 * unit)
    }

    private static func normalized(_ v: SIMD2<Float>) -> SIMD2<Float> {
        let length = (v * v).sum().squareRoot()
        return length > 1e-6 ? v / length : SIMD2(1, 0)
    }

    /// Смягчение в пиксель: края листьев — фаской, а не обрывом.
    static func blur(_ values: [Float], size: Int) -> [Float] {
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
