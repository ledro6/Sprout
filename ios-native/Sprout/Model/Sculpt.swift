import Foundation

/// Точка и направление в объёме, в метрах. Сцена RealityKit — правая, ось Y
/// вверх.
typealias Vec3 = SIMD3<Float>

/// Своими именами, а не `simd`: модель собирается и на Linux, где `simd`
/// нет, а одноимённые функции спорили бы с ним на телефоне.
extension SIMD3 where Scalar == Float {
    func dotted(_ other: Vec3) -> Float { (self * other).sum() }

    func crossed(_ other: Vec3) -> Vec3 {
        Vec3(y * other.z - z * other.y,
             z * other.x - x * other.z,
             x * other.y - y * other.x)
    }

    var size: Float { dotted(self).squareRoot() }

    /// Нулевой вектор направления не имеет — отвечаем «вверх», а не NaN.
    var unit: Vec3 {
        let length = size
        return length > 1e-9 ? self / length : Vec3(0, 1, 0)
    }

    /// Поворот по правилу правой руки — как у `simd_quatf(angle:axis:)`,
    /// чтобы модель и сцена крутили в одну сторону.
    func turned(around axis: Vec3, by angle: Float) -> Vec3 {
        let k = axis.unit
        let c = cos(angle)
        let s = sin(angle)
        let along: Vec3 = k * (k.dotted(self) * (1 - c))
        let swing: Vec3 = k.crossed(self) * s
        return self * c + swing + along
    }
}

/// Сетка: точки, нормали и треугольники тройками номеров. Лицевая сторона —
/// та, откуда обход идёт против часовой стрелки.
struct Mesh3D: Equatable, Sendable {
    var positions: [Vec3] = []
    var normals: [Vec3] = []
    var indices: [UInt32] = []

    var isEmpty: Bool { indices.isEmpty }

    var top: Float { positions.map(\.y).max() ?? 0 }

    mutating func merge(_ other: Mesh3D) {
        let base = UInt32(positions.count)
        positions += other.positions
        normals += other.normals
        indices += other.indices.map { $0 + base }
    }

    func turned(around axis: Vec3, by angle: Float) -> Mesh3D {
        var out = self
        out.positions = positions.map { $0.turned(around: axis, by: angle) }
        out.normals = normals.map { $0.turned(around: axis, by: angle) }
        return out
    }

    func moved(by offset: Vec3) -> Mesh3D {
        var out = self
        out.positions = positions.map { $0 + offset }
        return out
    }

    /// Нормаль вершины — сумма нормалей граней вокруг неё, взвешенная
    /// площадью: большие грани важнее, вырожденные не весят ничего.
    mutating func smooth() {
        var sums = [Vec3](repeating: .zero, count: positions.count)
        for face in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[face])
            let b = Int(indices[face + 1])
            let c = Int(indices[face + 2])
            let normal = (positions[b] - positions[a])
                .crossed(positions[c] - positions[a])
            sums[a] += normal
            sums[b] += normal
            sums[c] += normal
        }
        normals = sums.map(\.unit)
    }

    /// С изнанкой: те же точки, нормали наружу с другой стороны и обратный
    /// обход. Лист видно с обеих сторон, а отсечение задних граней остаётся —
    /// с ним свет на изнанке честный.
    func twoSided() -> Mesh3D {
        var back = self
        back.normals = normals.map { -$0 }
        var flipped: [UInt32] = []
        flipped.reserveCapacity(indices.count)
        for face in stride(from: 0, to: indices.count, by: 3) {
            flipped.append(indices[face])
            flipped.append(indices[face + 2])
            flipped.append(indices[face + 1])
        }
        back.indices = flipped
        var both = self
        both.merge(back)
        return both
    }
}

/// Формы для объёмного сада. Здесь только арифметика, без RealityKit, —
/// чтобы формы проверялись без телефона. В сцену их переводит `Stage`.
enum Sculpt {
    /// Тело вращения: профиль — точки (радиус, высота) — обходит ось Y.
    /// Нормаль смотрит вправо от хода профиля: вверх по внешней стенке —
    /// наружу, вниз по внутренней — внутрь. Рёбра — как у кактуса: радиус
    /// гуляет по кругу.
    static func lathe(_ profile: [SIMD2<Float>], segments: Int,
                      ribs: Int = 0, ribDepth: Float = 0) -> Mesh3D {
        var mesh = Mesh3D()
        for point in profile {
            for step in 0 ..< segments {
                let angle = 2 * Float.pi * Float(step) / Float(segments)
                let rib = 1 + ribDepth * cos(Float(ribs) * angle)
                let radius = point.x * rib
                mesh.positions.append(Vec3(radius * cos(angle), point.y,
                                           radius * sin(angle)))
            }
        }
        for ring in 0 ..< max(profile.count - 1, 0) {
            for step in 0 ..< segments {
                let a = UInt32(ring * segments + step)
                let b = UInt32(ring * segments + (step + 1) % segments)
                let c = UInt32((ring + 1) * segments + step)
                let d = UInt32((ring + 1) * segments + (step + 1) % segments)
                mesh.indices += [a, c, b, b, c, d]
            }
        }
        mesh.smooth()
        return mesh
    }

