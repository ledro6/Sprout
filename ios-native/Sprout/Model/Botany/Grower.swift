import Foundation

/// Сборщик: набор, случайность от зерна, черты со снимка и общие части.
struct Grower {
    var kit = Kit()
    var rng: Seeded
    let preset: Preset
    let traits: Traits?
    let seed: UInt32
    let species: String
    let detail: Rig.Detail

    static let soil = Greenhouse.soil

    init(_ blueprint: Blueprint, species: String,
         detail: Rig.Detail = .standard) {
        rng = Seeded(blueprint.seed + blueprint.preset.rawValue)
        preset = blueprint.preset
        traits = blueprint.traits
        seed = UInt32(truncatingIfNeeded: Seeded.hash(blueprint.seed))
        self.species = species.lowercased()
        self.detail = detail
    }

    /// Свой вид — или, в чертежах прежних сборок, вписанное название: тогда
    /// роза росла внутри пеларгонии, хойя — внутри плюща.
    func grows(_ kind: Preset, named stem: String) -> Bool {
        preset == kind || species.contains(stem)
    }

    /// Высота рисунка с поправкой на силу телефона — кратно восьми, как
    /// любит видеопамять.
    func sharp(_ height: Int) -> Int {
        let scaled = Int((Float(height) * detail.texture / 8).rounded()) * 8
        return min(max(scaled, 64), 2048)
    }

    /// Число рядов сетки с поправкой на силу телефона.
    func dense(_ count: Int) -> Int {
        max(3, Int((Float(count) * detail.mesh).rounded()))
    }

    // MARK: - Случай и черты

    mutating func random(_ range: ClosedRange<Float>) -> Float {
        Float.random(in: range, using: &rng)
    }

    mutating func chance(_ share: Float) -> Bool { random(0 ... 1) < share }

    /// Сколько листьев: из диапазона вида, умноженного на густоту снимка.
    mutating func count(_ range: ClosedRange<Int>) -> Int {
        let base = Int.random(in: range, using: &rng)
        return max(1, Int((Float(base) * density).rounded()))
    }

    var density: Float { Float(traits?.density ?? 1) }
    var stretch: Float { Float(traits?.stretch ?? 1) }

    /// Цвет листа со снимка сдвигает цвет вида, а не заменяет: иначе серый
    /// свет пасмурной комнаты вырастил бы серое растение.
    func green(_ own: Channels) -> Channels {
        guard let leaf = traits?.leaf else { return own }
        return .mix(own, leaf, 0.7)
    }

    func bloom(_ own: Channels) -> Channels { traits?.flower ?? own }

    func lighter(_ color: Channels, _ share: Double = 0.25) -> Channels {
        .mix(color, Channels(255, 255, 240), share)
    }

    func darker(_ color: Channels, _ share: Double = 0.3) -> Channels {
        .mix(color, Channels(0, 0, 0), share)
    }

    static func around(_ point: Vec3, _ yaw: Float) -> Vec3 {
        point.turned(around: Pose.y, by: yaw)
    }

    // MARK: - Материалы

    mutating func leafLook(_ design: LeafLook, rough: Float, gloss: Float = 0,
                           height: Int = 512, wilts: Bool = true) -> Int {
        let art = Leafart.leaf(design, seed: seed &+ UInt32(kit.pictures.count),
                               height: sharp(height))
        let color = kit.add(art.color)
        let normal = kit.add(art.normal)
        return kit.add(Look(color: color, normal: normal, rough: rough,
                            gloss: gloss, cutout: true, wilts: wilts))
    }

    mutating func pictureLook(_ picture: Picture, rough: Float,
                              gloss: Float = 0, wilts: Bool = false,
                              wets: Bool = false) -> Int {
        let color = kit.add(picture)
        return kit.add(Look(color: color, rough: rough, gloss: gloss,
                            wilts: wilts, wets: wets))
    }

    mutating func plainLook(_ tint: Channels, rough: Float, gloss: Float = 0,
                            wilts: Bool = false) -> Int {
        kit.add(Look(tint: tint, rough: rough, gloss: gloss, wilts: wilts))
    }

    // MARK: - Сетки

    /// Лист-карточка: сетка облегает контур рисунка, у лопастных черешок
    /// приходится в выемку.
    mutating func leafMesh(_ design: LeafLook, length: Float,
                           bend: Sculpt.Bend, rows: Int = 24,
                           columns: Int = 11) -> Int {
        var mesh = Sculpt.card(length: length, width: length * design.aspect,
                               bend: bend, rows: dense(rows),
                               columns: dense(columns),
                               hug: { Leafart.half(design.outline, $0) })
        if Leafart.lobed(design.outline) {
            mesh = mesh.moved(by: Vec3(-Leafart.notch * length, 0, 0))
        }
        return kit.add(mesh)
    }

