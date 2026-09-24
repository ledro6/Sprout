import Foundation

/// Материал детали: текстуры и то, как поверхность держит свет.
struct Look: Equatable, Sendable {
    /// Номер картинки цвета; нет — чистый `tint`.
    var color: Int? = nil
    /// Номер карты нормалей: рельеф жилок под светом.
    var normal: Int? = nil
    var tint = Channels(255, 255, 255)
    var rough: Float = 0.6
    /// Лак поверх — глянцевые листья фикуса, глазурь горшка.
    var gloss: Float = 0
    /// Прозрачность картинки вырезает контур — край листа, окошки монстеры.
    var cutout = false
    /// Меньше единицы — полупрозрачное: пластиковый горшок орхидеи.
    var opacity: Float = 1
    /// Желтеет к сухой земле.
    var wilts = false
    /// Темнеет от воды — земля.
    var wets = false
}

/// Деталь на месте: какая сетка, какой материал, поза и то, как она живёт.
/// Никнущие и качающиеся детали сцена двигает каждый кадр, прочие стоят.
struct Piece: Equatable, Sendable {
    var mesh: Int
    var look: Int
    var pose = Pose()
    /// Насколько опускается у сухой земли, радианы.
    var sag: Float = 0
    /// Размах покачивания, радианы.
    var sway: Float = 0
    /// 0…1 — очередь при появлении.
    var delay: Float = 0
    /// 0…1 — чтобы детали качались не в такт.
    var phase: Float = 0

    var lives: Bool { sag > 0 || sway > 0 }
}

/// Готовая модель растения: неповторимые сетки, картинки, материалы и
/// раскладка. Листья одного вида делят одну сетку и одну картинку — так
/// модель лёгкая и в памяти, и в файле, а детальная на экране.
struct Kit: Equatable, Sendable {
    /// Меняется вместе с тем, как растут модели: старые файлы тогда
    /// собираются заново.
    static let version: UInt32 = 2

    var meshes: [Mesh3D] = []
    var pictures: [Picture] = []
    var looks: [Look] = []
    var pieces: [Piece] = []
    var height: Float = 0
    var spread: Float = 0

    mutating func add(_ mesh: Mesh3D) -> Int {
        meshes.append(mesh)
        return meshes.count - 1
    }

    mutating func add(_ picture: Picture) -> Int {
        pictures.append(picture)
        return pictures.count - 1
    }

    mutating func add(_ look: Look) -> Int {
        looks.append(look)
        return looks.count - 1
    }

    mutating func place(_ mesh: Int, _ look: Int, _ pose: Pose = Pose(),
                        sag: Float = 0, sway: Float = 0, delay: Float = 0,
                        phase: Float = 0) {
        pieces.append(Piece(mesh: mesh, look: look, pose: pose, sag: sag,
                            sway: sway, delay: delay, phase: phase))
    }

    /// Сетка и сразу деталь из неё.
    mutating func put(_ mesh: Mesh3D, _ look: Int, _ pose: Pose = Pose(),
                      sag: Float = 0, sway: Float = 0, delay: Float = 0,
                      phase: Float = 0) {
        let index = add(mesh)
        place(index, look, pose, sag: sag, sway: sway, delay: delay,
              phase: phase)
    }

    var triangles: Int {
        pieces.reduce(0) { $0 + meshes[$1.mesh].triangles }
    }

    /// Высота и размах по всем деталям на своих местах.
    mutating func measure() {
        var top: Float = Greenhouse.rim
        var wide: Float = Greenhouse.potRadius
        for piece in pieces {
            for point in meshes[piece.mesh].positions {
                let placed = piece.pose.place(point)
                top = max(top, placed.y)
                wide = max(wide, (placed.x * placed.x + placed.z * placed.z)
                    .squareRoot())
            }
        }
        height = top
        spread = wide
    }

    // MARK: - Файл

    private static let magic: UInt32 = 0x5350_4B54

