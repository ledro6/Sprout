import Foundation

/// Двадцать видов, которые телефон умеет выращивать в объёме. Любой вид
/// сада сводится к ближайшему из них; снимок подкрашивает модель под своё
/// растение, а без снимка встаёт готовая модель вида.
enum Preset: String, Codable, CaseIterable, Sendable {
    case monstera, ficus, sansevieria, zamioculcas, spathiphyllum, orchid,
         aloe, cactus, echeveria, jade, dracaena, palm, fern, ivy,
         chlorophytum, violet, begonia, pelargonium, herbs, tulip

    var title: String {
        switch self {
        case .monstera: "Монстера"
        case .ficus: "Фикус"
        case .sansevieria: "Сансевиерия"
        case .zamioculcas: "Замиокулькас"
        case .spathiphyllum: "Спатифиллум"
        case .orchid: "Орхидея"
        case .aloe: "Алоэ"
        case .cactus: "Кактус"
        case .echeveria: "Эхеверия"
        case .jade: "Толстянка"
        case .dracaena: "Драцена"
        case .palm: "Пальма"
        case .fern: "Папоротник"
        case .ivy: "Плющ"
        case .chlorophytum: "Хлорофитум"
        case .violet: "Фиалка"
        case .begonia: "Бегония"
        case .pelargonium: "Пеларгония"
        case .herbs: "Пряные травы"
        case .tulip: "Тюльпан"
        }
    }

    /// По вписанному виду. Частное — раньше общего: «каменная роза» —
    /// суккулент, а не роза.
    static func of(_ species: String) -> Preset {
        let name = species.lowercased()
        return table.first { name.contains($0.stem) }?.preset ?? .spathiphyllum
    }

    private static let table: [(stem: String, preset: Preset)] = [
        ("монстер", .monstera), ("филодендрон", .monstera),
        ("фикус", .ficus), ("каучук", .ficus), ("деревце", .ficus),
        ("сансевиер", .sansevieria), ("щучий", .sansevieria),
        ("замиокулькас", .zamioculcas), ("долларов", .zamioculcas),
        ("спатифил", .spathiphyllum), ("диффенбах", .spathiphyllum),
        ("антуриум", .spathiphyllum), ("аглаонем", .spathiphyllum),
        ("орхиде", .orchid), ("фаленопсис", .orchid),
        ("алоэ", .aloe), ("хавортия", .aloe), ("агав", .aloe),
        ("кактус", .cactus), ("опунци", .cactus), ("маммиллярия", .cactus),
        ("эхевери", .echeveria), ("суккулент", .echeveria),
        ("молодил", .echeveria), ("каменная роза", .echeveria),
        ("толстянк", .jade), ("крассул", .jade), ("денежное", .jade),
        ("каланхоэ", .jade),
        ("драцен", .dracaena), ("юкк", .dracaena), ("кордилин", .dracaena),
        ("пальм", .palm), ("хамедоре", .palm), ("бамбук", .palm),
        ("папорот", .fern), ("нефролепис", .fern), ("мох", .fern),
        ("плющ", .ivy), ("сциндапсус", .ivy), ("эпипремнум", .ivy),
        ("хойя", .ivy), ("традесканц", .ivy),
        ("пряност", .herbs), ("пряные", .herbs),
        ("хлорофит", .chlorophytum), ("трав", .chlorophytum),
        ("фиалк", .violet), ("сенполи", .violet),
        ("бегони", .begonia),
        ("пеларгони", .pelargonium), ("герань", .pelargonium),
        ("розмарин", .herbs),
        ("роз", .pelargonium), ("ромашк", .pelargonium),
        ("цвет", .pelargonium),
        ("базилик", .herbs), ("мят", .herbs),
        ("зелень", .herbs), ("петрушк", .herbs), ("укроп", .herbs),
        ("кустик", .herbs), ("росток", .herbs),
        ("тюльпан", .tulip), ("лили", .tulip), ("нарцисс", .tulip),
        ("гиацинт", .tulip), ("крокус", .tulip), ("подсолнух", .tulip),
    ]
}

extension Plant {
    /// Свой чертёж — снятый при посадке; нет — готовая модель вида.
    var blueprint: Blueprint { plan ?? .stock(species) }
}

/// Выращивает модель по чертежу. Каждый вид — свой рецепт из общих частей:
/// горшок, земля, стебли, листья-карточки с рисунком, мясистые листья,
/// цветы. Всё детерминировано: один чертёж — одна и та же модель.
enum Botany {
    static func grow(_ blueprint: Blueprint, species: String) -> Kit {
        var grower = Grower(blueprint, species: species)
        switch blueprint.preset {
        case .monstera: grower.monstera()
        case .ficus: grower.ficus()
        case .sansevieria: grower.sansevieria()
        case .zamioculcas: grower.zamioculcas()
        case .spathiphyllum: grower.spathiphyllum()
        case .orchid: grower.orchid()
        case .aloe: grower.aloe()
        case .cactus: grower.cactus()
        case .echeveria: grower.echeveria()
        case .jade: grower.jade()
        case .dracaena: grower.dracaena()
        case .palm: grower.palm()
        case .fern: grower.fern()
        case .ivy: grower.ivy()
        case .chlorophytum: grower.chlorophytum()
        case .violet: grower.violet()
        case .begonia: grower.begonia()
        case .pelargonium: grower.pelargonium()
        case .herbs: grower.herbs()
        case .tulip: grower.tulip()
        }
        grower.kit.measure()
        return grower.kit
    }
}

/// Сборщик: набор, случайность от зерна, черты со снимка и общие части.
struct Grower {
    var kit = Kit()
    var rng: Seeded
    let traits: Traits?
    let seed: UInt32
    let species: String

    static let soil = Greenhouse.soil

    init(_ blueprint: Blueprint, species: String) {
        rng = Seeded(blueprint.seed + blueprint.preset.rawValue)
        traits = blueprint.traits
        seed = UInt32(truncatingIfNeeded: Seeded.hash(blueprint.seed))
        self.species = species.lowercased()
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
                               height: height)
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
                               bend: bend, rows: rows, columns: columns,
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
            mesh.merge(Sculpt.tube(path, sides: sides, radius: radius))
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
    static func whorl(_ design: LeafLook, length: Float, open: Float,
                      bend: Sculpt.Bend, turns: [Float],
                      sizes: [Float]? = nil, shift: Float = 0,
                      root: Float = 0, rows: Int = 12,
                      columns: Int = 9) -> Mesh3D {
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
        let mesh = Grower.whorl(design, length: length, open: open,
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
        var head = [Part(mesh: kit.add(Grower.whorl(
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

    // MARK: - Виды

    mutating func monstera() {
        pot()
        let base = green(Channels(34, 104, 50))
        let mature = LeafLook(outline: .heart, aspect: 0.92, veins: .pinnate(7),
                              base: base, tip: lighter(base, 0.12),
                              vein: lighter(base, 0.45), slits: 6, holes: 4)
        var young = mature
        young.slits = 0
        young.holes = 0
        young.aspect = 0.78
        young.base = lighter(base, 0.2)
        let mainLook = leafLook(mature, rough: 0.4, gloss: 0.35, height: 768)
        let youngLook = leafLook(young, rough: 0.4, gloss: 0.3)
        let big = leafMesh(mature, length: 0.2,
                           bend: Sculpt.Bend(arch: 0.16, fold: 0.1, cup: 0.08,
                                             wave: 0.015, waves: 4),
                           rows: 28, columns: 15)
        let small = leafMesh(young, length: 0.2,
                             bend: Sculpt.Bend(arch: 0.2, fold: 0.18))
        let stalk = pictureLook(Leafart.bark(lighter(base, 0.15),
                                             dark: base, seed: seed),
                                rough: 0.5)
        let count = count(5 ... 8)
        var paths: [[Vec3]] = []
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.2 ... 0.2))
                / Float(count)
            let reach = random(0.03 ... 0.09)
            let lift = random(0.14 ... 0.3) * stretch
            let end = Grower.around(Vec3(reach, Grower.soil + lift, 0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.008, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.2, Grower.soil + lift * 0.9, 0),
                              yaw),
                end))
            let isYoung = index == count - 1
            kit.place(isYoung ? small : big, isYoung ? youngLook : mainLook,
                      Pose(base: end, yaw: yaw, rise: random(-0.15 ... 0.3),
                           roll: random(-0.25 ... 0.25),
                           size: isYoung ? 0.55 : random(0.85 ... 1.2)),
                      sag: 0.6, sway: 0.025,
                      delay: Float(index) / Float(count), phase: random(0 ... 1))
        }
        stems(paths, look: stalk) { 0.0055 - 0.002 * $0 }
        // Воздушные корни — от стеблей вниз, в землю.
        let rootLook = plainLook(Channels(112, 84, 56), rough: 0.8)
        var roots: [[Vec3]] = []
        for index in 0 ..< Int.random(in: 1 ... 2, using: &rng) {
            let yaw = Float(index) * 2.4 + random(0 ... 1)
            roots.append(Sculpt.curve(
                Grower.around(Vec3(0.02, Grower.soil + 0.07, 0), yaw),
                Grower.around(Vec3(0.06, Grower.soil + 0.05, 0), yaw),
                Grower.around(Vec3(0.05, Grower.soil - 0.002, 0), yaw)))
        }
        stems(roots, look: rootLook, sides: 6) { 0.0028 - 0.001 * $0 }
    }

    mutating func ficus() {
        pot()
        let base = green(Channels(26, 66, 38))
        var design = LeafLook(outline: .oval, aspect: 0.5, veins: .pinnate(12),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.35))
        if let spot = traits?.variegation {
            design.pattern = .edges(spot, 0.35)
        }
        let look = leafLook(design, rough: 0.28, gloss: 0.7)
        let leaf = leafMesh(design, length: 0.17,
                            bend: Sculpt.Bend(arch: 0.14, fold: 0.12, cup: 0.06,
                                              wave: 0.008, waves: 3))
        let bark = pictureLook(Leafart.bark(Channels(130, 118, 96),
                                            dark: Channels(88, 78, 62),
                                            seed: seed), rough: 0.8)
        let height = random(0.3 ... 0.42) * stretch
        let lean = random(-0.03 ... 0.03)
        let trunk = (0 ... 12).map { step -> Vec3 in
            let t = Float(step) / 12
            return Vec3(lean * sin(t * .pi), Grower.soil - 0.01 + height * t,
                        lean * 0.5 * sin(t * 2 * .pi))
        }
        stems([trunk], look: bark, sides: 10) { 0.011 - 0.004 * $0 }
        let count = count(13 ... 18)
        var petioles: [[Vec3]] = []
        for index in 0 ..< count {
            let t = 0.25 + 0.72 * Float(index) / Float(count)
            let on = trunk[min(Int((t * 12).rounded()), 12)]
            let yaw = Float(index) * 2.399_963
            let out = Grower.around(Vec3(0.018, 0.008, 0), yaw)
            petioles.append([on, on + out * 0.5 + Vec3(0, 0.004, 0), on + out])
            kit.place(leaf, look,
                      Pose(base: on + out, yaw: yaw,
                           rise: 0.1 + 0.5 * t + random(-0.1 ... 0.1),
                           roll: random(-0.2 ... 0.2),
                           size: 1.1 - 0.35 * t + random(-0.08 ... 0.08)),
                      sag: 0.45, sway: 0.02, delay: t, phase: random(0 ... 1))
        }
        stems(petioles, look: bark, sides: 5) { _ in 0.0025 }
        let sheath = Sculpt.spike(radius: 0.005, height: 0.035, sides: 8)
            .moved(by: trunk[12])
        kit.put(sheath, plainLook(Channels(170, 52, 60), rough: 0.4))
    }