    /// Стебли одной сеткой: они не никнут, а сеток меньше — сцене легче.
    mutating func stems(_ paths: [[Vec3]], look: Int, sides: Int = 7,
                        radius: @escaping (Float) -> Float) {
        var mesh = Mesh3D()
        for path in paths {
            mesh.merge(Sculpt.tube(path, sides: dense(sides), radius: radius))
        }
        guard !mesh.isEmpty else { return }
        kit.put(mesh, look)
    }

    /// Точка на стебле: у трубки текстура липнет к картинке листа, поэтому
    /// её координаты сводятся в непрозрачную середину.
    static func opaque(_ mesh: Mesh3D) -> Mesh3D {
        var out = mesh
        out.uvs = mesh.uvs.map { _ in SIMD2(0.5, 0.5) }
        return out
    }

    // MARK: - Цветы

    /// Деталь цветка: сетка и её материал. Цветок — несколько деталей в
    /// одной позе.
    struct Part {
        var mesh: Int
        var look: Int
    }

    typealias Head = [Part]

    /// Лепесток не вянет: у цветка своя жизнь, и жухлый лепесток на свежем
    /// растении читался бы поломкой.
    mutating func petalLook(_ design: LeafLook, rough: Float = 0.5,
                            gloss: Float = 0) -> Int {
        leafLook(design, rough: rough, gloss: gloss, height: 256, wilts: false)
    }

    /// Круг лепестков. Цветок смотрит вдоль +X; `open` — угол лепестка от
    /// оси: ноль — сомкнут вперёд, π/2 — раскрыт плашмя. `turns` — где по
    /// кругу стоит каждый лепесток (ноль — вверх), `sizes` — во сколько раз
    /// он длиннее. Сдвиг вдоль оси разводит круги: иначе они мерцали бы
    /// друг в друге. `root` — на каком расстоянии от оси лепесток растёт:
    /// у розы лепестки сидят по краю донца, а не в одной точке.
    func whorl(_ design: LeafLook, length: Float, open: Float,
               bend: Sculpt.Bend, turns: [Float],
               sizes: [Float]? = nil, shift: Float = 0,
               root: Float = 0, rows: Int = 12,
               columns: Int = 9) -> Mesh3D {
        let rows = dense(rows)
        let columns = dense(columns)
        var ring = Mesh3D()
        for (index, turn) in turns.enumerated() {
            let size = sizes?[index % max(sizes?.count ?? 1, 1)] ?? 1
            let card = Sculpt.card(length: length * size,
                                   width: length * size * design.aspect,
                                   bend: bend, rows: rows, columns: columns,
                                   hug: { Leafart.half(design.outline, $0) })
                .turned(around: Pose.z, by: open)
                .moved(by: Vec3(0, root, 0))
                .turned(around: Pose.x, by: turn)
                .moved(by: Vec3(shift, 0, 0))
            ring.merge(card)
        }
        return ring
    }

    /// Ровно по кругу, со сдвигом на долю шага.
    static func evenly(_ count: Int, offset: Float = 0) -> [Float] {
        (0 ..< count).map { 2 * Float.pi * (Float($0) + offset) / Float(count) }
    }

    /// Тычинки: нити из середины вперёд и в стороны, на концах — пыльники.
    mutating func stamens(_ count: Int, length: Float, spread: Float,
                          anther: Float, thread: Channels,
                          pollen: Channels) -> Head {
        var threads = Mesh3D()
        var heads = Mesh3D()
        for index in 0 ..< count {
            let turn = 2 * Float.pi * Float(index) / Float(count)
                + random(-0.2 ... 0.2)
            let reach = length * random(0.8 ... 1.1)
            let out = spread * random(0.7 ... 1.1)
            let tip = Vec3(reach, out * cos(turn), out * sin(turn))
            let path = Sculpt.curve(Vec3(0, 0, 0),
                                    Vec3(reach * 0.6, tip.y * 0.3, tip.z * 0.3),
                                    tip, steps: 5)
            threads.merge(Sculpt.tube(path, sides: 4) { _ in anther * 0.28 })
            heads.merge(Sculpt.ball(radius: anther, segments: 6, rings: 4)
                .stretched(Vec3(0.8, 1, 1.25)).moved(by: tip))
        }
        let threadLook = plainLook(thread, rough: 0.6)
        let pollenLook = plainLook(pollen, rough: 0.85)
        return [Part(mesh: kit.add(Grower.opaque(threads)), look: threadLook),
                Part(mesh: kit.add(heads), look: pollenLook)]
    }

