import Foundation

/// Рецепты лиственных видов: листья-карточки с рисунком на черешках и
/// стеблях, розетки, пальмы, лианы, травы и цитрус.
extension Grower {
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
        let hoya = grows(.hoya, named: "хойя")
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
        if hoya { umbels(on: vines) }
    }

    /// Зонтики хойи: полушарие восковых звёздочек с красной серединкой.
    /// Сетки лепестков мелкие: звёздочек десятки.
    private mutating func umbels(on vines: [[Vec3]]) {
        let colour = bloom(Channels(246, 220, 226))
        let petal = LeafLook(outline: .petal, aspect: 0.8, veins: .none,
                             base: colour, tip: lighter(colour, 0.3),
                             vein: colour, glow: 0.35, mottle: 0.03)
        let ring = whorl(petal, length: 0.0062, open: Float.pi / 2 - 0.05,
                         bend: Sculpt.Bend(arch: 0.1, fold: 0.25),
                         turns: Grower.evenly(5), rows: 5, columns: 5)
        let star: Head = [Part(mesh: kit.add(ring), look: petalLook(petal)),
                          dome(0.0015, color: Channels(176, 34, 64),
                               squash: 0.8)]
        for (index, vine) in vines.prefix(2).enumerated() {
            let center = vine[min(10 + index * 3, vine.count - 1)]
            for step in 0 ..< 14 {
                let turn = Float(step) * 2.399_963
                let lift = 0.35 + 0.9 * Float(step % 5) / 4
                let out = Vec3(cos(lift) * cos(turn), sin(lift),
                               cos(lift) * sin(turn)) * 0.011
                place(flower: star,
                      Pose(base: center + out, yaw: atan2(-out.z, out.x),
                           rise: lift),
                      sag: 0.4, delay: 0.85)
            }
        }
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

    mutating func herbs() {
        pot(.cylinder)
        let mint = grows(.mint, named: "мят")
        let rosemary = grows(.rosemary, named: "розмарин")
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

    /// Калатея: длинные черешки и листья-овалы, расписанные ёлочкой; к
    /// вечеру листья поднимаются — поэтому они и здесь смотрят вверх.
    mutating func calathea() {
        pot(.cylinder)
        let base = green(Channels(128, 170, 104))
        let deep = darker(green(Channels(40, 92, 54)), 0.1)
        let design = LeafLook(outline: .oval, aspect: 0.44, veins: .pinnate(13),
                              base: base, tip: lighter(base, 0.06),
                              vein: lighter(base, 0.2), margin: deep,
                              marginWidth: 0.035, pattern: .feather(deep, 7))
        let look = leafLook(design, rough: 0.45, gloss: 0.25)
        let leaf = leafMesh(design, length: 0.13,
                            bend: Sculpt.Bend(arch: 0.1, fold: 0.1, wave: 0.012,
                                              waves: 5))
        let stalk = plainLook(Channels(112, 96, 80), rough: 0.5)
        let count = count(9 ... 14)
        var paths: [[Vec3]] = []
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963
            let reach = random(0.02 ... 0.05)
            let lift = random(0.08 ... 0.2) * stretch
            let end = Grower.around(Vec3(reach, Grower.soil + lift, 0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.005, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.2, Grower.soil + lift * 0.85, 0),
                              yaw),
                end))
            kit.place(leaf, look,
                      Pose(base: end, yaw: yaw, rise: random(0.55 ... 1.05),
                           roll: random(-0.35 ... 0.35),
                           size: random(0.8 ... 1.15)),
                      sag: 0.7, sway: 0.02, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
        stems(paths, look: stalk, sides: 6) { 0.0028 - 0.0008 * $0 }
    }

    /// Пилея: стволик и листья-монетки на длинных черешках, черешок входит
    /// в середину пластины.
    mutating func pilea() {
        pot(.bowl)
        let base = green(Channels(66, 140, 60))
        let design = LeafLook(outline: .oval, aspect: 0.96, veins: .pinnate(4),
                              base: base, tip: lighter(base, 0.05),
                              vein: lighter(base, 0.3), mottle: 0.12)
        let look = leafLook(design, rough: 0.3, gloss: 0.45, height: 256)
        let size: Float = 0.06
        let coin = kit.add(Sculpt.card(length: size, width: size * design.aspect,
                                       bend: Sculpt.Bend(arch: 0.02, fold: 0.04,
                                                         cup: 0.16),
                                       rows: dense(14), columns: dense(13),
                                       hug: { Leafart.half(design.outline, $0) })
            .moved(by: Vec3(-size / 2, 0, 0)))
        let stalk = plainLook(Channels(110, 150, 84), rough: 0.6)
        let height = random(0.08 ... 0.13) * stretch
        let lean = random(-0.01 ... 0.01)
        let trunk = Sculpt.curve(Vec3(0, Grower.soil - 0.006, 0),
                                 Vec3(lean, Grower.soil + height * 0.5, 0),
                                 Vec3(lean * 2, Grower.soil + height, 0),
                                 steps: 12)
        var petioles: [[Vec3]] = []
        let count = count(12 ... 17)
        for index in 0 ..< count {
            let t = 0.15 + 0.85 * Float(index) / Float(count)
            let on = trunk[min(Int((t * 12).rounded()), 12)]
            let yaw = Float(index) * 2.399_963
            let reach = random(0.05 ... 0.08) * (1.1 - 0.4 * t)
            let end = on + Grower.around(
                Vec3(reach, reach * random(0.1 ... 0.5), 0), yaw)
            petioles.append(Sculpt.curve(on, on + Grower.around(
                Vec3(reach * 0.5, reach * 0.35, 0), yaw), end, steps: 6))
            kit.place(coin, look,
                      Pose(base: end + Vec3(0, 0.002, 0),
                           yaw: yaw + random(-0.3 ... 0.3),
                           rise: random(-0.05 ... 0.35),
                           roll: random(-0.25 ... 0.25),
                           size: random(0.75 ... 1.15) * (1.15 - 0.35 * t)),
                      sag: 0.5, sway: 0.02, delay: t, phase: random(0 ... 1))
        }
        stems([trunk], look: stalk, sides: 8) { 0.005 - 0.002 * $0 }
        stems(petioles, look: stalk, sides: 5) { _ in 0.0014 }
    }

    /// Алоказия: несколько больших листьев-стрел с белыми жилками на
    /// высоких полосатых черешках; кончик свисает вниз.
    mutating func alocasia() {
        pot(.cylinder)
        let base = green(Channels(26, 62, 42))
        let design = LeafLook(outline: .heart, aspect: 0.56, veins: .pinnate(5),
                              base: base, tip: lighter(base, 0.05),
                              vein: Channels(222, 236, 222),
                              margin: Channels(206, 224, 206), marginWidth: 0.012,
                              mottle: 0.08)
        let look = leafLook(design, rough: 0.28, gloss: 0.6, height: 768)
        let leaf = leafMesh(design, length: 0.2,
                            bend: Sculpt.Bend(arch: 0.12, fold: 0.1, cup: -0.02,
                                              wave: 0.02, waves: 3),
                            rows: 26, columns: 13)
        let stalk = pictureLook(Leafart.bark(Channels(150, 160, 110),
                                             dark: Channels(60, 64, 44),
                                             rings: 24, seed: seed), rough: 0.45)
        let count = count(3 ... 5)
        var paths: [[Vec3]] = []
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.2 ... 0.2))
                / Float(count)
            let reach = random(0.03 ... 0.08)
            let lift = random(0.18 ... 0.32) * stretch
            let end = Grower.around(Vec3(reach, Grower.soil + lift, 0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.008, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.2, Grower.soil + lift * 0.8, 0),
                              yaw),
                end))
            kit.place(leaf, look,
                      Pose(base: end, yaw: yaw, rise: random(-0.55 ... -0.2),
                           roll: random(-0.2 ... 0.2),
                           size: random(0.85 ... 1.15)),
                      sag: 0.5, sway: 0.02, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
        stems(paths, look: stalk, sides: 8) { 0.006 - 0.0025 * $0 }
    }

    /// Юкка: стволы в кольцах коры, на макушке — розетка жёстких мечей;
    /// нижние отгибаются, верхние торчат.
    mutating func yucca() {
        pot(.cylinder)
        let base = green(Channels(44, 96, 62))
        let design = LeafLook(outline: .sword, aspect: 0.085, veins: .parallel(2),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.15),
                              margin: lighter(base, 0.3), marginWidth: 0.03)
        let look = leafLook(design, rough: 0.45, gloss: 0.25)
        let leaves = (0 ..< 3).map { _ in
            leafMesh(design, length: random(0.15 ... 0.19),
                     bend: Sculpt.Bend(arch: random(0.02 ... 0.12), fold: 0.3,
                                       twist: random(-0.2 ... 0.2)),
                     rows: 22, columns: 5)
        }
        let bark = pictureLook(Leafart.bark(Channels(150, 132, 104),
                                            dark: Channels(100, 86, 66),
                                            rings: 22, seed: seed), rough: 0.85)
        var canes: [[Vec3]] = []
        for index in 0 ..< Int.random(in: 1 ... 2, using: &rng) {
            let yaw = Float(index) * 2.6 + random(0 ... 0.6)
            let height = (0.16 + 0.1 * Float(index) + random(0 ... 0.06))
                * stretch
            let cane = Sculpt.curve(
                Grower.around(Vec3(0.012 * Float(index), Grower.soil - 0.01, 0),
                              yaw),
                Grower.around(Vec3(0.018, Grower.soil + height * 0.5, 0), yaw),
                Grower.around(Vec3(0.022 + random(0 ... 0.02),
                                   Grower.soil + height, 0), yaw))
            canes.append(cane)
            let crown = cane[cane.count - 1]
            let count = count(22 ... 30)
            for leafIndex in 0 ..< count {
                let inner = Float(leafIndex) / Float(count)
                kit.place(leaves[leafIndex % 3], look,
                          Pose(base: crown + Vec3(0, inner * 0.03, 0),
                               yaw: Float(leafIndex) * 2.399_963,
                               rise: -0.15 + 1.5 * inner,
                               roll: random(-0.3 ... 0.3),
                               size: 1.05 - 0.35 * inner),
                          sag: 0.2, sway: 0.012,
                          delay: Float(index) * 0.25 + inner * 0.5,
                          phase: random(0 ... 1))
            }
        }
        stems(canes, look: bark, sides: 10) { 0.014 - 0.004 * $0 }
    }

    /// Лимонное дерево: ствол, ветки облаком лаковых листьев, лимоны висят
    /// под листвой, между ними — белые звёздочки цветов.
    mutating func citrus() {
        pot(.classic)
        let base = green(Channels(34, 96, 44))
        let design = LeafLook(outline: .oval, aspect: 0.5, veins: .pinnate(8),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.3))
        let look = leafLook(design, rough: 0.25, gloss: 0.65, height: 384)
        let leaf = leafMesh(design, length: 0.06,
                            bend: Sculpt.Bend(arch: 0.14, fold: 0.18, cup: 0.04),
                            rows: 14, columns: 9)
        let bark = pictureLook(Leafart.bark(Channels(128, 116, 90),
                                            dark: Channels(86, 76, 60),
                                            seed: seed), rough: 0.8)
        let height = random(0.16 ... 0.22) * stretch
        let trunk = Sculpt.curve(
            Vec3(0, Grower.soil - 0.01, 0),
            Vec3(random(-0.01 ... 0.01), Grower.soil + height * 0.5, 0),
            Vec3(random(-0.01 ... 0.01), Grower.soil + height, 0))
        stems([trunk], look: bark, sides: 10) { 0.009 - 0.003 * $0 }
        let top = trunk[trunk.count - 1]
        var branches: [[Vec3]] = []
        var tips: [(Vec3, Float)] = []
        let arms = Int.random(in: 4 ... 5, using: &rng)
        for index in 0 ..< arms {
            let yaw = 2 * Float.pi * Float(index) / Float(arms)
                + random(-0.3 ... 0.3)
            let reach = random(0.07 ... 0.11)
            let end = top + Grower.around(
                Vec3(reach, reach * random(0.4 ... 0.9), 0), yaw)
            branches.append(Sculpt.curve(top, top + Grower.around(
                Vec3(reach * 0.4, reach * 0.15, 0), yaw), end, steps: 8))
            tips.append((end, yaw))
        }
        stems(branches, look: bark, sides: 7) { 0.005 - 0.0025 * $0 }
        for (tipIndex, (point, yaw)) in tips.enumerated() {
            for index in 0 ..< count(9 ... 13) {
                let turn = yaw + Float(index) * 2.399_963
                let out = Grower.around(Vec3(random(0 ... 0.03),
                                             random(-0.02 ... 0.03), 0), turn)
                kit.place(leaf, look,
                          Pose(base: point + out, yaw: turn,
                               rise: random(-0.2 ... 0.6),
                               roll: random(-0.4 ... 0.4),
                               size: random(0.8 ... 1.15)),
                          sag: 0.35, sway: 0.015,
                          delay: Float(tipIndex) / Float(tips.count),
                          phase: random(0 ... 1))
            }
        }
        var lemon = Sculpt.ball(radius: 0.015, segments: 16, rings: 10)
            .stretched(Vec3(1.3, 1, 1))
        lemon.merge(Sculpt.spike(radius: 0.004, height: 0.006, sides: 8)
            .turned(around: Pose.z, by: -Float.pi / 2)
            .moved(by: Vec3(0.0185, 0, 0)))
        let fruit = kit.add(lemon)
        let peel = pictureLook(Leafart.skin(Channels(244, 206, 50), seed: seed),
                               rough: 0.35, gloss: 0.35)
        for (index, (point, yaw)) in tips.prefix(Int.random(
            in: 3 ... 4, using: &rng)).enumerated() {
            let at = point + Grower.around(Vec3(0.012, -0.035, 0),
                                           yaw + random(-0.5 ... 0.5))
            kit.place(fruit, peel, Pose(base: at, yaw: yaw + random(0 ... 3),
                                        rise: random(-1.4 ... -1.0)),
                      sag: 0.15, sway: 0.01, delay: 0.85 + 0.03 * Float(index),
                      phase: random(0 ... 1))
        }
        let white = LeafLook(outline: .petal, aspect: 0.55, veins: .fan(4),
                             base: bloom(Channels(252, 252, 246)),
                             tip: Channels(255, 255, 255),
                             vein: Channels(230, 230, 220), glow: 0.2,
                             mottle: 0.03)
        let blossom = flower(white, petals: 5, size: 0.011,
                             open: Float.pi / 2 - 0.35,
                             bend: Sculpt.Bend(arch: -0.12, fold: 0.1),
                             heart: nil, stamens: 12,
                             pollen: Channels(250, 220, 90))
        for (point, yaw) in tips {
            let turn = yaw + random(-1 ... 1)
            place(flower: blossom,
                  Pose(base: point + Grower.around(Vec3(0.02, 0.018, 0), turn),
                       yaw: turn, rise: random(0.3 ... 0.9)),
                  sag: 0.3, delay: 0.9)
        }
    }
}
