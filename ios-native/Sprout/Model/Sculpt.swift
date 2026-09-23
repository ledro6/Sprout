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

/// Поза детали: размер, поворот вокруг своей оси, подъём, поворот вокруг
/// вертикали и место. Тот же порядок, что у шарнира в сцене.
struct Pose: Equatable, Sendable {
    var base = Vec3.zero
    var yaw: Float = 0
    var rise: Float = 0
    var roll: Float = 0
    var size: Float = 1

    static let x = Vec3(1, 0, 0)
    static let y = Vec3(0, 1, 0)
    static let z = Vec3(0, 0, 1)

    func turn(_ direction: Vec3, lean: Float = 0) -> Vec3 {
        direction.turned(around: Pose.x, by: roll)
            .turned(around: Pose.z, by: rise - lean)
            .turned(around: Pose.y, by: yaw)
    }

    func place(_ point: Vec3, lean: Float = 0) -> Vec3 {
        turn(point * size, lean: lean) + base
    }
}

/// Сетка: точки, нормали, координаты текстуры и треугольники тройками
/// номеров. Лицевая сторона — та, откуда обход идёт против часовой стрелки.
/// Текстура: u — поперёк, v — снизу вверх, как в USD.
struct Mesh3D: Equatable, Sendable {
    var positions: [Vec3] = []
    var normals: [Vec3] = []
    var uvs: [SIMD2<Float>] = []
    var indices: [UInt32] = []

    var isEmpty: Bool { indices.isEmpty }

    var triangles: Int { indices.count / 3 }

    var top: Float { positions.map(\.y).max() ?? 0 }

    mutating func merge(_ other: Mesh3D) {
        let base = UInt32(positions.count)
        positions += other.positions
        normals += other.normals
        uvs += other.uvs
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

    func posed(_ pose: Pose, lean: Float = 0) -> Mesh3D {
        var out = self
        out.positions = positions.map { pose.place($0, lean: lean) }
        out.normals = normals.map { pose.turn($0, lean: lean) }
        return out
    }

    /// Растянуть по осям; нормали — обратно растяжению, чтобы свет не врал.
    func stretched(_ factor: Vec3) -> Mesh3D {
        var out = self
        out.positions = positions.map { $0 * factor }
        out.normals = normals.map { ($0 / factor).unit }
        return out
    }

    /// Текстура сверху, как проекция на пол: для земли и камешков.
    func mappedFromAbove(radius: Float) -> Mesh3D {
        var out = self
        out.uvs = positions.map {
            SIMD2(0.5 + $0.x / (2 * radius), 0.5 + $0.z / (2 * radius))
        }
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

    /// Касательные вдоль u — для карты нормалей: по ним рельеф жилок знает,
    /// куда у текстуры право. Перпендикулярны нормали.
    func tangents() -> [Vec3] {
        var sums = [Vec3](repeating: .zero, count: positions.count)
        for face in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[face])
            let b = Int(indices[face + 1])
            let c = Int(indices[face + 2])
            let edge1 = positions[b] - positions[a]
            let edge2 = positions[c] - positions[a]
            let step1 = uvs[b] - uvs[a]
            let step2 = uvs[c] - uvs[a]
            let det = step1.x * step2.y - step2.x * step1.y
            guard abs(det) > 1e-12 else { continue }
            let along: Vec3 = (edge1 * step2.y - edge2 * step1.y) / det
            sums[a] += along
            sums[b] += along
            sums[c] += along
        }
        return zip(sums, normals).map { sum, normal in
            let flat = sum - normal * normal.dotted(sum)
            if flat.size > 1e-9 { return flat.unit }
            // Вырожденное — любая перпендикулярная.
            let helper = abs(normal.x) < 0.9 ? Pose.x : Pose.y
            return normal.crossed(helper).unit
        }
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

    /// Сетка из рядов по `columns` точек: соседние ряды — полосой
    /// треугольников. Общая для всех форм с сеткой.
    mutating func weave(rows: Int, columns: Int, flip: Bool = false) {
        for row in 0 ..< rows - 1 {
            for column in 0 ..< columns - 1 {
                let a = UInt32(row * columns + column)
                let b = a + 1
                let c = UInt32((row + 1) * columns + column)
                let d = c + 1
                indices += flip ? [a, b, c, b, d, c] : [a, c, b, b, c, d]
            }
        }
    }
}

/// Формы для объёмного сада. Здесь только арифметика, без RealityKit, —
/// чтобы формы проверялись без телефона. В сцену их переводит `Stage`.
enum Sculpt {
    /// Тело вращения: профиль — точки (радиус, высота) — обходит ось Y.
    /// Нормаль смотрит вправо от хода профиля: вверх по внешней стенке —
    /// наружу, вниз по внутренней — внутрь. Рёбра — как у кактуса: радиус
    /// гуляет по кругу. Шов текстуры — лишний столбец, а нормали на шве
    /// сведены: иначе по горшку шла бы складка.
    static func lathe(_ profile: [SIMD2<Float>], segments: Int,
                      ribs: Int = 0, ribDepth: Float = 0) -> Mesh3D {
        var mesh = Mesh3D()
        var lengths: [Float] = [0]
        for index in 1 ..< max(profile.count, 1) {
            let step = profile[index] - profile[index - 1]
            lengths.append(lengths[index - 1]
                + (step * step).sum().squareRoot())
        }
        let total = max(lengths.last ?? 1, 1e-6)
        let columns = segments + 1
        for (ring, point) in profile.enumerated() {
            for step in 0 ... segments {
                let angle = 2 * Float.pi * Float(step) / Float(segments)
                let rib = 1 + ribDepth * cos(Float(ribs) * angle)
                let radius = point.x * rib
                mesh.positions.append(Vec3(radius * cos(angle), point.y,
                                           radius * sin(angle)))
                mesh.uvs.append(SIMD2(Float(step) / Float(segments),
                                      lengths[ring] / total))
            }
        }
        mesh.weave(rows: profile.count, columns: columns)
        // Нормали — по сетке, сваренной на шве: иначе лишний столбец не
        // знал бы соседей с другой стороны, а центр донышка остался бы без
        // граней вовсе.
        var welded = mesh
        welded.indices = mesh.indices.map {
            Int($0) % columns == segments ? $0 - UInt32(segments) : $0
        }
        welded.smooth()
        mesh.normals = welded.normals
        for ring in 0 ..< profile.count {
            mesh.normals[ring * columns + segments] = mesh.normals[ring * columns]
        }
        return mesh
    }