    /// Чашелистики — зелёная звёздочка под венчиком, отогнутая назад.
    mutating func sepals(_ count: Int, length: Float, color: Channels,
                         open: Float = 1.9) -> Part {
        let design = LeafLook(outline: .lanceolate, aspect: 0.4,
                              veins: .none, base: color,
                              tip: lighter(color, 0.15), mottle: 0.1)
        let look = leafLook(design, rough: 0.6, height: 128, wilts: false)
        let mesh = whorl(design, length: length, open: open,
                                bend: Sculpt.Bend(arch: 0.2, fold: 0.1),
                                turns: Grower.evenly(count, offset: 0.5),
                                shift: -0.001, rows: 6, columns: 5)
        return Part(mesh: kit.add(mesh), look: look)
    }

    /// Серединка: бугорок своего цвета.
    mutating func dome(_ radius: Float, color: Channels,
                       squash: Float = 0.6) -> Part {
        let mesh = Sculpt.ball(radius: radius, segments: 10, rings: 6)
            .stretched(Vec3(squash, 1, 1))
        return Part(mesh: kit.add(mesh), look: plainLook(color, rough: 0.8))
    }

    /// Простой цветок: круг лепестков, тычинки и серединка. Для мелких
    /// соцветий, где рисунок лепестка важнее устройства цветка.
    mutating func flower(_ petal: LeafLook, petals: Int, size: Float,
                         open: Float, bend: Sculpt.Bend,
                         heart: Channels?, stamens count: Int = 0,
                         pollen: Channels = Channels(250, 214, 60)) -> Head {
        let look = petalLook(petal)
        var head = [Part(mesh: kit.add(whorl(
            petal, length: size, open: open, bend: bend,
            turns: Grower.evenly(petals))), look: look)]
        if count > 0 {
            head += stamens(count, length: size * 0.35, spread: size * 0.18,
                            anther: size * 0.06, thread: lighter(pollen, 0.5),
                            pollen: pollen)
        }
        if let heart { head.append(dome(size * 0.12, color: heart)) }
        return head
    }

    /// Поставить цветок: все детали — одной позой и одним покачиванием.
    mutating func place(flower head: Head, _ pose: Pose, sag: Float,
                        delay: Float) {
        let phase = random(0 ... 1)
        for part in head {
            kit.place(part.mesh, part.look, pose, sag: sag, sway: 0.03,
                      delay: delay, phase: phase)
        }
    }

    // MARK: - Горшок и земля

    enum Shape { case classic, cylinder, bowl }

    enum Top { case soil, gravel, bark }

    static func profile(_ shape: Shape) -> [SIMD2<Float>] {
        let rim = Greenhouse.rim
        let soil = Greenhouse.soil
        let inner = Greenhouse.potInner
        let top = Greenhouse.potRadius
        switch shape {
        case .classic:
            return [SIMD2(0, 0.004), SIMD2(0.05, 0), SIMD2(0.055, 0.006),
                    SIMD2(0.0562, 0.014), SIMD2(0.0646, 0.062),
                    SIMD2(0.0733, 0.11), SIMD2(0.074, 0.118),
                    SIMD2(0.081, 0.121), SIMD2(top, rim - 0.001),
                    SIMD2(0.074, rim), SIMD2(0.07, 0.126),
                    SIMD2(inner, soil - 0.004)]
        case .cylinder:
            return [SIMD2(0, 0.003), SIMD2(0.07, 0), SIMD2(0.076, 0.004),
                    SIMD2(0.078, 0.02), SIMD2(0.079, 0.07), SIMD2(0.08, 0.12),
                    SIMD2(0.0805, rim - 0.001), SIMD2(0.074, rim),
                    SIMD2(0.071, 0.126), SIMD2(inner, soil - 0.004)]
        case .bowl:
            return [SIMD2(0, 0.004), SIMD2(0.04, 0), SIMD2(0.058, 0.012),
                    SIMD2(0.072, 0.04), SIMD2(0.08, 0.08), SIMD2(0.082, 0.115),
                    SIMD2(top, rim - 0.001), SIMD2(0.074, rim),
                    SIMD2(0.07, 0.126), SIMD2(inner, soil - 0.004)]
        }
    }