    /// Двоичный слепок: числа подряд, младшим байтом вперёд. Сжимает его
    /// уже приложение — на Linux сжатия в Foundation нет.
    func encoded() -> Data {
        var tape = Tape()
        tape.put(Kit.magic)
        tape.put(Kit.version)
        tape.put(height)
        tape.put(spread)
        tape.put(UInt32(meshes.count))
        for mesh in meshes {
            tape.put(UInt32(mesh.positions.count))
            tape.put(UInt32(mesh.indices.count))
            tape.put(mesh.positions.flatMap { [$0.x, $0.y, $0.z] })
            tape.put(mesh.normals.flatMap { [$0.x, $0.y, $0.z] })
            tape.put(mesh.uvs.flatMap { [$0.x, $0.y] })
            tape.put(mesh.indices)
        }
        tape.put(UInt32(pictures.count))
        for picture in pictures {
            tape.put(UInt32(picture.width))
            tape.put(UInt32(picture.height))
            tape.data.append(contentsOf: picture.pixels)
        }
        tape.put(UInt32(looks.count))
        for look in looks {
            tape.put(Int32(look.color ?? -1))
            tape.put(Int32(look.normal ?? -1))
            tape.put([Float(look.tint.red), Float(look.tint.green),
                      Float(look.tint.blue), look.rough, look.gloss,
                      look.opacity])
            tape.put(UInt32((look.cutout ? 1 : 0) | (look.wilts ? 2 : 0)
                | (look.wets ? 4 : 0)))
        }
        tape.put(UInt32(pieces.count))
        for piece in pieces {
            tape.put(UInt32(piece.mesh))
            tape.put(UInt32(piece.look))
            let pose = piece.pose
            tape.put([pose.base.x, pose.base.y, pose.base.z, pose.yaw,
                      pose.rise, pose.roll, pose.size, piece.sag, piece.sway,
                      piece.delay, piece.phase])
        }
        return tape.data
    }

    /// Чужой или старый файл — нет модели, а не падение: её соберут заново.
    init?(_ data: Data) {
        var tape = Tape(data)
        guard tape.word() == Kit.magic, tape.word() == Kit.version,
              let height = tape.number(), let spread = tape.number(),
              let meshCount = tape.word()
        else { return nil }
        self.height = height
        self.spread = spread
        for _ in 0 ..< meshCount {
            guard let points = tape.word(), let count = tape.word(),
                  let positions = tape.numbers(Int(points) * 3),
                  let normals = tape.numbers(Int(points) * 3),
                  let uvs = tape.numbers(Int(points) * 2),
                  let indices = tape.words(Int(count))
            else { return nil }
            var mesh = Mesh3D()
            mesh.positions = stride(from: 0, to: positions.count, by: 3).map {
                Vec3(positions[$0], positions[$0 + 1], positions[$0 + 2])
            }
            mesh.normals = stride(from: 0, to: normals.count, by: 3).map {
                Vec3(normals[$0], normals[$0 + 1], normals[$0 + 2])
            }
            mesh.uvs = stride(from: 0, to: uvs.count, by: 2).map {
                SIMD2(uvs[$0], uvs[$0 + 1])
            }
            mesh.indices = indices
            guard indices.allSatisfy({ Int($0) < mesh.positions.count })
            else { return nil }
            meshes.append(mesh)
        }
        guard let pictureCount = tape.word() else { return nil }
        for _ in 0 ..< pictureCount {
            guard let width = tape.word(), let height = tape.word(),
                  let pixels = tape.bytes(Int(width) * Int(height) * 4)
            else { return nil }
            pictures.append(Picture(width: Int(width), height: Int(height),
                                    pixels: pixels))
        }
        guard let lookCount = tape.word() else { return nil }
        for _ in 0 ..< lookCount {
            guard let color = tape.signed(), let normal = tape.signed(),
                  let values = tape.numbers(6), let flags = tape.word()
            else { return nil }
            looks.append(Look(
                color: color < 0 ? nil : Int(color),
                normal: normal < 0 ? nil : Int(normal),
                tint: Channels(Double(values[0]), Double(values[1]),
                               Double(values[2])),
                rough: values[3], gloss: values[4], cutout: flags & 1 != 0,
                opacity: values[5], wilts: flags & 2 != 0,
                wets: flags & 4 != 0))
        }
        guard let pieceCount = tape.word() else { return nil }
        for _ in 0 ..< pieceCount {
            guard let mesh = tape.word(), let look = tape.word(),
                  let values = tape.numbers(11),
                  Int(mesh) < meshes.count, Int(look) < looks.count
            else { return nil }
            pieces.append(Piece(
                mesh: Int(mesh), look: Int(look),
                pose: Pose(base: Vec3(values[0], values[1], values[2]),
                           yaw: values[3], rise: values[4], roll: values[5],
                           size: values[6]),
                sag: values[7], sway: values[8], delay: values[9],
                phase: values[10]))
        }
    }