    mutating func sansevieria() {
        pot(.cylinder)
        let base = green(Channels(40, 86, 52))
        var design = LeafLook(outline: .sword, aspect: 0.17, veins: .none,
                              base: base, tip: lighter(base, 0.05),
                              pattern: .bands(darker(base, 0.45), 11))
        if traits?.variegation != nil || chance(0.5) {
            design.margin = traits?.variegation ?? Channels(222, 204, 92)
            design.marginWidth = 0.1
        }
        let look = leafLook(design, rough: 0.45, gloss: 0.2)
        var leaves: [Int] = []
        for _ in 0 ..< 3 {
            leaves.append(leafMesh(design, length: random(0.32 ... 0.46)
                                       * stretch,
                                   bend: Sculpt.Bend(arch: 0.02, fold: 0.3,
                                                     twist: random(-0.5 ... 0.5)),
                                   rows: 26, columns: 7))
        }
        let count = count(6 ... 10)
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963
            kit.place(leaves[index % 3], look,
                      Pose(base: Grower.around(Vec3(random(0.006 ... 0.03),
                                                    Grower.soil - 0.005, 0), yaw),
                           yaw: yaw, rise: random(1.32 ... 1.52),
                           roll: random(-0.6 ... 0.6),
                           size: random(0.7 ... 1.05)),
                      sag: 0.08, sway: 0.008, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
    }

    mutating func zamioculcas() {
        pot()
        let base = green(Channels(30, 82, 42))
        let design = LeafLook(outline: .ovate, aspect: 0.44, veins: .pinnate(5),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.3))
        let look = leafLook(design, rough: 0.22, gloss: 0.8, height: 384)
        let leaflet = leafMesh(design, length: 0.06,
                               bend: Sculpt.Bend(arch: 0.1, fold: 0.15, cup: 0.1))
        let stalk = pictureLook(Leafart.bark(Channels(78, 112, 54),
                                             dark: Channels(44, 70, 34),
                                             seed: seed), rough: 0.35,
                                gloss: 0.4)
        let count = count(6 ... 9)
        var paths: [[Vec3]] = []
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.25 ... 0.25))
                / Float(count)
            // Черешки веером наружу, а не пучком вверх.
            let reach = random(0.06 ... 0.14)
            let lift = random(0.2 ... 0.34) * stretch
            let path = Sculpt.curve(
                Grower.around(Vec3(0.012, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.15, Grower.soil + lift * 0.7, 0), yaw),
                Grower.around(Vec3(reach, Grower.soil + lift, 0), yaw), steps: 12)
            paths.append(path)
            let pairs = Int.random(in: 4 ... 6, using: &rng)
            for pair in 0 ..< pairs {
                let t = 0.4 + 0.58 * Float(pair) / Float(pairs)
                let step = min(Int((t * 12).rounded()), 11)
                let at = path[step]
                let ahead = (path[step + 1] - path[step]).unit
                let heading = atan2(-ahead.z, ahead.x)
                let climb = asin(min(max(ahead.y, -1), 1))
                // Листочки двумя рядами по сторонам черешка и к его концу.
                for side: Float in [1, -1] {
                    kit.place(leaflet, look,
                              Pose(base: at, yaw: heading + side * random(0.55 ... 0.8),
                                   rise: climb * 0.6 + random(-0.1 ... 0.15),
                                   roll: side * random(0.3 ... 0.6),
                                   size: 1.1 - 0.4 * abs(t - 0.65)),
                              sag: 0.4, sway: 0.02,
                              delay: (Float(index) + t) / Float(count + 1),
                              phase: random(0 ... 1))
                }
            }
            let tip = (path[12] - path[11]).unit
            kit.place(leaflet, look,
                      Pose(base: path[12], yaw: atan2(-tip.z, tip.x),
                           rise: asin(min(max(tip.y, -1), 1)) * 0.6, size: 0.85),
                      sag: 0.4, sway: 0.02, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
        stems(paths, look: stalk, sides: 8) { 0.011 * pow(1 - $0, 1.4) + 0.0035 }
    }

    mutating func spathiphyllum() {
        pot()
        let base = green(Channels(30, 96, 46))
        var design = LeafLook(outline: .lanceolate, aspect: 0.36,
                              veins: .pinnate(9), base: base,
                              tip: lighter(base, 0.1), vein: lighter(base, 0.4))
        if let spot = traits?.variegation {
            design.pattern = .marbled(spot, 0.3)
        }
        let look = leafLook(design, rough: 0.35, gloss: 0.4)
        let leaf = leafMesh(design, length: 0.18,
                            bend: Sculpt.Bend(arch: 0.25, fold: 0.18,
                                              wave: 0.01, waves: 3))
        let stalk = plainLook(lighter(base, 0.1), rough: 0.5)
        let count = count(10 ... 15)
        var paths: [[Vec3]] = []
        var top: Float = 0
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963
            let reach = random(0.02 ... 0.06)
            let lift = random(0.1 ... 0.2) * stretch
            top = max(top, lift)
            let end = Grower.around(Vec3(reach, Grower.soil + lift, 0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.006, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.3, Grower.soil + lift * 0.8, 0), yaw),
                end))
            kit.place(leaf, look,
                      Pose(base: end, yaw: yaw, rise: random(0.35 ... 0.9),
                           roll: random(-0.2 ... 0.2), size: random(0.8 ... 1.15)),
                      sag: 0.9, sway: 0.025, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
        stems(paths, look: stalk, sides: 6) { 0.004 - 0.0015 * $0 }
        let spathe = LeafLook(outline: .spathe, aspect: 0.5,
                              veins: .fan(9),
                              base: bloom(Channels(248, 248, 240)),
                              tip: Channels(206, 226, 190),
                              vein: Channels(200, 218, 188),
                              throat: Channels(214, 232, 196),
                              throatReach: 0.25, glow: 0.25, mottle: 0.05)
        let white = leafLook(spathe, rough: 0.5, height: 256, wilts: false)
        let hood = leafMesh(spathe, length: 0.075,
                            bend: Sculpt.Bend(arch: -0.05, fold: 0.1, cup: 0.45),
                            rows: 14, columns: 9)
        // Початок толще к середине и чуть изогнут, в бугорках-цветочках.
        let spadix = Sculpt.tube((0 ... 10).map {
            let t = Float($0) / 10
            return Vec3(0.008 + 0.03 * t, 0.006 + 0.003 * t * t, 0)
        }, sides: 10, repeat: 0.04) { t in
            0.0042 * pow(sin(Float.pi * (0.15 + 0.85 * t)), 0.5) + 0.0008
        }
        let cream = kit.add(spadix)
        let creamLook = pictureLook(Leafart.spadix(Channels(238, 228, 176)),
                                    rough: 0.8)
        var stalks: [[Vec3]] = []
        for index in 0 ..< self.count(2 ... 4) {
            let yaw = Float(index) * 2.1 + random(0 ... 0.6)
            let lift = top + random(0.05 ... 0.12)
            let end = Grower.around(Vec3(random(0.01 ... 0.04),
                                         Grower.soil + lift, 0), yaw)
            stalks.append(Sculpt.curve(
                Grower.around(Vec3(0.004, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(0.005, Grower.soil + lift * 0.6, 0), yaw), end))
            let pose = Pose(base: end, yaw: yaw, rise: random(1.1 ... 1.35),
                            roll: 0)
            let phase = random(0 ... 1)
            kit.place(hood, white, pose, sag: 0.8, sway: 0.03, delay: 0.8,
                      phase: phase)
            kit.place(cream, creamLook, pose, sag: 0.8, sway: 0.03, delay: 0.8,
                      phase: phase)
        }
        stems(stalks, look: stalk, sides: 6) { _ in 0.003 }
    }

    mutating func orchid() {
        pot(.cylinder, clear: true, top: .bark)
        let base = green(Channels(44, 104, 58))
        let design = LeafLook(outline: .oval, aspect: 0.36, veins: .parallel(6),
                              base: base, tip: lighter(base, 0.1),
                              vein: lighter(base, 0.2))
        let look = leafLook(design, rough: 0.3, gloss: 0.5)
        let leaf = leafMesh(design, length: 0.16,
                            bend: Sculpt.Bend(arch: 0.18, fold: 0.35))
        let count = count(4 ... 6)
        for index in 0 ..< count {
            let yaw = (index.isMultiple(of: 2) ? 0 : Float.pi)
                + random(-0.35 ... 0.35) + Float(index) * 0.15
            kit.place(leaf, look,
                      Pose(base: Vec3(0, Grower.soil + 0.006 + Float(index) * 0.004,
                                      0),
                           yaw: yaw, rise: random(0.05 ... 0.35),
                           size: 1.1 - Float(index) * 0.08),
                      sag: 0.35, sway: 0.01, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
        let head = orchidFlower(bloom(Channels(246, 232, 244)))
        let bud = kit.add(Sculpt.ball(radius: 0.007, segments: 10, rings: 6)
            .stretched(Vec3(1.5, 1, 1)))
        let budLook = plainLook(.mix(Channels(170, 196, 140),
                                     bloom(Channels(246, 232, 244)), 0.35),
                                rough: 0.5)
        let spikeLook = plainLook(Channels(74, 86, 52), rough: 0.6)
        var spikes: [[Vec3]] = []
        for index in 0 ..< Int.random(in: 1 ... 2, using: &rng) {
            let yaw = Float.pi / 2 + Float(index) * Float.pi + random(-0.3 ... 0.3)
            let high = random(0.3 ... 0.4) * stretch
            let path = Sculpt.curve(
                Vec3(0, Grower.soil + 0.01, 0),
                Grower.around(Vec3(0.0, Grower.soil + high * 1.35, 0), yaw),
                Grower.around(Vec3(0.18, Grower.soil + high * 0.7, 0), yaw),
                steps: 20)
            spikes.append(path)
            let blooms = Int.random(in: 5 ... 8, using: &rng)
            for flowerIndex in 0 ..< blooms {
                let at = path[min(8 + flowerIndex * 10 / blooms, 18)]
                place(flower: head,
                      Pose(base: at + Vec3(0, -0.014, 0),
                           yaw: yaw + (flowerIndex.isMultiple(of: 2) ? 0.9 : -0.9)
                               + random(-0.2 ... 0.2),
                           rise: random(-0.15 ... 0.15),
                           roll: random(-0.25 ... 0.25)),
                      sag: 0.3, delay: 0.7 + 0.03 * Float(flowerIndex))
            }
            kit.place(bud, budLook, Pose(base: path[20], yaw: yaw),
                      sag: 0.3, sway: 0.03, delay: 0.9, phase: random(0 ... 1))
            kit.place(bud, budLook, Pose(base: path[19], yaw: yaw, size: 0.8),
                      sag: 0.3, sway: 0.03, delay: 0.9, phase: random(0 ... 1))
        }
        stems(spikes, look: spikeLook, sides: 6) { _ in 0.0024 }
    }

    /// Фаленопсис анфас: три чашелистика — верхний и два нижних, два
    /// широких лепестка по бокам, губа с жёлтым горлом и крапом внизу и
    /// колонка в середине. Всё плоско, чуть вперёд, как у живого цветка.
    mutating func orchidFlower(_ colour: Channels) -> Head {
        let length: Float = 0.036
        let blush = Channels.mix(colour, Channels(214, 60, 150), 0.35)
        let sepal = LeafLook(outline: .oval, aspect: 0.5, veins: .fan(7),
                             base: colour, tip: lighter(colour, 0.2),
                             vein: blush, throat: blush, throatReach: 0.3,
                             glow: 0.35, mottle: 0.06)
        let petal = LeafLook(outline: .broad, aspect: 1.02, veins: .fan(11),
                             base: colour, tip: lighter(colour, 0.25),
                             vein: blush, throat: blush, throatReach: 0.35,
                             glow: 0.4, mottle: 0.06)
        let lipColour = Channels.mix(colour, Channels(196, 34, 120), 0.75)
        let lip = LeafLook(outline: .lip, aspect: 0.9, veins: .fan(5),
                           base: lipColour, tip: darker(lipColour, 0.1),
                           vein: darker(lipColour, 0.3),
                           pattern: .spots(Channels(150, 20, 80), 26),
                           throat: Channels(250, 206, 70), throatReach: 0.4,
                           mottle: 0.1)
        let flat = Float.pi / 2 - 0.1
        let sepals = Grower.whorl(sepal, length: length, open: flat,
                                  bend: Sculpt.Bend(arch: 0.08, fold: 0.05,
                                                    cup: -0.15),
                                  turns: [0, 2.45, -2.45], shift: -0.0015)
        let petals = Grower.whorl(petal, length: length * 0.92, open: flat,
                                  bend: Sculpt.Bend(arch: 0.05, fold: 0,
                                                    cup: -0.12, wave: 0.02,
                                                    waves: 2),
                                  turns: [1.3, -1.3])
        let labellum = Grower.whorl(lip, length: length * 0.55,
                                    open: Float.pi / 2 - 0.45,
                                    bend: Sculpt.Bend(arch: 0.35, fold: 0,
                                                      cup: -0.7),
                                    turns: [Float.pi], shift: 0.002)
        let column = Sculpt.tube(Sculpt.curve(Vec3(0, 0, 0),
                                              Vec3(0.004, 0.001, 0),
                                              Vec3(0.008, 0.001, 0), steps: 4),
                                 sides: 8) { 0.0026 - 0.0008 * $0 }
        return [
            Part(mesh: kit.add(sepals), look: petalLook(sepal, rough: 0.45)),
            Part(mesh: kit.add(petals), look: petalLook(petal, rough: 0.45)),
            Part(mesh: kit.add(labellum), look: petalLook(lip, rough: 0.4,
                                                          gloss: 0.2)),
            Part(mesh: kit.add(Grower.opaque(column)),
                 look: plainLook(Channels(250, 246, 236), rough: 0.5)),
        ]
    }

    mutating func aloe() {
        pot(.bowl, top: .gravel)
        let base = green(Channels(112, 150, 112))
        var skin = Leafart.skin(base, seed: seed)
        for _ in 0 ..< 90 {
            skin.disc(SIMD2(random(0 ... 1), random(0.05 ... 0.9)),
                      radius: 0.02, squash: 0.25, Ink(0.9, 0.93, 0.88, 0.85))
        }
        let look = pictureLook(skin, rough: 0.5, gloss: 0.1, wilts: true)
        func shape(_ t: Float) -> Float { pow(sin(Float.pi * pow(t, 0.5)), 1.3) }
        var leaves: [Int] = []
        for variant in 0 ..< 3 {
            let length = 0.16 + Float(variant) * 0.02
            let width: Float = 0.042
            var leaf = Sculpt.fleshy(length: length, width: width,
                                     thickness: 0.014, arch: 0.1, rows: 18,
                                     sides: 14, shape: shape)
            // Зубцы по краю — мелкие шипы наружу.
            for step in 1 ..< 14 {
                let t = Float(step) / 14
                let half = width / 2 * shape(t)
                for side: Float in [1, -1] {
                    let tooth = Sculpt.spike(radius: 0.0012, height: 0.004,
                                             sides: 4)
                        .turned(around: Pose.x, by: side * Float.pi / 2)
                        .moved(by: Vec3(t * length, -0.1 * length * t * t,
                                        side * half))
                    leaf.merge(tooth)
                }
            }
            leaves.append(kit.add(leaf))
        }
        let count = count(12 ... 18)
        for index in 0 ..< count {
            let inner = Float(index) / Float(count)
            let yaw = Float(index) * 2.399_963
            kit.place(leaves[index % 3], look,
                      Pose(base: Grower.around(Vec3(0.004 + 0.014 * (1 - inner),
                                                    Grower.soil, 0), yaw),
                           yaw: yaw, rise: 0.35 + 0.95 * inner,
                           size: 1.05 - 0.45 * inner),
                      sag: 0.25, sway: 0.006, delay: inner, phase: random(0 ... 1))
        }
    }

    mutating func cactus() {
        pot(.classic, top: .gravel)
        let base = green(Channels(62, 122, 72))
        let look = pictureLook(Leafart.skin(base, seed: seed), rough: 0.55,
                               gloss: 0.1, wilts: true)
        let areoleLook = plainLook(Channels(236, 232, 220), rough: 0.9)
        let spineLook = plainLook(Channels(232, 222, 176), rough: 0.5)
        let soil = Grower.soil
        let tall = random(0.14 ... 0.24) * stretch
        let ribs = Int.random(in: 10 ... 12, using: &rng)
        let depth: Float = 0.09
        let profile: [SIMD2<Float>] = [
            SIMD2(0.036, soil - 0.004), SIMD2(0.039, soil + 0.02),
            SIMD2(0.039, soil + tall * 0.5), SIMD2(0.038, soil + tall * 0.8),
            SIMD2(0.031, soil + tall * 0.95), SIMD2(0.018, soil + tall + 0.008),
            SIMD2(0, soil + tall + 0.012),
        ]
        var body = Sculpt.lathe(profile, segments: 120, ribs: ribs,
                                ribDepth: depth)
        var areoles = Mesh3D()
        var spines = Mesh3D()
        func radius(at y: Float) -> Float {
            for index in 1 ..< profile.count where profile[index].y >= y {
                let a = profile[index - 1]
                let b = profile[index]
                let t = (y - a.y) / max(b.y - a.y, 1e-5)
                return a.x + (b.x - a.x) * t
            }
            return 0
        }
        func dress(column: (Float) -> (Vec3, Vec3), steps: Int) {
            for step in 0 ..< steps {
                let (point, out) = column(Float(step) / Float(steps))
                areoles.merge(Sculpt.ball(radius: 0.0022, segments: 6, rings: 4)
                    .moved(by: point))
                for spine in 0 ..< 4 {
                    let spread = Float(spine) * 1.57 + random(-0.3 ... 0.3)
                    let tangent = out.crossed(Pose.y).unit
                    let direction = (out + tangent * cos(spread) * 0.7
                        + Pose.y * sin(spread) * 0.7).unit
                    let needle = Sculpt.spike(radius: 0.0005,
                                              height: random(0.006 ... 0.011),
                                              sides: 4)
                    spines.merge(needle.posed(Pose(
                        base: point,
                        yaw: atan2(-direction.z, direction.x),
                        rise: asin(min(max(direction.y, -1), 1)) - .pi / 2)))
                }
            }
        }
        for rib in 0 ..< ribs {
            let angle = 2 * Float.pi * Float(rib) / Float(ribs)
            let out = Vec3(cos(angle), 0, sin(angle))
            dress(column: { t in
                let y = soil + 0.012 + (tall - 0.004) * t
                let r = radius(at: y) * (1 + depth)
                return (Vec3(out.x * r, y, out.z * r), out)
            }, steps: Int(tall / 0.012))
        }
        for index in 0 ..< Int.random(in: 0 ... 2, using: &rng) {
            let yaw = Float(index) * Float.pi + random(-0.5 ... 0.5)
            let at = soil + tall * random(0.35 ... 0.6)
            let length = random(0.04 ... 0.07)
            var path = [Vec3(0.028, at, 0), Vec3(0.045, at + 0.002, 0),
                        Vec3(0.058, at + 0.01, 0), Vec3(0.064, at + 0.022, 0)]
            for step in 1 ... 8 {
                path.append(Vec3(0.066, at + 0.022 + length * Float(step) / 8, 0))
            }
            let placed = path.map { Grower.around($0, yaw) }
            body.merge(Sculpt.tube(placed, sides: 24) { t in
                t < 0.85 ? 0.017
                    : 0.017 * max(0, 1 - pow((t - 0.85) / 0.15, 2)).squareRoot()
            })
            for line in 0 ..< 4 {
                let turn = Float(line) * Float.pi / 2
                dress(column: { t in
                    let step = min(Int(4 + t * 7), path.count - 1)
                    let center = placed[step]
                    let out = Grower.around(Vec3(cos(turn), 0, sin(turn)), yaw)
                    return (center + out * 0.018, out)
                }, steps: 6)
            }
        }
        kit.put(body, look)
        kit.put(areoles, areoleLook)
        kit.put(spines, spineLook)
        if traits?.flower != nil || chance(0.3) {
            let head = cactusFlower(bloom(Channels(236, 96, 150)))
            place(flower: head,
                  Pose(base: Vec3(0, soil + tall + 0.008, 0), rise: .pi / 2),
                  sag: 0, delay: 0.9)
        }
    }

    mutating func echeveria() {
        pot(.bowl, top: .gravel)
        let base = green(Channels(142, 176, 166))
        var skin = Leafart.skin(base, seed: seed)
        let blush = bloom(Channels(214, 120, 140))
        skin.shade { uv, old in
            let k = pow(max(0, uv.y - 0.6) / 0.4, 1.6) * 0.8
            return Leafart.blend(old, blush, k)
        }
        let look = pictureLook(skin, rough: 0.6, wilts: true)
        func spoon(_ t: Float) -> Float { pow(sin(Float.pi * pow(t, 1.3)), 0.6) }
        let leaves = (0 ..< 3).map { variant in
            kit.add(Sculpt.fleshy(length: 0.066 + Float(variant) * 0.006,
                                  width: 0.038, thickness: 0.013, arch: -0.08,
                                  rows: 12, sides: 12, shape: spoon))
        }
        func rosette(at center: Vec3, scale: Float, count: Int, delay: Float) {
            for index in 0 ..< count {
                let inner = Float(index) / Float(count)
                let yaw = Float(index) * 2.399_963
                kit.place(leaves[index % 3], look,
                          Pose(base: center + Grower.around(
                                   Vec3(0.026 * (1 - inner) * scale, 0, 0), yaw),
                               yaw: yaw, rise: 0.25 + 1.15 * inner,
                               size: scale * (1.05 - 0.55 * inner)),
                          sag: 0.15, sway: 0.004, delay: delay + inner * 0.3,
                          phase: random(0 ... 1))
            }
        }
        rosette(at: Vec3(0, Grower.soil + 0.004, 0), scale: 1,
                count: count(30 ... 44), delay: 0)
        for index in 0 ..< Int.random(in: 0 ... 2, using: &rng) {
            let yaw = Float(index) * 2.5 + random(0 ... 1)
            rosette(at: Grower.around(Vec3(0.05, Grower.soil + 0.004, 0), yaw),
                    scale: 0.45, count: 14, delay: 0.5)
        }
    }

    mutating func jade() {
        pot(.bowl)
        let base = green(Channels(72, 132, 72))
        var skin = Leafart.skin(base, seed: seed)
        skin.shade { uv, old in
            // Красная кайма по ребру: у мясистого листа ребро — u 0 и 0.5.
            let k = pow(abs(cos(uv.x * 4 * .pi)), 10) * 0.55
            return Leafart.blend(old, Channels(184, 51, 51), k)
        }
        let look = pictureLook(skin, rough: 0.35, gloss: 0.35, wilts: true)
        func oval(_ t: Float) -> Float { pow(sin(Float.pi * pow(t, 0.8)), 0.6) }
        let leaf = kit.add(Sculpt.fleshy(length: 0.036, width: 0.024,
                                         thickness: 0.009, arch: 0.05,
                                         rows: 10, sides: 12, shape: oval))
        let bark = pictureLook(Leafart.bark(Channels(122, 116, 78),
                                            dark: Channels(80, 74, 50),
                                            rings: 6, seed: seed), rough: 0.7)
        let height = random(0.1 ... 0.15) * stretch
        let trunk = Sculpt.curve(Vec3(0, Grower.soil - 0.01, 0),
                                 Vec3(0.005, Grower.soil + height * 0.5, 0),
                                 Vec3(-0.004, Grower.soil + height, 0))
        stems([trunk], look: bark, sides: 12) { 0.017 - 0.006 * $0 }
        var branches: [[Vec3]] = []
        var tips: [(Vec3, Float)] = []
        let top = trunk[trunk.count - 1]
        for index in 0 ..< Int.random(in: 3 ... 4, using: &rng) {
            let yaw = Float(index) * 1.8 + random(0 ... 0.6)
            let reach = random(0.05 ... 0.09)
            let end = top + Grower.around(Vec3(reach, reach * 0.7, 0), yaw)
            branches.append(Sculpt.curve(top, top + Grower.around(
                Vec3(reach * 0.4, reach * 0.1, 0), yaw), end, steps: 6))
            tips.append((end, yaw))
            for twig in 0 ..< 2 {
                let side = yaw + (twig == 0 ? 0.7 : -0.7)
                let small = end + Grower.around(Vec3(0.04, 0.03, 0), side)
                branches.append([end, (end + small) / 2 + Vec3(0, 0.006, 0),
                                 small])
                tips.append((small, side))
            }
        }
        stems(branches, look: bark, sides: 8) { 0.008 - 0.004 * $0 }
        for (tipIndex, (point, yaw)) in tips.enumerated() {
            for pair in 0 ..< 3 {
                let turn = yaw + Float(pair) * Float.pi / 2
                for side: Float in [1, -1] {
                    kit.place(leaf, look,
                              Pose(base: point + Vec3(0, Float(pair) * 0.006, 0),
                                   yaw: turn + (side > 0 ? 0 : .pi),
                                   rise: 0.3 + 0.25 * Float(pair),
                                   size: 1.05 - 0.15 * Float(pair)),
                              sag: 0.2, sway: 0.008,
                              delay: Float(tipIndex) / Float(tips.count),
                              phase: random(0 ... 1))
                }
            }
        }
        if species.contains("каланхоэ") || traits?.flower != nil {
            let colour = bloom(Channels(250, 120, 44))
            let petal = LeafLook(outline: .petal, aspect: 0.8, veins: .fan(5),
                                 base: colour, tip: lighter(colour, 0.15),
                                 vein: darker(colour, 0.15),
                                 throat: Channels(252, 214, 90),
                                 throatReach: 0.3, glow: 0.2, mottle: 0.08)
            let head = flower(petal, petals: 4, size: 0.01,
                              open: Float.pi / 2 - 0.3,
                              bend: Sculpt.Bend(arch: -0.1, fold: 0.05,
                                                cup: -0.1),
                              heart: nil, stamens: 4,
                              pollen: Channels(250, 210, 90))
            for (point, yaw) in tips.prefix(5) {
                for index in 0 ..< 5 {
                    place(flower: head,
                          Pose(base: point + Grower.around(
                                   Vec3(0.008, 0.035, 0),
                                   yaw + Float(index) * 1.25),
                               yaw: yaw + Float(index) * 1.25, rise: 1.2),
                          sag: 0.2, delay: 0.9)
                }
            }
        }
    }

    mutating func dracaena() {
        pot(.cylinder)
        let base = green(Channels(40, 92, 46))
        let design = LeafLook(outline: .strap, aspect: 0.075,
                              veins: .parallel(2), base: base,
                              tip: lighter(base, 0.1), vein: lighter(base, 0.2),
                              pattern: .edges(traits?.variegation
                                  ?? Channels(168, 40, 52), 0.22))
        let look = leafLook(design, rough: 0.4, gloss: 0.2)
        let leaves = (0 ..< 3).map { _ in
            leafMesh(design, length: random(0.14 ... 0.2),
                     bend: Sculpt.Bend(arch: random(0.25 ... 0.5), fold: 0.2,
                                       twist: random(-0.4 ... 0.4)),
                     rows: 18, columns: 5)
        }
        let bark = pictureLook(Leafart.bark(Channels(132, 120, 102),
                                            dark: Channels(90, 82, 70), rings: 14,
                                            seed: seed), rough: 0.8)
        var canes: [[Vec3]] = []
        for index in 0 ..< Int.random(in: 2 ... 3, using: &rng) {
            let yaw = Float(index) * 2.2 + random(0 ... 0.5)
            let height = (0.18 + 0.1 * Float(index) + random(0 ... 0.06)) * stretch
            let cane = Sculpt.curve(
                Grower.around(Vec3(0.01, Grower.soil - 0.01, 0), yaw),
                Grower.around(Vec3(0.02, Grower.soil + height * 0.5, 0), yaw),
                Grower.around(Vec3(0.015 + random(0 ... 0.02),
                                   Grower.soil + height, 0), yaw))
            canes.append(cane)
            let crown = cane[cane.count - 1]
            let count = count(24 ... 34)
            for leafIndex in 0 ..< count {
                let inner = Float(leafIndex) / Float(count)
                let turn = Float(leafIndex) * 2.399_963
                kit.place(leaves[leafIndex % 3], look,
                          Pose(base: crown + Vec3(0, inner * 0.02, 0),
                               yaw: turn, rise: -0.3 + 1.6 * inner,
                               roll: random(-0.4 ... 0.4),
                               size: 1.05 - 0.4 * inner),
                          sag: 0.35, sway: 0.02,
                          delay: Float(index) * 0.2 + inner * 0.5,
                          phase: random(0 ... 1))
            }
        }
        stems(canes, look: bark, sides: 9) { 0.0075 - 0.0015 * $0 }
    }

    mutating func palm() {
        pot()
        let base = green(Channels(52, 120, 58))
        let design = LeafLook(outline: .lanceolate, aspect: 0.16,
                              veins: .parallel(2), base: base,
                              tip: lighter(base, 0.12), vein: lighter(base, 0.25))
        let look = leafLook(design, rough: 0.4, gloss: 0.2, height: 256)
        var fronds: [Int] = []
        for variant in 0 ..< 3 {
            let length = 0.22 + Float(variant) * 0.05
            let spine = (0 ... 16).map { step -> Vec3 in
                let t = Float(step) / 16
                return Vec3(length * t, -0.3 * length * t * t, 0)
            }
            var frond = Grower.opaque(Sculpt.tube(spine, sides: 5) {
                0.0022 - 0.0012 * $0
            })
            for pair in 1 ... 15 {
                let t = Float(pair) / 16
                let at = spine[pair]
                let size = 0.075 * sin(Float.pi * (0.15 + 0.8 * t))
                for side: Float in [1, -1] {
                    let leaflet = Sculpt.card(length: size, width: size * 0.16,
                                              bend: Sculpt.Bend(arch: 0.25,
                                                                fold: 0.3),
                                              rows: 8, columns: 5,
                                              hug: { Leafart.half(.lanceolate, $0) })
                        .turned(around: Pose.x, by: side * 0.35)
                        .turned(around: Pose.y, by: side * (Float.pi / 2 - 0.75))
                        .moved(by: at)
                    frond.merge(leaflet)
                }
            }
            fronds.append(kit.add(frond))
        }
        let cane = pictureLook(Leafart.bark(Channels(96, 136, 70),
                                            dark: Channels(62, 96, 48),
                                            rings: 10, seed: seed), rough: 0.5)
        var canes: [[Vec3]] = []
        let count = count(3 ... 5)
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * Float(index) / Float(count) + random(0 ... 0.5)
            let height = random(0.1 ... 0.26) * stretch
            let path = Sculpt.curve(
                Grower.around(Vec3(0.01, Grower.soil - 0.01, 0), yaw),
                Grower.around(Vec3(0.012, Grower.soil + height * 0.5, 0), yaw),
                Grower.around(Vec3(0.02, Grower.soil + height, 0), yaw))
            canes.append(path)
            for frondIndex in 0 ..< Int.random(in: 3 ... 4, using: &rng) {
                kit.place(fronds[(index + frondIndex) % 3], look,
                          Pose(base: path[path.count - 1],
                               yaw: yaw + Float(frondIndex) * 1.7
                                   + random(-0.3 ... 0.3),
                               rise: random(0.55 ... 1.15),
                               roll: random(-0.3 ... 0.3),
                               size: random(0.85 ... 1.1)),
                          sag: 0.45, sway: 0.03,
                          delay: Float(index) / Float(count),
                          phase: random(0 ... 1))
            }
        }
        stems(canes, look: cane, sides: 8) { 0.006 - 0.0015 * $0 }
    }

    mutating func fern() {
        pot(.classic)
        let base = green(Channels(66, 136, 58))
        let picture = Leafart.frond(base, seed: seed)
        let texture = kit.add(picture)
        let look = kit.add(Look(color: texture, rough: 0.6, cutout: true,
                                wilts: true))
        let fronds = (0 ..< 3).map { variant in
            kit.add(Sculpt.card(length: 0.2 + Float(variant) * 0.04,
                                width: 0.05, bend: Sculpt.Bend(
                                    arch: 0.5, fold: 0.1,
                                    twist: Float(variant - 1) * 0.3),
                                rows: 30, columns: 5,
                                hug: { t in 0.35 + 0.65 * sin(Float.pi * min(t * 1.1, 1)) }))
        }
        let count = count(30 ... 44)
        for index in 0 ..< count {
            let inner = Float(index) / Float(count)
            let yaw = Float(index) * 2.399_963
            kit.place(fronds[index % 3], look,
                      Pose(base: Grower.around(Vec3(random(0.004 ... 0.02),
                                                    Grower.soil + 0.004, 0), yaw),
                           yaw: yaw, rise: 0.25 + 1.0 * inner,
                           roll: random(-0.3 ... 0.3),
                           size: random(0.8 ... 1.05) * (0.8 + 0.2 * stretch)),
                      sag: 0.5, sway: 0.035, delay: inner, phase: random(0 ... 1))
        }
    }

    mutating func ivy() {
        pot()
        let hoya = species.contains("хойя")
        let base = green(hoya ? Channels(46, 100, 50) : Channels(56, 118, 50))
        var design = LeafLook(outline: hoya ? .oval : .heart,
                              aspect: hoya ? 0.52 : 0.82,
                              veins: .pinnate(hoya ? 3 : 5), base: base,
                              tip: lighter(base, 0.1), vein: lighter(base, 0.3))
        if hoya {
            design.pattern = .speckles(Channels(220, 230, 210))
        } else {
            design.pattern = .marbled(traits?.variegation
                ?? Channels(222, 212, 120), 0.32)
        }
        let look = leafLook(design, rough: hoya ? 0.3 : 0.45,
                            gloss: hoya ? 0.5 : 0.25, height: 384)
        let leaf = leafMesh(design, length: 0.055,
                            bend: Sculpt.Bend(arch: 0.15, fold: 0.15),
                            rows: 14, columns: 9)
        let vineLook = plainLook(Channels(94, 120, 60), rough: 0.6)
        let count = count(5 ... 8)
        var vines: [[Vec3]] = []
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.2 ... 0.2))
                / Float(count)
            let trailing = index.isMultiple(of: 2) || index == 1
            let path: [Vec3]
            if trailing {
                let fall = random(0.1 ... 0.28) * stretch
                path = Sculpt.curve(
                    Grower.around(Vec3(0.01, Grower.soil, 0), yaw),
                    Grower.around(Vec3(0.12, Grower.soil + 0.06, 0), yaw),
                    Grower.around(Vec3(0.13 + random(0 ... 0.04),
                                       Grower.soil - fall, 0), yaw), steps: 16)
            } else {
                let rise = random(0.1 ... 0.2) * stretch
                path = Sculpt.curve(
                    Grower.around(Vec3(0.008, Grower.soil, 0), yaw),
                    Grower.around(Vec3(0.02, Grower.soil + rise * 0.6, 0), yaw),
                    Grower.around(Vec3(0.05, Grower.soil + rise, 0), yaw),
                    steps: 16)
            }
            vines.append(path)
            for step in stride(from: 3, through: 16, by: 2) {
                let at = path[step]
                let ahead = (path[min(step + 1, 16)] - path[step - 1]).unit
                let heading = atan2(-ahead.z, ahead.x)
                let side: Float = step % 4 == 1 ? 1 : -1
                kit.place(leaf, look,
                          Pose(base: at, yaw: heading + side * random(0.7 ... 1.3),
                               rise: trailing ? random(-0.2 ... 0.3)
                                   : random(0.1 ... 0.5),
                               roll: side * random(0 ... 0.4),
                               size: random(0.75 ... 1.15)),
                          sag: 0.5, sway: 0.03,
                          delay: (Float(index) + Float(step) / 16)
                              / Float(count + 1),
                          phase: random(0 ... 1))
            }
        }
        stems(vines, look: vineLook, sides: 5) { _ in 0.0022 }
    }

    mutating func chlorophytum() {
        pot()
        let base = green(Channels(64, 134, 62))
        let design = LeafLook(outline: .strap, aspect: 0.075,
                              veins: .parallel(3), base: base,
                              tip: lighter(base, 0.1), vein: lighter(base, 0.25),
                              pattern: .stripe(traits?.variegation
                                  ?? Channels(236, 236, 204), 0.42))
        let look = leafLook(design, rough: 0.45, gloss: 0.15)
        let leaves = (0 ..< 3).map { variant in
            leafMesh(design, length: 0.2 + Float(variant) * 0.05,
                     bend: Sculpt.Bend(arch: random(0.55 ... 0.85), fold: 0.25,
                                       twist: random(-0.3 ... 0.3)),
                     rows: 22, columns: 5)
        }
        let count = count(22 ... 34)
        for index in 0 ..< count {
            let inner = Float(index) / Float(count)
            let yaw = Float(index) * 2.399_963
            kit.place(leaves[index % 3], look,
                      Pose(base: Grower.around(Vec3(random(0.004 ... 0.016),
                                                    Grower.soil, 0), yaw),
                           yaw: yaw, rise: 0.6 + 0.75 * inner,
                           roll: random(-0.4 ... 0.4),
                           size: random(0.8 ... 1.1) * stretch),
                      sag: 0.5, sway: 0.03, delay: inner, phase: random(0 ... 1))
        }
        // Усы с детками — дугой за край горшка.
        let runner = plainLook(Channels(196, 200, 150), rough: 0.6)
        var runners: [[Vec3]] = []
        for index in 0 ..< Int.random(in: 2 ... 3, using: &rng) {
            let yaw = Float(index) * 2.3 + random(0 ... 0.8)
            let end = Grower.around(Vec3(0.2 + random(0 ... 0.06),
                                         Grower.soil - 0.08, 0), yaw)
            runners.append(Sculpt.curve(
                Grower.around(Vec3(0.01, Grower.soil + 0.02, 0), yaw),
                Grower.around(Vec3(0.12, Grower.soil + 0.14, 0), yaw), end,
                steps: 14))
            for baby in 0 ..< 7 {
                let turn = Float(baby) * 2.399_963
                kit.place(leaves[0], look,
                          Pose(base: end, yaw: turn, rise: 0.4 + Float(baby) * 0.12,
                               size: 0.28),
                          sag: 0.4, sway: 0.03, delay: 0.9, phase: random(0 ... 1))
            }
        }
        stems(runners, look: runner, sides: 5) { _ in 0.0015 }
    }

    mutating func violet() {
        pot(.bowl)
        let base = green(Channels(34, 82, 42))
        let design = LeafLook(outline: .round, aspect: 0.92, veins: .pinnate(4),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.25), teeth: 10,
                              toothDepth: 0.04, scallops: true)
        let look = leafLook(design, rough: 0.9, height: 384)
        let leaf = leafMesh(design, length: 0.06,
                            bend: Sculpt.Bend(arch: 0.12, fold: 0.05, cup: 0.12),
                            rows: 14, columns: 11)
        let stalk = plainLook(lighter(base, 0.2), rough: 0.8)
        let count = count(14 ... 20)
        var paths: [[Vec3]] = []
        for index in 0 ..< count {
            let inner = Float(index) / Float(count)
            let yaw = Float(index) * 2.399_963
            let reach = 0.075 * (1 - inner * 0.55)
            let end = Grower.around(Vec3(reach, Grower.soil + 0.03 + inner * 0.025,
                                         0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.004, Grower.soil, 0), yaw),
                Grower.around(Vec3(reach * 0.45, Grower.soil + 0.04, 0), yaw), end))
            kit.place(leaf, look,
                      Pose(base: end, yaw: yaw, rise: -0.25 + 0.6 * inner,
                           size: 1.1 - 0.35 * inner),
                      sag: 0.35, sway: 0.01, delay: inner, phase: random(0 ... 1))
        }
        stems(paths, look: stalk, sides: 5) { _ in 0.0025 }
        let head = violetFlower(bloom(Channels(112, 52, 172)))
        var pedicels: [[Vec3]] = []
        for index in 0 ..< self.count(6 ... 12) {
            let yaw = Float(index) * 2.1 + random(0 ... 0.5)
            let end = Grower.around(Vec3(random(0 ... 0.025),
                                         Grower.soil + 0.075 + random(0 ... 0.02),
                                         0), yaw)
            pedicels.append([Vec3(0, Grower.soil + 0.01, 0),
                             (end + Vec3(0, Grower.soil + 0.01, 0)) / 2
                                 + Vec3(0, 0.01, 0), end])
            place(flower: head, Pose(base: end, yaw: yaw,
                                     rise: random(0.9 ... 1.4),
                                     roll: random(-0.6 ... 0.6)),
                  sag: 0.4, delay: 0.7 + Float(index) * 0.02)
        }
        stems(pedicels, look: stalk, sides: 4) { _ in 0.0014 }
    }

    mutating func begonia() {
        pot()
        let base = green(Channels(52, 92, 48))
        let design = LeafLook(outline: .wing, aspect: 0.62, veins: .palmate(5),
                              base: base, tip: lighter(base, 0.1),
                              vein: Channels(96, 136, 74), margin: darker(base, 0.2),
                              marginWidth: 0.02,
                              pattern: .spots(traits?.variegation
                                  ?? Channels(206, 214, 210), 22),
                              teeth: 12, toothDepth: 0.05, asymmetry: 0.22)
        let look = leafLook(design, rough: 0.45, gloss: 0.2)
        let leaf = leafMesh(design, length: 0.11,
                            bend: Sculpt.Bend(arch: 0.2, fold: 0.1,
                                              wave: 0.015, waves: 4))
        let stalk = plainLook(Channels(150, 70, 60), rough: 0.6)
        let count = count(7 ... 10)
        var paths: [[Vec3]] = []
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963
            let reach = random(0.03 ... 0.07)
            let lift = random(0.08 ... 0.16) * stretch
            let end = Grower.around(Vec3(reach, Grower.soil + lift, 0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.006, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.3, Grower.soil + lift, 0), yaw), end))
            kit.place(leaf, look,
                      Pose(base: end, yaw: yaw, rise: random(-0.1 ... 0.35),
                           roll: random(-0.3 ... 0.3), size: random(0.85 ... 1.15)),
                      sag: 0.55, sway: 0.02, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
        stems(paths, look: stalk, sides: 6) { 0.0045 - 0.0015 * $0 }
        let head = begoniaFlower(bloom(Channels(240, 96, 112)))
        for cluster in 0 ..< Int.random(in: 2 ... 3, using: &rng) {
            let yaw = Float(cluster) * 2.2 + random(0 ... 0.6)
            let center = Grower.around(Vec3(0.05, Grower.soil + 0.17 * stretch, 0),
                                       yaw)
            for index in 0 ..< 5 {
                let turn = Float(index) * 1.25
                place(flower: head,
                      Pose(base: center + Grower.around(Vec3(0.013, 0, 0), turn),
                           yaw: turn, rise: 0.6, roll: random(-0.4 ... 0.4)),
                      sag: 0.45, delay: 0.8)
            }
        }
    }

    mutating func pelargonium() {
        if species.contains("роз") { return rose() }
        pot(.classic)
        let base = green(Channels(82, 140, 70))
        let design = LeafLook(outline: .round, aspect: 0.96,
                              veins: .palmate(7), base: base,
                              tip: lighter(base, 0.1), vein: lighter(base, 0.3),
                              pattern: .zone(Channels(110, 72, 44)), teeth: 9,
                              toothDepth: 0.12, scallops: true)
        let look = leafLook(design, rough: 0.8, height: 384)
        let leaf = leafMesh(design, length: 0.065,
                            bend: Sculpt.Bend(arch: 0.1, cup: 0.18,
                                              wave: 0.02, waves: 5),
                            rows: 16, columns: 13)
        let stalk = plainLook(Channels(110, 150, 80), rough: 0.8)
        let count = count(9 ... 14)
        var paths: [[Vec3]] = []
        var top: Float = 0
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963
            let reach = random(0.03 ... 0.08)
            let lift = random(0.05 ... 0.13) * stretch
            top = max(top, lift)
            let end = Grower.around(Vec3(reach, Grower.soil + lift, 0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.006, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.4, Grower.soil + lift, 0), yaw), end))
            kit.place(leaf, look,
                      Pose(base: end, yaw: yaw, rise: random(-0.05 ... 0.3),
                           size: random(0.85 ... 1.15)),
                      sag: 0.5, sway: 0.02, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
        let head = geraniumFlower(bloom(Channels(226, 40, 56)))
        for umbel in 0 ..< self.count(2 ... 4) {
            let yaw = Float(umbel) * 2.0 + random(0 ... 0.6)
            let center = Grower.around(Vec3(random(0.01 ... 0.05),
                                            Grower.soil + top + random(0.06 ... 0.12),
                                            0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.006, Grower.soil, 0), yaw),
                Grower.around(Vec3(0.01, (Grower.soil + center.y) / 2, 0), yaw),
                center))
            for index in 0 ..< Int.random(in: 12 ... 18, using: &rng) {
                let turn = Float(index) * 2.399_963
                let lift = random(0 ... 1)
                let out = Grower.around(Vec3(0.02 * (1 - lift * 0.6),
                                             0.01 * lift, 0), turn)
                paths.append([center, center + out * 0.5, center + out])
                place(flower: head,
                      Pose(base: center + out, yaw: turn,
                           rise: 0.4 + 1.0 * lift),
                      sag: 0.45, delay: 0.75 + lift * 0.2)
            }
        }
        stems(paths, look: stalk, sides: 5) { 0.003 - 0.001 * $0 }
    }

    /// Фиалка: два лепестка сверху меньше, три снизу больше, край
    /// волнистый, серединка темнее; пара пухлых жёлтых пыльников.
    mutating func violetFlower(_ colour: Channels) -> Head {
        let petal = LeafLook(outline: .broad, aspect: 1.0, veins: .fan(9),
                             base: colour, tip: lighter(colour, 0.12),
                             vein: darker(colour, 0.25), teeth: 7,
                             toothDepth: 0.03, scallops: true,
                             throat: darker(colour, 0.35), throatReach: 0.3,
                             glow: 0.15, mottle: 0.08)
        let length: Float = 0.014
        let ring = Grower.whorl(petal, length: length,
                                open: Float.pi / 2 - 0.08,
                                bend: Sculpt.Bend(arch: -0.06, fold: 0,
                                                  cup: -0.2, wave: 0.03,
                                                  waves: 2),
                                turns: [0.62, -0.62, Float.pi, Float.pi - 1.25,
                                        Float.pi + 1.25],
                                sizes: [0.82, 0.82, 1.05, 1, 1])
        var head = [Part(mesh: kit.add(ring), look: petalLook(petal))]
        var anthers = Mesh3D()
        for side: Float in [1, -1] {
            anthers.merge(Sculpt.ball(radius: 0.0022, segments: 8, rings: 5)
                .stretched(Vec3(1, 1.3, 0.9))
                .moved(by: Vec3(0.0022, 0, side * 0.0018)))
        }
        head.append(Part(mesh: kit.add(anthers),
                         look: plainLook(Channels(252, 214, 40), rough: 0.7)))
        let pistil = Sculpt.tube([Vec3(0, 0, 0), Vec3(0.005, 0.0015, 0)],
                                 sides: 4) { _ in 0.0005 }
        head.append(Part(mesh: kit.add(Grower.opaque(pistil)),
                         look: plainLook(Channels(120, 150, 90), rough: 0.6)))
        return head
    }

    /// Мужской цветок бегонии: два широких лепестка сверху и снизу, два
    /// узких по бокам, в середине — жёлтый пучок тычинок.
    mutating func begoniaFlower(_ colour: Channels) -> Head {
        let petal = LeafLook(outline: .broad, aspect: 1.05, veins: .fan(7),
                             base: colour, tip: lighter(colour, 0.2),
                             vein: darker(colour, 0.12),
                             throat: lighter(colour, 0.35), throatReach: 0.35,
                             glow: 0.3, mottle: 0.06)
        let ring = Grower.whorl(petal, length: 0.017,
                                open: Float.pi / 2 - 0.08,
                                bend: Sculpt.Bend(arch: -0.04, fold: 0,
                                                  cup: -0.15),
                                turns: [0, Float.pi, Float.pi / 2,
                                        -Float.pi / 2],
                                sizes: [1, 1, 0.62, 0.62])
        var head = [Part(mesh: kit.add(ring), look: petalLook(petal))]
        var cluster = Mesh3D()
        for index in 0 ..< 14 {
            let turn = Float(index) * 2.399_963
            let out = 0.0022 * (Float(index) / 14).squareRoot()
            cluster.merge(Sculpt.ball(radius: 0.0011, segments: 6, rings: 4)
                .moved(by: Vec3(0.0022 - out * 0.4, out * cos(turn),
                                out * sin(turn))))
        }
        head.append(Part(mesh: kit.add(cluster),
                         look: plainLook(Channels(250, 212, 50), rough: 0.8)))
        return head
    }

    /// Цветок пеларгонии в зонтике: два верхних лепестка уже и с тёмными
    /// жилками-дорожками, три нижних шире; короткие тычинки.
    mutating func geraniumFlower(_ colour: Channels) -> Head {
        let upper = LeafLook(outline: .broad, aspect: 0.78, veins: .fan(7),
                             base: colour, tip: colour,
                             vein: darker(colour, 0.45),
                             throat: lighter(colour, 0.45), throatReach: 0.28,
                             glow: 0.12, mottle: 0.08)
        let lower = LeafLook(outline: .broad, aspect: 0.95, veins: .fan(7),
                             base: colour, tip: lighter(colour, 0.08),
                             vein: darker(colour, 0.12),
                             throat: lighter(colour, 0.45), throatReach: 0.25,
                             glow: 0.12, mottle: 0.08)
        let open = Float.pi / 2 - 0.12
        let bend = Sculpt.Bend(arch: -0.05, fold: 0, cup: -0.15, wave: 0.02,
                               waves: 2)
        let top = Grower.whorl(upper, length: 0.012, open: open, bend: bend,
                               turns: [0.5, -0.5], shift: 0.0004)
        let bottom = Grower.whorl(lower, length: 0.013, open: open, bend: bend,
                                  turns: [Float.pi, Float.pi - 1.2,
                                          Float.pi + 1.2])
        var head = [Part(mesh: kit.add(top), look: petalLook(upper)),
                    Part(mesh: kit.add(bottom), look: petalLook(lower))]
        head += stamens(6, length: 0.0035, spread: 0.0012, anther: 0.0005,
                        thread: lighter(colour, 0.5),
                        pollen: Channels(214, 110, 50))
        return head
    }

    /// Тюльпан — бокал: три наружных и три внутренних лепестка сходятся
    /// кверху, на донце тёмное пятно, внутри — тёмные тычинки.
    mutating func tulipFlower(_ colour: Channels) -> Head {
        let outer = LeafLook(outline: .tepal, aspect: 0.66, veins: .fan(9),
                             base: colour, tip: lighter(colour, 0.06),
                             vein: darker(colour, 0.12),
                             throat: .mix(colour, Channels(250, 210, 70), 0.6),
                             throatReach: 0.32, glow: 0.12, mottle: 0.06)
        var inner = outer
        inner.throat = Channels(60, 40, 40)
        inner.throatReach = 0.22
        let length: Float = 0.052
        let shell = Grower.whorl(outer, length: length, open: 0.62,
                                 bend: Sculpt.Bend(arch: 0.42, fold: 0,
                                                   cup: -0.75),
                                 turns: Grower.evenly(3), rows: 16,
                                 columns: 11)
        let core = Grower.whorl(inner, length: length * 0.96, open: 0.52,
                                bend: Sculpt.Bend(arch: 0.42, fold: 0,
                                                  cup: -0.8),
                                turns: Grower.evenly(3, offset: 0.5),
                                shift: -0.001, rows: 16, columns: 11)
        var head = [Part(mesh: kit.add(shell),
                         look: petalLook(outer, rough: 0.35, gloss: 0.3)),
                    Part(mesh: kit.add(core),
                         look: petalLook(inner, rough: 0.35, gloss: 0.3))]
        head += stamens(6, length: 0.02, spread: 0.006, anther: 0.0018,
                        thread: Channels(70, 60, 50),
                        pollen: Channels(46, 36, 40))
        head.append(dome(0.0035, color: Channels(150, 170, 90), squash: 1.6))
        return head
    }

    /// Цветок кактуса — воронка из трёх кругов узких лепестков, к краю
    /// ярче, к горлу светлее; пучок сливочных тычинок и звёздочка рыльца.
    mutating func cactusFlower(_ colour: Channels) -> Head {
        let petal = LeafLook(outline: .petal, aspect: 0.32, veins: .fan(3),
                             base: lighter(colour, 0.35), tip: colour,
                             vein: darker(colour, 0.1),
                             throat: Channels(250, 236, 220),
                             throatReach: 0.4, glow: 0.2, mottle: 0.06)
        let look = petalLook(petal, rough: 0.4, gloss: 0.15)
        let bend = Sculpt.Bend(arch: -0.18, fold: 0.1, cup: -0.2)
        var funnel = Grower.whorl(petal, length: 0.024, open: 1.2, bend: bend,
                                  turns: Grower.evenly(14))
        funnel.merge(Grower.whorl(petal, length: 0.022, open: 0.9, bend: bend,
                                  turns: Grower.evenly(14, offset: 0.5),
                                  shift: 0.001))
        funnel.merge(Grower.whorl(petal, length: 0.018, open: 0.6, bend: bend,
                                  turns: Grower.evenly(10, offset: 0.25),
                                  shift: 0.002))
        var head = [Part(mesh: kit.add(funnel), look: look)]
        head += stamens(26, length: 0.008, spread: 0.0035, anther: 0.0006,
                        thread: Channels(250, 244, 220),
                        pollen: Channels(250, 222, 120))
        var stigma = Mesh3D()
        for index in 0 ..< 6 {
            let turn = Float(index) * Float.pi / 3
            stigma.merge(Sculpt.ball(radius: 0.0008, segments: 6, rings: 4)
                .stretched(Vec3(0.6, 1.6, 1))
                .moved(by: Vec3(0.0105, 0.0011 * cos(turn),
                                0.0011 * sin(turn))))
        }
        head.append(Part(mesh: kit.add(stigma),
                         look: plainLook(Channels(200, 220, 120), rough: 0.7)))
        return head
    }

    /// Роза: прямые стебли с шипами, перистые листья из пяти зубчатых
    /// листочков, на макушках — цветы, на боковых веточках — бутоны.
    mutating func rose() {
        pot(.classic)
        let base = green(Channels(40, 86, 46))
        let design = LeafLook(outline: .ovate, aspect: 0.6, veins: .pinnate(6),
                              base: base, tip: lighter(base, 0.06),
                              vein: lighter(base, 0.25), teeth: 14,
                              toothDepth: 0.07)
        let look = leafLook(design, rough: 0.3, gloss: 0.45, height: 256)
        let leaflet = leafMesh(design, length: 0.028,
                               bend: Sculpt.Bend(arch: 0.1, fold: 0.22),
                               rows: 12, columns: 9)
        let stalk = plainLook(Channels(66, 104, 56), rough: 0.6)
        let thorn = plainLook(Channels(150, 84, 64), rough: 0.5)
        let colour = bloom(Channels(196, 22, 48))
        let head = roseFlower(colour)
        let bud = roseBud(colour)
        var paths: [[Vec3]] = []
        var thorns = Mesh3D()
        let count = count(3 ... 5)
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963 + random(0 ... 0.4)
            let height = random(0.2 ... 0.3) * stretch
            let lean = random(0.025 ... 0.07)
            let path = Sculpt.curve(
                Grower.around(Vec3(0.006, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(lean * 0.3, Grower.soil + height * 0.55, 0),
                              yaw),
                Grower.around(Vec3(lean, Grower.soil + height, 0), yaw),
                steps: 14)
            paths.append(path)
            place(flower: head,
                  Pose(base: path[14], yaw: yaw,
                       rise: .pi / 2 - random(0.05 ... 0.4)),
                  sag: 0.35, delay: 0.8 + 0.03 * Float(index))
            for node in [4, 7, 10] {
                let turn = yaw + Float(node) * 2.2
                leaf(at: path[node], turn: turn, leaflet: leaflet, look: look,
                     stalk: &paths, delay: Float(node) / 14)
            }
            // Шип от оси стебля наружу и чуть вниз: основание прячется в
            // стебле, торчит только кончик.
            for step in stride(from: 2, to: 13, by: 2) {
                thorns.merge(Sculpt.spike(radius: 0.0013, height: 0.0058,
                                          sides: 4)
                    .posed(Pose(base: path[step], yaw: Float(step) * 1.9 + yaw,
                                rise: -0.35 - .pi / 2)))
            }
            if index < 2 {
                let fork = path[9]
                let side = yaw + (index == 0 ? 1.1 : -1.1)
                let tip = fork + Grower.around(Vec3(0.035, 0.045, 0), side)
                paths.append(Sculpt.curve(fork, fork + Grower.around(
                    Vec3(0.012, 0.02, 0), side), tip, steps: 5))
                place(flower: bud, Pose(base: tip, yaw: side, rise: 1.25),
                      sag: 0.3, delay: 0.9)
            }
        }
        kit.put(thorns, thorn)
        stems(paths, look: stalk, sides: 7) { 0.0034 - 0.0014 * $0 }
    }

    /// Перистый лист розы: черешок и пять листочков — две пары и верхний.
    private mutating func leaf(at node: Vec3, turn: Float, leaflet: Int,
                               look: Int, stalk: inout [[Vec3]],
                               delay: Float) {
        let reach: Float = 0.05
        let end = node + Grower.around(Vec3(reach, reach * 0.35, 0), turn)
        let rachis = Sculpt.curve(node, node + Grower.around(
            Vec3(reach * 0.5, reach * 0.3, 0), turn), end, steps: 6)
        stalk.append(rachis)
        let phase = random(0 ... 1)
        for (step, size) in [(2, Float(0.8)), (4, Float(0.95))] {
            for side: Float in [1, -1] {
                kit.place(leaflet, look,
                          Pose(base: rachis[step], yaw: turn + side * 1.2,
                               rise: random(-0.1 ... 0.2),
                               roll: side * 0.25, size: size),
                          sag: 0.5, sway: 0.02, delay: delay, phase: phase)
            }
        }
        kit.place(leaflet, look,
                  Pose(base: end, yaw: turn, rise: random(0 ... 0.25),
                       size: 1.05),
                  sag: 0.5, sway: 0.02, delay: delay, phase: phase)
    }

    /// Цветок розы: спираль лепестков золотым углом. Внутренние сомкнуты и
    /// завёрнуты к середине, наружные раскрыты и отогнуты кончиками; снизу
    /// — чашелистики.
    mutating func roseFlower(_ colour: Channels) -> Head {
        let petal = LeafLook(outline: .broad, aspect: 1.12, veins: .fan(11),
                             base: colour, tip: lighter(colour, 0.05),
                             vein: darker(colour, 0.18),
                             throat: .mix(colour, Channels(250, 214, 120), 0.45),
                             throatReach: 0.32, glow: 0.06, mottle: 0.08)
        var mesh = Mesh3D()
        let petals = 19
        for index in 0 ..< petals {
            let k = Float(index) / Float(petals - 1)
            let bend = Sculpt.Bend(arch: 0.32 - 0.62 * k, fold: 0,
                                   cup: -1.0 + 0.6 * k)
            mesh.merge(Grower.whorl(petal, length: 0.017 + 0.017 * pow(k, 0.7),
                                    open: 0.18 + 1.12 * pow(k, 1.3),
                                    bend: bend,
                                    turns: [Float(index) * 2.399_963],
                                    shift: 0.004 * (1 - k),
                                    root: 0.0015 + 0.004 * k,
                                    rows: 12, columns: 11))
        }
        return [Part(mesh: kit.add(mesh),
                     look: petalLook(petal, rough: 0.45, gloss: 0.1)),
                sepals(5, length: 0.02, color: Channels(58, 104, 58))]
    }

    /// Бутон: пять сомкнутых лепестков, чашелистики обнимают их снизу.
    mutating func roseBud(_ colour: Channels) -> Head {
        let petal = LeafLook(outline: .broad, aspect: 1.1, veins: .fan(7),
                             base: colour, tip: darker(colour, 0.1),
                             vein: darker(colour, 0.2), mottle: 0.08)
        let mesh = Grower.whorl(petal, length: 0.017, open: 0.22,
                                bend: Sculpt.Bend(arch: 0.2, fold: 0, cup: -1.1),
                                turns: Grower.evenly(5), root: 0.002,
                                rows: 10, columns: 9)
        return [Part(mesh: kit.add(mesh), look: petalLook(petal, rough: 0.45)),
                sepals(5, length: 0.016, color: Channels(58, 104, 58),
                       open: 0.5)]
    }

    mutating func herbs() {
        pot(.cylinder)
        let mint = species.contains("мят")
        let rosemary = species.contains("розмарин")
        let base = green(rosemary ? Channels(64, 100, 74)
            : (mint ? Channels(72, 146, 76) : Channels(74, 156, 62)))
        let design = LeafLook(outline: rosemary ? .strap : .ovate,
                              aspect: rosemary ? 0.14 : (mint ? 0.55 : 0.62),
                              veins: rosemary ? .none : .pinnate(5), base: base,
                              tip: lighter(base, 0.1), vein: lighter(base, 0.3),
                              teeth: rosemary ? 0 : (mint ? 9 : 7),
                              toothDepth: mint ? 0.12 : 0.05)
        let look = leafLook(design, rough: rosemary ? 0.7 : 0.35,
                            gloss: rosemary ? 0 : 0.3, height: 256)
        let leaf = leafMesh(design, length: rosemary ? 0.022 : 0.045,
                            bend: Sculpt.Bend(arch: 0.15, fold: 0.2, cup: 0.1),
                            rows: 12, columns: 7)
        let stalk = plainLook(rosemary ? Channels(110, 100, 70)
                              : lighter(base, 0.15), rough: 0.7)
        let count = count(5 ... 8)
        var paths: [[Vec3]] = []
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.3 ... 0.3))
                / Float(count)
            let height = random(0.1 ... 0.2) * stretch
            let lean = random(0.01 ... 0.04)
            let path = Sculpt.curve(
                Grower.around(Vec3(0.006, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(lean * 0.3, Grower.soil + height * 0.6, 0), yaw),
                Grower.around(Vec3(lean, Grower.soil + height, 0), yaw), steps: 12)
            paths.append(path)
            let nodes = rosemary ? 11 : 6
            for node in 0 ..< nodes {
                let t = 0.2 + 0.8 * Float(node) / Float(nodes - 1)
                let at = path[min(Int((t * 12).rounded()), 12)]
                let turn = yaw + Float(node) * Float.pi / 2
                for side: Float in [1, -1] {
                    kit.place(leaf, look,
                              Pose(base: at, yaw: turn + (side > 0 ? 0 : .pi),
                                   rise: rosemary ? 0.9 : random(0.2 ... 0.6),
                                   roll: side * 0.2,
                                   size: rosemary ? 1
                                       : 0.7 + 0.5 * sin(Float.pi * t)),
                              sag: 0.55, sway: 0.02,
                              delay: (Float(index) + t) / Float(count + 1),
                              phase: random(0 ... 1))
                }
            }
        }
        stems(paths, look: stalk, sides: 5) { 0.003 - 0.0012 * $0 }
    }

    mutating func tulip() {
        pot(.classic)
        let base = green(Channels(100, 140, 110))
        let design = LeafLook(outline: .lanceolate, aspect: 0.3,
                              veins: .parallel(5), base: base,
                              tip: lighter(base, 0.1), vein: lighter(base, 0.2))
        let look = leafLook(design, rough: 0.5, gloss: 0.15)
        let leaf = leafMesh(design, length: 0.16,
                            bend: Sculpt.Bend(arch: 0.35, fold: 0.35,
                                              wave: 0.015, waves: 3))
        let head = tulipFlower(bloom(Channels(226, 38, 52)))
        let stalk = plainLook(base, rough: 0.5)
        var stems: [[Vec3]] = []
        for index in 0 ..< count(3 ... 5) {
            let yaw = Float(index) * 2.399_963 + random(0 ... 0.4)
            let height = random(0.18 ... 0.28) * stretch
            let end = Grower.around(Vec3(random(0.01 ... 0.04),
                                         Grower.soil + height, 0), yaw)
            stems.append(Sculpt.curve(
                Grower.around(Vec3(0.008, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(0.012, Grower.soil + height * 0.5, 0), yaw),
                end))
            place(flower: head, Pose(base: end, yaw: yaw,
                                     rise: .pi / 2 - random(0.02 ... 0.15)),
                  sag: 0.5, delay: 0.7)
            for leafIndex in 0 ..< 2 {
                let turn = yaw + Float(leafIndex) * Float.pi + random(-0.3 ... 0.3)
                kit.place(leaf, look,
                          Pose(base: Grower.around(Vec3(0.012, Grower.soil, 0),
                                                   turn),
                               yaw: turn, rise: random(0.85 ... 1.2),
                               roll: random(-0.3 ... 0.3),
                               size: random(0.85 ... 1.1)),
                          sag: 0.45, sway: 0.015, delay: Float(index) * 0.15,
                          phase: random(0 ... 1))
            }
        }
        self.stems(stems, look: stalk, sides: 7) { _ in 0.0032 }
    }
}
