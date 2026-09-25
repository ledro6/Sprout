import Foundation

/// Рецепты суккулентов и кактусов: мясистые листья, розетки, ребристые
/// колонны и лепёшки с колючками.
extension Grower {
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
        var funnel = whorl(petal, length: 0.024, open: 1.2, bend: bend,
                                  turns: Grower.evenly(14))
        funnel.merge(whorl(petal, length: 0.022, open: 0.9, bend: bend,
                                  turns: Grower.evenly(14, offset: 0.5),
                                  shift: 0.001))
        funnel.merge(whorl(petal, length: 0.018, open: 0.6, bend: bend,
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
        if grows(.kalanchoe, named: "каланхоэ") || traits?.flower != nil {
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

    /// Каланхоэ: низкий кустик мясистых городчатых листьев парами крест-
    /// накрест, над ним — плотные шапки мелких цветов.
    mutating func kalanchoe() {
        pot(.classic)
        let base = green(Channels(44, 110, 50))
        let design = LeafLook(outline: .oval, aspect: 0.74, veins: .pinnate(3),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.2),
                              margin: Channels(150, 60, 50), marginWidth: 0.015,
                              teeth: 7, toothDepth: 0.06, scallops: true,
                              mottle: 0.1)
        let look = leafLook(design, rough: 0.3, gloss: 0.5, height: 256)
        let leaf = leafMesh(design, length: 0.05,
                            bend: Sculpt.Bend(arch: 0.08, fold: 0.06, cup: 0.06),
                            rows: 12, columns: 9)
        let stalk = plainLook(Channels(96, 130, 70), rough: 0.6)
        let colour = bloom(Channels(238, 64, 48))
        let petal = LeafLook(outline: .petal, aspect: 0.8, veins: .fan(3),
                             base: colour, tip: lighter(colour, 0.12),
                             vein: darker(colour, 0.15),
                             throat: Channels(252, 214, 90), throatReach: 0.3,
                             glow: 0.2, mottle: 0.06)
        let ring = whorl(petal, length: 0.0075, open: Float.pi / 2 - 0.25,
                         bend: Sculpt.Bend(arch: -0.1, fold: 0.05, cup: -0.1),
                         turns: Grower.evenly(4), rows: 5, columns: 5)
        let blossom: Head = [Part(mesh: kit.add(ring), look: petalLook(petal)),
                             dome(0.0016, color: Channels(252, 214, 90),
                                  squash: 0.8)]
        var paths: [[Vec3]] = []
        let count = count(4 ... 6)
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.2 ... 0.2))
                / Float(count)
            let height = random(0.06 ... 0.1) * stretch
            let reach = random(0.02 ... 0.05)
            let path = Sculpt.curve(
                Grower.around(Vec3(0.005, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.4, Grower.soil + height * 0.6, 0),
                              yaw),
                Grower.around(Vec3(reach, Grower.soil + height, 0), yaw),
                steps: 8)
            paths.append(path)
            for pair in 0 ..< 4 {
                let at = path[2 + pair * 2]
                let turn = yaw + Float(pair) * Float.pi / 2
                for side: Float in [1, -1] {
                    kit.place(leaf, look,
                              Pose(base: at, yaw: turn + (side > 0 ? 0 : .pi),
                                   rise: 0.15 + 0.2 * Float(pair),
                                   roll: random(-0.15 ... 0.15),
                                   size: 1.05 - 0.12 * Float(pair)),
                              sag: 0.3, sway: 0.008,
                              delay: Float(index) / Float(count),
                              phase: random(0 ... 1))
                }
            }
            // Цветонос выше листьев и шапка цветов на нём.
            let top = path[8]
            let crown = top + Grower.around(Vec3(0.01, random(0.05 ... 0.08), 0),
                                            yaw)
            paths.append(Sculpt.curve(top, (top + crown) / 2
                + Vec3(0, 0.01, 0), crown, steps: 6))
            for step in 0 ..< 16 {
                let turn = Float(step) * 2.399_963
                let lift = 0.3 + 1.1 * Float(step % 6) / 5
                let out = Vec3(cos(lift) * cos(turn), sin(lift),
                               cos(lift) * sin(turn)) * 0.013
                place(flower: blossom,
                      Pose(base: crown + out, yaw: atan2(-out.z, out.x),
                           rise: lift),
                      sag: 0.3, delay: 0.8 + 0.1 * Float(index) / Float(count))
            }
        }
        stems(paths, look: stalk, sides: 6) { 0.003 - 0.0012 * $0 }
    }

    /// Хавортия: тугая розетка тёмных треугольных листьев в белых
    /// бугорках полосками — «зебра».
    mutating func haworthia() {
        pot(.bowl, top: .gravel)
        let base = green(Channels(38, 82, 54))
        var skin = Leafart.skin(base, seed: seed)
        for row in 0 ..< 16 {
            let v = 0.06 + Float(row) * 0.056
            var u = random(0 ... 0.04)
            while u < 1 {
                skin.disc(SIMD2(u, v + random(-0.008 ... 0.008)),
                          radius: random(0.012 ... 0.018), squash: 0.45,
                          Ink(0.93, 0.95, 0.9, 0.95))
                u += random(0.035 ... 0.06)
            }
        }
        let look = pictureLook(skin, rough: 0.55, gloss: 0.1, wilts: true)
        func blade(_ t: Float) -> Float { min(1, t * 6) * pow(1 - t, 0.85) }
        let leaves = (0 ..< 3).map { variant in
            kit.add(Sculpt.fleshy(length: 0.06 + Float(variant) * 0.008,
                                  width: 0.02, thickness: 0.011, arch: -0.12,
                                  rows: 14, sides: 12, shape: blade))
        }
        let count = count(18 ... 26)
        for index in 0 ..< count {
            let inner = Float(index) / Float(count)
            let yaw = Float(index) * 2.399_963
            kit.place(leaves[index % 3], look,
                      Pose(base: Grower.around(Vec3(0.004 + 0.012 * (1 - inner),
                                                    Grower.soil, 0), yaw),
                           yaw: yaw, rise: 0.7 + 0.75 * inner,
                           roll: random(-0.2 ... 0.2),
                           size: 1.05 - 0.4 * inner),
                      sag: 0.2, sway: 0.004, delay: inner, phase: random(0 ... 1))
        }
    }

    /// Опунция: плоские лепёшки одна на другой, в ареолах с колючками;
    /// иногда — жёлтый цветок на верхней.
    mutating func opuntia() {
        pot(.classic, top: .gravel)
        let base = green(Channels(92, 146, 84))
        let look = pictureLook(Leafart.skin(base, seed: seed), rough: 0.5,
                               gloss: 0.12, wilts: true)
        let areoleLook = plainLook(Channels(226, 214, 170), rough: 0.9)
        let spineLook = plainLook(Channels(238, 230, 200), rough: 0.5)
        func round(_ t: Float) -> Float { pow(sin(Float.pi * pow(t, 0.8)), 0.62) }
        let length: Float = 0.1
        let width: Float = 0.072
        let thick: Float = 0.013
        let pad = Sculpt.fleshy(length: length, width: width, thickness: thick,
                                arch: 0, rows: 18, sides: 18, shape: round)
        let first = Pose(base: Vec3(0, Grower.soil - 0.012, 0),
                         yaw: random(0 ... 3), rise: 1.5)
        var poses = [first]
        for index in 0 ..< Int.random(in: 2 ... 3, using: &rng) {
            let side = Float(index) - 0.9
            poses.append(Pose(base: first.place(Vec3(length * 0.9, 0,
                                                     side * width * 0.28)),
                              yaw: first.yaw + random(-0.5 ... 0.5),
                              rise: 1.5 - side * 0.5 + random(-0.1 ... 0.1),
                              size: random(0.7 ... 0.85)))
        }
        if chance(0.6) {
            let parent = poses[1]
            poses.append(Pose(base: parent.place(Vec3(length * 0.9, 0, 0)),
                              yaw: parent.yaw + random(-0.6 ... 0.6),
                              rise: 1.4 + random(-0.2 ... 0.2), size: 0.6))
        }
        var body = Mesh3D()
        var areoles = Mesh3D()
        var spines = Mesh3D()
        for pose in poses {
            body.merge(pad.posed(pose))
            // Ареолы на обеих сторонах лепёшки — рядами со сдвигом.
            for row in 1 ..< 8 {
                let t = Float(row) / 8
                let half = width / 2 * round(t)
                let deep = thick / 2 * pow(round(t), 0.8)
                let columns = max(Int(half * 0.8 / 0.012), 1)
                for column in -columns ... columns {
                    let z = Float(column) * half * 0.8 / Float(columns)
                        + (row.isMultiple(of: 2) ? 0.004 : -0.004)
                    let across = min(abs(z) / max(half, 1e-4), 1)
                    for face: Float in [1, -1] {
                        let rise = deep * (1 - across * across).squareRoot()
                            * (face > 0 ? 0.55 : 1)
                        let point = pose.place(Vec3(t * length, face * rise, z))
                        areoles.merge(Sculpt.ball(radius: 0.0016 * pose.size,
                                                  segments: 5, rings: 3)
                            .moved(by: point))
                        guard chance(0.5) else { continue }
                        let out = pose.turn(Vec3(0, face, 0)).unit
                        spines.merge(Sculpt.spike(radius: 0.0004,
                                                  height: random(0.005 ... 0.009),
                                                  sides: 3)
                            .posed(Pose(base: point,
                                        yaw: atan2(-out.z, out.x),
                                        rise: asin(min(max(out.y, -1), 1))
                                            - .pi / 2)))
                    }
                }
            }
        }
        kit.put(body, look)
        kit.put(areoles, areoleLook)
        kit.put(spines, spineLook)
        if traits?.flower != nil || chance(0.5) {
            let crown = poses[poses.count - 1]
            place(flower: cactusFlower(bloom(Channels(250, 206, 60))),
                  Pose(base: crown.place(Vec3(length * 0.95, 0, 0)),
                       yaw: crown.yaw, rise: crown.rise),
                  sag: 0, delay: 0.9)
        }
    }
}