    /// Горшок: цвет со снимка, если он там был; терракота — пористая и с
    /// поддоном, глазурь — блестит.
    mutating func pot(_ shape: Shape? = nil, clear: Bool = false,
                      top: Top = .soil) {
        let colors: [Channels] = [
            Channels(196, 106, 72), Channels(236, 230, 218),
            Channels(143, 168, 140), Channels(58, 60, 66),
            Channels(222, 170, 160), Channels(170, 170, 165),
        ]
        let pick = Int.random(in: 0 ..< colors.count, using: &rng)
        let color = traits?.pot ?? colors[pick]
        let clay = traits?.pot == nil ? pick == 0 : Grower.earthy(color)
        let shapes: [Shape] = [.classic, .cylinder, .bowl]
        let drawn = shapes[Int.random(in: 0 ..< shapes.count, using: &rng)]
        let form: Shape = shape ?? (clay ? .classic : drawn)
        let body = Sculpt.lathe(Grower.profile(form), segments: 96)
        if clear {
            let look = kit.add(Look(tint: Channels(235, 240, 238), rough: 0.15,
                                    gloss: 0.8, opacity: 0.35))
            kit.put(body, look)
            roots()
        } else {
            let glaze: Leafart.Glaze = clay ? .clay
                : (pick == 5 && traits?.pot == nil ? .stone : .glaze)
            let look = pictureLook(Leafart.pot(glaze, color, seed: seed),
                                   rough: clay ? 0.85 : 0.3,
                                   gloss: glaze == .glaze ? 0.6 : 0)
            kit.put(body, look)
            if clay {
                let saucer = Sculpt.lathe([
                    SIMD2(0, 0.0015), SIMD2(0.088, 0), SIMD2(0.094, 0.003),
                    SIMD2(0.098, 0.014), SIMD2(0.095, 0.0155),
                    SIMD2(0.09, 0.006), SIMD2(0, 0.006),
                ], segments: 96)
                kit.put(saucer, look)
            }
        }
        dress(top)
    }

    /// Терракота узнаётся по тёплому землистому тону.
    static func earthy(_ color: Channels) -> Bool {
        color.red > color.green * 1.25 && color.green > color.blue
            && color.red > 120 && color.red < 235
    }

    private mutating func dress(_ top: Top) {
        let soil = Grower.soil
        let disc = Sculpt.lathe([
            SIMD2(Greenhouse.potInner + 0.0015, soil - 0.002),
            SIMD2(0.045, soil + 0.005), SIMD2(0, soil + 0.008),
        ], segments: 64).mappedFromAbove(radius: Greenhouse.potInner)
        let earth = Greenhouse.drySoil
        let ground = kit.add(Leafart.soil(earth, seed: seed))
        let look = kit.add(Look(color: ground, rough: 0.95, wets: true))
        kit.put(disc, look)
        switch top {
        case .soil:
            break
        case .gravel:
            let stones = pictureLook(
                Leafart.pot(.stone, Channels(190, 182, 168), seed: seed &+ 7),
                rough: 0.8)
            pebbles(110, size: 0.004 ... 0.007, squash: Vec3(1, 0.6, 1),
                    look: stones)
        case .bark:
            let chips = pictureLook(
                Leafart.bark(Channels(128, 84, 52), dark: Channels(80, 50, 30),
                             seed: seed &+ 9), rough: 0.9)
            pebbles(55, size: 0.008 ... 0.013, squash: Vec3(1.6, 0.5, 1),
                    look: chips)
        }
    }

    private mutating func pebbles(_ count: Int, size: ClosedRange<Float>,
                                  squash: Vec3, look: Int) {
        var heap = Mesh3D()
        for _ in 0 ..< count {
            let angle = random(0 ... 2 * .pi)
            let reach = random(0 ... 1).squareRoot()
                * (Greenhouse.potInner - 0.006)
            let stone = Sculpt.ball(radius: random(size), segments: 7, rings: 4)
                .stretched(squash)
                .turned(around: Pose.y, by: random(0 ... 3))
                .moved(by: Vec3(cos(angle) * reach,
                                Grower.soil + 0.004 + random(0 ... 0.003),
                                sin(angle) * reach))
            heap.merge(stone)
        }
        kit.put(heap, look)
    }

    /// Корни в прозрачном горшке орхидеи — серо-зелёные, вьются по стенке.
    private mutating func roots() {
        let look = plainLook(Channels(160, 175, 150), rough: 0.6)
        var paths: [[Vec3]] = []
        for index in 0 ..< 6 {
            let yaw = Float(index) * 1.05 + random(0 ... 0.4)
            let low = random(0.02 ... 0.06)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.01, Grower.soil, 0), yaw),
                Grower.around(Vec3(0.07, Grower.soil - 0.02, 0.02), yaw),
                Grower.around(Vec3(0.066, low, -0.03), yaw), steps: 12))
        }
        stems(paths, look: look, sides: 6) { _ in 0.0035 }
    }
}