    /// Трубка вдоль пути: стебель, носик лейки, ручка. Кольца несёт
    /// параллельный перенос — без него трубку перекручивало бы на изгибах.
    static func tube(_ path: [Vec3], sides: Int,
                     radius: (Float) -> Float) -> Mesh3D {
        guard path.count > 1 else { return Mesh3D() }
        var mesh = Mesh3D()
        let last = path.count - 1
        var tangent = (path[1] - path[0]).unit
        let helper = abs(tangent.y) < 0.9 ? Vec3(0, 1, 0) : Vec3(1, 0, 0)
        var side = tangent.crossed(helper).unit
        for (index, point) in path.enumerated() {
            let ahead = path[min(index + 1, last)]
            let behind = path[max(index - 1, 0)]
            let next = (ahead - behind).unit
            // Прежнюю боковую ось очищаем от нового хода — это и есть
            // параллельный перенос.
            side = (side - next * side.dotted(next)).unit
            tangent = next
            let other = tangent.crossed(side)
            let r = radius(Float(index) / Float(last))
            for step in 0 ..< sides {
                let angle = 2 * Float.pi * Float(step) / Float(sides)
                let normal = side * cos(angle) + other * sin(angle)
                mesh.positions.append(point + normal * r)
                mesh.normals.append(normal)
            }
        }
        for ring in 0 ..< last {
            for step in 0 ..< sides {
                let a = UInt32(ring * sides + step)
                let b = UInt32(ring * sides + (step + 1) % sides)
                let c = UInt32((ring + 1) * sides + step)
                let d = UInt32((ring + 1) * sides + (step + 1) % sides)
                mesh.indices += [a, b, c, b, d, c]
            }
        }
        return mesh
    }

    /// Очертание листа: ширина как доля от наибольшей по ходу от черешка
    /// (0) к кончику (1).
    enum Outline {
        case oval, blade, heart, petal

        func width(_ t: Float) -> Float {
            let t = min(max(t, 0), 1)
            switch self {
            case .oval: return pow(sin(Float.pi * t), 0.75)
            case .blade: return min(1, t * 7) * pow(1 - t, 0.55)
            case .heart: return sin(Float.pi * pow(t, 0.7))
            case .petal: return pow(sin(Float.pi * pow(t, 0.6)), 0.6)
            }
        }
    }

    /// Лист вдоль +X, черешок в начале координат, ширина — по Z. Изгиб
    /// опускает кончик, складка приподнимает края к жилке.
    static func leaf(length: Float, width: Float, arch: Float, fold: Float,
                     outline: Outline, steps: Int = 12) -> Mesh3D {
        let across: [Float] = [-1, -0.5, 0, 0.5, 1]
        var mesh = Mesh3D()
        for row in 0 ... steps {
            let t = Float(row) / Float(steps)
            let half = width / 2 * outline.width(t)
            for u in across {
                let rise = -arch * length * t * t + fold * abs(u) * half
                mesh.positions.append(Vec3(t * length, rise, u * half))
            }
        }
        let columns = across.count
        for row in 0 ..< steps {
            for column in 0 ..< columns - 1 {
                let a = UInt32(row * columns + column)
                let b = a + 1
                let c = UInt32((row + 1) * columns + column)
                let d = c + 1
                mesh.indices += [a, b, c, b, d, c]
            }
        }
        mesh.smooth()
        return mesh.twoSided()
    }

    /// Цветок, раскрытый вдоль +X: лепестки кругом, чашечка — насколько они
    /// сомкнуты (0 — плоский, к π/2 — бутон), и серединка.
    static func blossom(petals: Int, size: Float, cup: Float,
                        heart: Float) -> (petals: Mesh3D, heart: Mesh3D) {
        var ring = Mesh3D()
        let open = Float.pi / 2 - cup
        for index in 0 ..< petals {
            let petal = leaf(length: size, width: size * 0.62,
                             arch: -0.12, fold: 0.18, outline: .petal,
                             steps: 8)
                // Из плоскости головки вверх, к её оси.
                .turned(around: Vec3(0, 0, 1), by: open)
                .turned(around: Vec3(1, 0, 0),
                        by: 2 * Float.pi * Float(index) / Float(petals))
            ring.merge(petal)
        }
        let dome = lathe([SIMD2(heart, 0), SIMD2(heart * 0.8, heart * 0.5),
                          SIMD2(0, heart * 0.75)], segments: 12)
            .turned(around: Vec3(0, 0, 1), by: -Float.pi / 2)
        return (ring, dome)
    }

    /// Дуга кольца на полу, лицом вверх; `sweep` — доля круга от «двенадцати
    /// часов». Пустая при нуле — нечего рисовать.
    static func arc(inner: Float, outer: Float, sweep: Float,
                    segments: Int = 72, lift: Float = 0.002) -> Mesh3D {
        let share = min(max(sweep, 0), 1)
        let steps = max(Int((Float(segments) * share).rounded(.up)), 1)
        guard share > 0.001 else { return Mesh3D() }
        var mesh = Mesh3D()
        for step in 0 ... steps {
            let angle = -Float.pi / 2
                + 2 * Float.pi * share * Float(step) / Float(steps)
            for radius in [inner, outer] {
                mesh.positions.append(Vec3(radius * cos(angle), lift,
                                           radius * sin(angle)))
                mesh.normals.append(Vec3(0, 1, 0))
            }
        }
        for step in 0 ..< steps {
            let a = UInt32(step * 2)
            let b = a + 1
            let c = a + 2
            let d = a + 3
            mesh.indices += [a, c, b, b, c, d]
        }
        return mesh
    }
}