    init() {}
}

/// Лента для двоичного слепка.
private struct Tape {
    var data = Data()
    var offset = 0

    init() {}

    init(_ data: Data) {
        self.data = data
    }

    mutating func put(_ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    mutating func put(_ value: Int32) { put(UInt32(bitPattern: value)) }

    mutating func put(_ value: Float) { put(value.bitPattern) }

    mutating func put(_ values: [Float]) {
        for value in values { put(value.bitPattern) }
    }

    mutating func put(_ values: [UInt32]) {
        for value in values { put(value) }
    }

    mutating func word() -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        var value: UInt32 = 0
        for shift in 0 ..< 4 {
            value |= UInt32(data[data.startIndex + offset + shift]) << (8 * shift)
        }
        offset += 4
        return value
    }

    mutating func signed() -> Int32? { word().map { Int32(bitPattern: $0) } }

    mutating func number() -> Float? { word().map { Float(bitPattern: $0) } }

    mutating func numbers(_ count: Int) -> [Float]? {
        guard offset + count * 4 <= data.count else { return nil }
        var out: [Float] = []
        out.reserveCapacity(count)
        for _ in 0 ..< count { out.append(number()!) }
        return out
    }

    mutating func words(_ count: Int) -> [UInt32]? {
        guard offset + count * 4 <= data.count else { return nil }
        var out: [UInt32] = []
        out.reserveCapacity(count)
        for _ in 0 ..< count { out.append(word()!) }
        return out
    }

    mutating func bytes(_ count: Int) -> [UInt8]? {
        guard offset + count <= data.count else { return nil }
        let start = data.startIndex + offset
        offset += count
        return [UInt8](data[start ..< start + count])
    }
}

/// Случайность от строки: `hashValue` в Swift от запуска к запуску разный, а
/// растение должно выглядеть одинаково.
struct Seeded: RandomNumberGenerator {
    private var state: UInt64

    init(_ text: String) {
        state = Seeded.hash(text)
    }

    init(number: UInt64) {
        state = number
    }

    static func hash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return hash
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}

/// Что взято со снимка: цвета листьев, цветов и горшка, пестрота, густота
/// и вытянутость. Нет снимка или он мыльный — модель берётся готовая.
struct Traits: Codable, Hashable, Sendable {
    var leaf: Channels
    var variegation: Channels?
    var flower: Channels?
    var pot: Channels?
    /// Во сколько раз гуще листва, чем у готовой модели: 0.75…1.35.
    var density: Double
    /// Во сколько раз выше: 0.8…1.3.
    var stretch: Double
}

/// Чертёж модели: вид, снятые со снимка черты и зерно. Лежит в растении и
/// весит байты; модель по нему собирается заново одинаковой.
struct Blueprint: Codable, Hashable, Sendable {
    var preset: Preset
    var traits: Traits?
    var seed: String

    /// Одна из двадцати готовых — для вида, без снимка.
    static func stock(_ species: String) -> Blueprint {
        stock(Preset.of(species))
    }

    static func stock(_ preset: Preset) -> Blueprint {
        Blueprint(preset: preset, traits: nil, seed: preset.rawValue)
    }

    /// Подпись для экрана: откуда модель.
    var source: String {
        traits == nil ? "Готовая модель: \(preset.title.lowercased())"
            : "Модель по снимку: \(preset.title.lowercased())"
    }

    /// Имя файла модели: меняется с чертежом и с версией сборки.
    var fingerprint: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(self)) ?? Data()
        let hash = Seeded.hash(String(decoding: data, as: UTF8.self)
            + "\(Kit.version)")
        return String(hash, radix: 16)
    }
}
