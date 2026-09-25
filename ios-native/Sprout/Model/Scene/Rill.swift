import Foundation

/// Струя лейки как геометрия. Струйки сеточки летят порциями по баллистике
/// (`Droplet`), и из порций каждый кадр строится сетка: трубки струек, а где
/// струйка порвалась — капли через одну, вытянутые вдоль полёта. Здесь
/// только арифметика — воду из сетки делает сцена (Views/Water.swift).
struct Rill {
    /// Порция воды в полёте. Номер — чтобы капли не мигали: какая порция
    /// станет каплей, решает он, а не место в очереди.
    struct Parcel: Sendable {
        var drop: Droplet
        var serial: Int
    }

    /// Точка сетки в том виде, в каком её читает видеокарта: касательная —
    /// для ряби на поверхности, v развёртки — возраст воды в полёте, чтобы
    /// рябь бежала вместе с водой.
    struct Vertex: Sendable {
        var position: SIMD3<Float> = .zero
        var normal: SIMD3<Float> = .zero
        var tangent: SIMD3<Float> = .zero
        var uv: SIMD2<Float> = .zero
    }

    /// Порций в струйке — с запасом на самое высокое растение.
    static let cap = 96
    static let sides = 8
    /// Толщина средней струйки у лейки размера один.
    static let thickness: Float = 0.0017
    /// Капля — эллипсоид из стольких колец и долек.
    static let beadRings = 4
    static let beadSegments = 6

    let jets: [Pouring.Jet]
    /// Порции каждой струйки — от новой, у сеточки, к старой, у земли.
    private(set) var flows: [[Parcel]]
    /// Когда струйка рвётся на капли — секунды полёта.
    private var breaks: [Float]
    private var serial = 0
    private var owed: Double = 0
    private var pace: Float = 0
    private var scale: Float = 1
    /// Льёт ли лейка сейчас: нет — у сеточки струйки тоже скруглены.
    private(set) var pouring = false

    init(jets count: Int) {
        jets = Pouring.jets(count)
        flows = Array(repeating: [], count: jets.count)
        breaks = Array(repeating: 1, count: jets.count)
    }

    var idle: Bool { flows.allSatisfy(\.isEmpty) }

    /// Сетке сколько места нужно самое большее: трубка в каждой порции и
    /// капля в каждой второй.
    var room: (vertices: Int, indices: Int) {
        let flows = max(jets.count, 1)
        let bead = (Self.beadRings + 1) * (Self.beadSegments + 1)
        return (vertices: flows * (Self.cap * (Self.sides + 1)
                                   + Self.cap / 2 * bead),
                indices: flows * (Self.cap * Self.sides * 6
                                  + Self.cap / 2 * Self.beadRings
                                      * Self.beadSegments * 6))
    }

    /// Новый полив: струйки рвутся на капли на своей доле полёта `flight`.
    mutating func begin(scale: Float, flight: Float) {
        self.scale = scale
        flows = Array(repeating: [], count: jets.count)
        breaks = jets.map { max($0.breaks * flight, 0.03) }
        owed = 0
        pouring = false
    }

    /// Сколько летит вода от кончика носика до земли в полный наклон.
    static func flight(scale: Float, clearance: Float) -> Float {
        var drop = Droplet(position: .zero, velocity: {
            let launch = Pouring.launch(scale: scale)
            return Vec3(launch.x, launch.y, 0)
        }())
        while drop.position.y > -clearance * scale && drop.age < 3 {
            drop.fall(1 / 240)
        }
        return drop.age
    }

    /// Лить весь кадр: сеточка в `mouth`, вода вылетает со скоростью `jet`;
    /// `side` — поперёк носика по горизонтали. Порции, вылетевшие посреди
    /// кадра, догоняют своё место — струя ровная и при редких кадрах.
    mutating func pour(from mouth: Vec3, jet: Vec3, side: Vec3, dt: Double) {
        pouring = true
        pace = jet.size
        guard pace > 0 else { return }
        let heading = jet / pace
        let up = heading.crossed(side).unit
        owed += Pouring.rate * dt
        while owed >= 1 {
            owed -= 1
            let late = Float(owed / Pouring.rate)
            serial += 1
            for (index, spec) in jets.enumerated() {
                let hole: Vec3 = (side * spec.hole.x + up * spec.hole.y)
                    * (Pouring.rose * scale)
                let lean: Vec3 = (side * spec.lean.x + up * spec.lean.y) * pace
                var drop = Droplet(position: mouth + hole, velocity: jet + lean)
                drop.fall(late)
                flows[index].insert(Parcel(drop: drop, serial: serial), at: 0)
                if flows[index].count > Self.cap { flows[index].removeLast() }
            }
        }
    }

    /// Лейка выпрямилась: новых порций нет, хвост струи отрывается.
    mutating func stop() { pouring = false }

    mutating func clear() {
        flows = Array(repeating: [], count: jets.count)
        pouring = false
    }