    /// Трубка вдоль пути: стебель, черешок, ствол. Кольца несёт
    /// параллельный перенос — без него трубку перекручивало бы на изгибах.
    /// Текстура вдоль идёт в метрах, поделённых на `repeat`: кора не
    /// растягивается на длинном стволе.
    static func tube(_ path: [Vec3], sides: Int, repeat span: Float = 0.1,
                     radius: (Float) -> Float) -> Mesh3D {
        guard path.count > 1 else { return Mesh3D() }
        var mesh = Mesh3D()
        let last = path.count - 1
        var side = (path[1] - path[0]).unit.crossed(
            abs((path[1] - path[0]).unit.y) < 0.9 ? Pose.y : Pose.x).unit
        var travelled: Float = 0
        for (index, point) in path.enumerated() {
            let ahead = path[min(index + 1, last)]
            let behind = path[max(index - 1, 0)]
            let tangent = (ahead - behind).unit
            // Прежнюю боковую ось очищаем от нового хода — это и есть
            // параллельный перенос.
            side = (side - tangent * side.dotted(tangent)).unit
            let other = tangent.crossed(side)
            if index > 0 { travelled += (point - path[index - 1]).size }
            let r = radius(Float(index) / Float(last))
            for step in 0 ... sides {
                let angle = 2 * Float.pi * Float(step) / Float(sides)
                let normal = side * cos(angle) + other * sin(angle)
                mesh.positions.append(point + normal * r)
                mesh.normals.append(normal)
                mesh.uvs.append(SIMD2(Float(step) / Float(sides),
                                      travelled / span))
            }
        }
        mesh.weave(rows: path.count, columns: sides + 1, flip: true)
        return mesh
    }

    /// Изгиб листовой пластины. Всё — в долях: изгиб опускает кончик на
    /// долю длины, складка поднимает края к жилке, чаша — края вверх
    /// дугой, волна — рябь по краю, закрутка — поворот к кончику.
    struct Bend: Equatable, Sendable {
        var arch: Float = 0.2
        var fold: Float = 0.15
        var cup: Float = 0
        var wave: Float = 0
        var waves: Float = 5
        var twist: Float = 0
    }