    /// Полёт за кадр. Порции, упавшие в горшок, — вода: ответ — где в
    /// среднем они коснулись земли; мимо горшка — пропадают на полу.
    mutating func fly(_ dt: Float, ground: Float, center: Vec3, mouth: Float,
                      floor: Float) -> Vec3? {
        var landed = Vec3.zero
        var count = 0
        for index in flows.indices {
            var kept: [Parcel] = []
            kept.reserveCapacity(flows[index].count)
            for var parcel in flows[index] {
                parcel.drop.fall(dt)
                let point = parcel.drop.position
                var off = point - center
                off.y = 0
                if point.y <= ground, off.size <= mouth {
                    landed += Vec3(point.x, ground, point.z)
                    count += 1
                    continue
                }
                if point.y < floor || parcel.drop.age > 3 { continue }
                kept.append(parcel)
            }
            flows[index] = kept
        }
        return count > 0 ? landed / Float(count) : nil
    }

    // MARK: - Сетка

    /// Сетка воды из порций: трубки, пока струйка цела, дальше — капли
    /// через одну. Лицевая сторона — снаружи.
    func geometry() -> (vertices: [Vertex], indices: [UInt32]) {
        var vertices: [Vertex] = []
        var indices: [UInt32] = []
        vertices.reserveCapacity(4_096)
        indices.reserveCapacity(16_384)
        for (index, flow) in flows.enumerated() where !flow.isEmpty {
            let width = Self.thickness * jets[index].width * scale
            let whole = flow.prefix(while: { $0.drop.age < breaks[index] })
            tube(Array(whole), width: width, into: &vertices, &indices)
            for parcel in flow.dropFirst(whole.count)
                where parcel.serial.isMultiple(of: 2) {
                bead(parcel, width: width, into: &vertices, &indices)
            }
        }
        return (vertices, indices)
    }

    /// Трубка через порции: кольца несёт параллельный перенос, как у
    /// стеблей, — без него струю перекручивало бы там, где она падает
    /// отвесно. Толще у сеточки, тоньше там, где вода разогналась: сколько
    /// воды — столько и течёт. Концы скруглены.
    private func tube(_ parcels: [Parcel], width: Float,
                      into vertices: inout [Vertex],
                      _ indices: inout [UInt32]) {
        guard parcels.count > 1 else { return }
        let sides = Self.sides
        let first = UInt32(vertices.count)
        var side = Vec3.zero
        for (ring, parcel) in parcels.enumerated() {
            let drop = parcel.drop
            let speed = max(drop.velocity.size, 1e-4)
            let along = drop.velocity / speed
            if ring == 0 {
                side = along.crossed(abs(along.y) < 0.9 ? Pose.y : Pose.x)
            }
            side = (side - along * side.dotted(along)).unit
            let other = along.crossed(side)
            let thin = min(max((max(pace, 1e-4) / speed).squareRoot(), 0.4),
                           1.2)
            let end: Float = ring == parcels.count - 1 ? 0.55
                : ring == 0 && !pouring ? 0.5 : 1
            let radius = width * thin * end
            for step in 0 ... sides {
                let angle = 2 * Float.pi * Float(step) / Float(sides)
                let normal = side * cos(angle) + other * sin(angle)
                vertices.append(Vertex(
                    position: drop.position + normal * radius, normal: normal,
                    tangent: along,
                    uv: SIMD2(Float(step) / Float(sides), drop.age)))
            }
        }
        let columns = UInt32(sides + 1)
        for ring in 0 ..< UInt32(parcels.count - 1) {
            for step in 0 ..< UInt32(sides) {
                let a = first + ring * columns + step
                let c = a + columns
                indices += [a, a + 1, c, a + 1, c + 1, c]
            }
        }
    }

    /// Капля: эллипсоид, вытянутый вдоль полёта, размер — от номера порции.
    private func bead(_ parcel: Parcel, width: Float,
                      into vertices: inout [Vertex],
                      _ indices: inout [UInt32]) {
        let drop = parcel.drop
        let speed = max(drop.velocity.size, 1e-4)
        let along = drop.velocity / speed
        let side = along.crossed(abs(along.y) < 0.9 ? Pose.y : Pose.x).unit
        let other = along.crossed(side)
        let size = width * (1.1 + 0.35 * Float((parcel.serial * 37) % 11) / 10)
        let stretch = 1 + min(speed * 0.9, 1.6)
        let first = UInt32(vertices.count)
        let rings = Self.beadRings
        let segments = Self.beadSegments
        for ring in 0 ... rings {
            let lat = Float.pi * (Float(ring) / Float(rings) - 0.5)
            for step in 0 ... segments {
                let lon = 2 * Float.pi * Float(step) / Float(segments)
                let across = side * cos(lon) + other * sin(lon)
                let normal = (across * cos(lat) + along * sin(lat)).unit
                let point = drop.position + across * (cos(lat) * size)
                    + along * (sin(lat) * size * stretch)
                vertices.append(Vertex(
                    position: point, normal: normal, tangent: along,
                    uv: SIMD2(Float(step) / Float(segments), drop.age)))
            }
        }
        let columns = UInt32(segments + 1)
        for ring in 0 ..< UInt32(rings) {
            for step in 0 ..< UInt32(segments) {
                let a = first + ring * columns + step
                let c = a + columns
                indices += [a, a + 1, c, a + 1, c + 1, c]
            }
        }
    }
}