    /// Лист-карточка вдоль +X, черешок в начале координат, ширина — по Z.
    /// Очертание рисует прозрачность текстуры, а сетка лишь облегает его с
    /// запасом: так край листа точный, а точек мало. `hug` — полуширина по
    /// длине в долях; нулевая — прямоугольник.
    static func card(length: Float, width: Float, bend: Bend,
                     rows: Int = 20, columns: Int = 9,
                     hug: ((Float) -> Float)? = nil) -> Mesh3D {
        var mesh = Mesh3D()
        for row in 0 ..< rows {
            let t = Float(row) / Float(rows - 1)
            let reach = min(1, (hug?(t) ?? 1) * 1.12 + 0.04)
            for column in 0 ..< columns {
                let s = (Float(column) / Float(columns - 1)) * 2 - 1
                let across = s * reach
                let z = across * width / 2
                let edge = abs(across)
                let ripple = bend.wave * width
                    * sin(t * bend.waves * 2 * .pi) * edge * edge
                let y = -bend.arch * length * t * t
                    + bend.fold * edge * width / 2
                    + bend.cup * edge * edge * width / 2 + ripple
                var point = Vec3(t * length, y, z)
                if bend.twist != 0 {
                    point = point.turned(around: Pose.x, by: bend.twist * t)
                }
                mesh.positions.append(point)
                mesh.uvs.append(SIMD2(0.5 + across / 2, t))
            }
        }
        mesh.weave(rows: rows, columns: columns, flip: true)
        mesh.smooth()
        return mesh.twoSided()
    }

    /// Мясистый лист: сечение — эллипс, от основания к острому кончику.
    /// Алоэ, эхеверия, толстянка. `shape` — полуширина по длине.
    static func fleshy(length: Float, width: Float, thickness: Float,
                       arch: Float, rows: Int = 16, sides: Int = 14,
                       shape: (Float) -> Float) -> Mesh3D {
        var mesh = Mesh3D()
        for row in 0 ..< rows {
            let t = Float(row) / Float(rows - 1)
            let half = width / 2 * shape(t)
            let deep = thickness / 2 * pow(shape(t), 0.8)
            let lift = -arch * length * t * t
            for step in 0 ... sides {
                let angle = 2 * Float.pi * Float(step) / Float(sides)
                // Сверху площе: сечение как у настоящего листа алоэ.
                let upper = sin(angle) > 0 ? 0.55 : 1
                mesh.positions.append(Vec3(
                    t * length, lift + sin(angle) * deep * Float(upper),
                    cos(angle) * half))
                mesh.uvs.append(SIMD2(Float(step) / Float(sides), t))
            }
        }
        mesh.weave(rows: rows, columns: sides + 1)
        mesh.smooth()
        return mesh
    }

    /// Шар или эллипсоид — бутон, камешек, серединка.
    static func ball(radius: Float, segments: Int = 12,
                     rings: Int = 8) -> Mesh3D {
        let profile = (0 ... rings).map { ring -> SIMD2<Float> in
            let angle = Float.pi * (Float(ring) / Float(rings) - 0.5)
            return SIMD2(radius * cos(angle), radius * sin(angle))
        }
        return lathe(profile, segments: segments)
    }

    /// Конус вдоль +Y — колючка, зубец, шип.
    static func spike(radius: Float, height: Float, sides: Int = 5) -> Mesh3D {
        lathe([SIMD2(0, 0), SIMD2(radius, 0), SIMD2(0, height)],
              segments: sides)
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
            for (index, radius) in [inner, outer].enumerated() {
                mesh.positions.append(Vec3(radius * cos(angle), lift,
                                           radius * sin(angle)))
                mesh.normals.append(Vec3(0, 1, 0))
                mesh.uvs.append(SIMD2(Float(index),
                                      Float(step) / Float(steps)))
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

    /// Квадратичная кривая Безье — стебель или черешок с одним изгибом.
    static func curve(_ a: Vec3, _ b: Vec3, _ c: Vec3,
                      steps: Int = 10) -> [Vec3] {
        (0 ... steps).map { step in
            let t = Float(step) / Float(steps)
            let first: Vec3 = a * ((1 - t) * (1 - t))
            let middle: Vec3 = b * (2 * (1 - t) * t)
            let last: Vec3 = c * (t * t)
            return first + middle + last
        }
    }
}
