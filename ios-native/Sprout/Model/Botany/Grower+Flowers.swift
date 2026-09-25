import Foundation

/// Рецепты цветущих видов и их цветы. Цветок — `Head`: круги лепестков,
/// тычинки и чашелистики из общих частей `Grower`.
extension Grower {
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
        let sepals = whorl(sepal, length: length, open: flat,
                                  bend: Sculpt.Bend(arch: 0.08, fold: 0.05,
                                                    cup: -0.15),
                                  turns: [0, 2.45, -2.45], shift: -0.0015)
        let petals = whorl(petal, length: length * 0.92, open: flat,
                                  bend: Sculpt.Bend(arch: 0.05, fold: 0,
                                                    cup: -0.12, wave: 0.02,
                                                    waves: 2),
                                  turns: [1.3, -1.3])
        let labellum = whorl(lip, length: length * 0.55,
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
        if grows(.rose, named: "роз") { return rose() }
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
        let ring = whorl(petal, length: length,
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
        let ring = whorl(petal, length: 0.017,
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
        let top = whorl(upper, length: 0.012, open: open, bend: bend,
                               turns: [0.5, -0.5], shift: 0.0004)
        let bottom = whorl(lower, length: 0.013, open: open, bend: bend,
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
        let shell = whorl(outer, length: length, open: 0.62,
                                 bend: Sculpt.Bend(arch: 0.42, fold: 0,
                                                   cup: -0.75),
                                 turns: Grower.evenly(3), rows: 16,
                                 columns: 11)
        let core = whorl(inner, length: length * 0.96, open: 0.52,
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
            mesh.merge(whorl(petal, length: 0.017 + 0.017 * pow(k, 0.7),
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
        let mesh = whorl(petal, length: 0.017, open: 0.22,
                                bend: Sculpt.Bend(arch: 0.2, fold: 0, cup: -1.1),
                                turns: Grower.evenly(5), root: 0.002,
                                rows: 10, columns: 9)
        return [Part(mesh: kit.add(mesh), look: petalLook(petal, rough: 0.45)),
                sepals(5, length: 0.016, color: Channels(58, 104, 58),
                       open: 0.5)]
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

    /// Антуриум: лаковые листья-сердца и такое же лаковое красное
    /// покрывало, из основания которого торчит початок.
    mutating func anthurium() {
        pot(.classic)
        let base = green(Channels(24, 84, 42))
        let design = LeafLook(outline: .heart, aspect: 0.7, veins: .pinnate(6),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.3))
        let look = leafLook(design, rough: 0.25, gloss: 0.6)
        let leaf = leafMesh(design, length: 0.12,
                            bend: Sculpt.Bend(arch: 0.2, fold: 0.12, cup: 0.04))
        let stalk = plainLook(lighter(base, 0.12), rough: 0.45)
        let count = count(7 ... 10)
        var paths: [[Vec3]] = []
        var top: Float = 0
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963
            let reach = random(0.03 ... 0.07)
            let lift = random(0.1 ... 0.2) * stretch
            top = max(top, lift)
            let end = Grower.around(Vec3(reach, Grower.soil + lift, 0), yaw)
            paths.append(Sculpt.curve(
                Grower.around(Vec3(0.006, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(reach * 0.3, Grower.soil + lift * 0.9, 0),
                              yaw),
                end))
            kit.place(leaf, look,
                      Pose(base: end, yaw: yaw, rise: random(-0.2 ... 0.3),
                           roll: random(-0.2 ... 0.2),
                           size: random(0.85 ... 1.15)),
                      sag: 0.6, sway: 0.02, delay: Float(index) / Float(count),
                      phase: random(0 ... 1))
        }
        stems(paths, look: stalk, sides: 6) { 0.0035 - 0.001 * $0 }
        let colour = bloom(Channels(204, 22, 44))
        let spathe = LeafLook(outline: .heart, aspect: 0.82, veins: .pinnate(9),
                              base: colour, tip: lighter(colour, 0.08),
                              vein: darker(colour, 0.12), mottle: 0.04)
        let red = leafLook(spathe, rough: 0.18, gloss: 0.85, height: 256,
                           wilts: false)
        let hood = leafMesh(spathe, length: 0.085,
                            bend: Sculpt.Bend(arch: -0.04, fold: 0.03,
                                              cup: -0.05, wave: 0.01,
                                              waves: 3),
                            rows: 14, columns: 11)
        // Початок — короткий и толстый, из основания покрывала вверх.
        let spadix = Sculpt.tube((0 ... 8).map {
            let t = Float($0) / 8
            return Vec3(0.032 * t, 0.004 * t * t, 0)
        }, sides: 10, repeat: 0.03) { t in 0.004 * (1 - 0.45 * t) + 0.0008 }
        let rod = kit.add(spadix)
        let rodLook = pictureLook(Leafart.spadix(Channels(246, 214, 110)),
                                  rough: 0.7)
        var stalks: [[Vec3]] = []
        for index in 0 ..< self.count(2 ... 4) {
            let yaw = Float(index) * 2.3 + random(0 ... 0.6)
            let lift = top + random(0.03 ... 0.08)
            let end = Grower.around(Vec3(random(0.05 ... 0.08),
                                         Grower.soil + lift, 0), yaw)
            stalks.append(Sculpt.curve(
                Grower.around(Vec3(0.004, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(0.01, Grower.soil + lift * 0.8, 0), yaw),
                end))
            let phase = random(0 ... 1)
            // Сердце стоит почти стоймя лицом наружу, початок — над ним.
            let rise = random(0.85 ... 1.15)
            kit.place(hood, red, Pose(base: end, yaw: yaw, rise: rise,
                                      roll: random(-0.2 ... 0.2)),
                      sag: 0.6, sway: 0.03, delay: 0.8, phase: phase)
            kit.place(rod, rodLook,
                      Pose(base: end + Grower.around(Vec3(0.004, 0.002, 0), yaw),
                           yaw: yaw + Float.pi, rise: Float.pi - rise - 0.5),
                      sag: 0.6, sway: 0.03, delay: 0.85, phase: phase)
        }
        stems(stalks, look: stalk, sides: 6) { _ in 0.0026 }
    }

    /// Лилия: высокие стебли в узких листьях, на макушке — крупные
    /// звёзды с отогнутыми лепестками и бутон.
    mutating func lily() {
        pot(.classic)
        let base = green(Channels(52, 112, 52))
        let design = LeafLook(outline: .lanceolate, aspect: 0.2,
                              veins: .parallel(3), base: base,
                              tip: lighter(base, 0.08), vein: lighter(base, 0.2))
        let look = leafLook(design, rough: 0.45, gloss: 0.2, height: 256)
        let leaf = leafMesh(design, length: 0.075,
                            bend: Sculpt.Bend(arch: 0.3, fold: 0.25),
                            rows: 12, columns: 5)
        let stalk = plainLook(Channels(70, 122, 60), rough: 0.5)
        let colour = bloom(Channels(250, 244, 240))
        let head = lilyFlower(colour)
        let bud = kit.add(Sculpt.ball(radius: 0.008, segments: 10, rings: 7)
            .stretched(Vec3(3.2, 1, 1)).moved(by: Vec3(0.022, 0, 0)))
        let budLook = plainLook(.mix(Channels(170, 200, 140), colour, 0.45),
                                rough: 0.5)
        var paths: [[Vec3]] = []
        for index in 0 ..< count(2 ... 3) {
            let yaw = Float(index) * 2.399_963 + random(0 ... 0.5)
            let height = random(0.3 ... 0.4) * stretch
            let lean = random(0.01 ... 0.04)
            let path = Sculpt.curve(
                Grower.around(Vec3(0.008, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(lean * 0.2, Grower.soil + height * 0.6, 0),
                              yaw),
                Grower.around(Vec3(lean, Grower.soil + height, 0), yaw),
                steps: 16)
            paths.append(path)
            for step in 2 ... 12 {
                let t = Float(step) / 16
                kit.place(leaf, look,
                          Pose(base: path[step],
                               yaw: yaw + Float(step) * 2.399_963,
                               rise: random(0.5 ... 0.9),
                               roll: random(-0.2 ... 0.2), size: 1.05 - 0.5 * t),
                          sag: 0.5, sway: 0.015, delay: t,
                          phase: random(0 ... 1))
            }
            let top = path[16]
            for flowerIndex in 0 ..< Int.random(in: 1 ... 2, using: &rng) {
                let turn = yaw + Float(flowerIndex) * 2.6 + random(-0.3 ... 0.3)
                let at = top + Grower.around(
                    Vec3(0.02, -0.006 * Float(flowerIndex), 0), turn)
                paths.append([top, (top + at) / 2 + Vec3(0, 0.004, 0), at])
                place(flower: head,
                      Pose(base: at, yaw: turn, rise: random(0.25 ... 0.6)),
                      sag: 0.35, delay: 0.8 + 0.05 * Float(flowerIndex))
            }
            let turn = yaw + 1.3
            let budAt = top + Grower.around(Vec3(0.012, 0.01, 0), turn)
            paths.append([top, budAt])
            kit.place(bud, budLook, Pose(base: budAt, yaw: turn, rise: 1.1),
                      sag: 0.35, sway: 0.02, delay: 0.9, phase: random(0 ... 1))
        }
        stems(paths, look: stalk, sides: 7) { 0.0036 - 0.0012 * $0 }
    }

    /// Цветок лилии: шесть длинных лепестков звездой, кончики отогнуты, у
    /// горла крап; длинные тычинки с тёмными пыльниками и пестик.
    mutating func lilyFlower(_ colour: Channels) -> Head {
        let tepal = LeafLook(outline: .lanceolate, aspect: 0.3, veins: .fan(5),
                             base: colour, tip: lighter(colour, 0.08),
                             vein: .mix(colour, Channels(210, 200, 120), 0.4),
                             pattern: .spots(Channels(190, 70, 90), 14),
                             throat: .mix(colour, Channels(210, 226, 120), 0.6),
                             throatReach: 0.4, glow: 0.12, mottle: 0.05)
        let bend = Sculpt.Bend(arch: -0.32, fold: 0.18, cup: 0)
        var ring = whorl(tepal, length: 0.06, open: 0.95, bend: bend,
                         turns: Grower.evenly(3), rows: 16, columns: 9)
        ring.merge(whorl(tepal, length: 0.056, open: 0.9, bend: bend,
                         turns: Grower.evenly(3, offset: 0.5), shift: -0.0015,
                         rows: 16, columns: 9))
        var head = [Part(mesh: kit.add(ring),
                         look: petalLook(tepal, rough: 0.4, gloss: 0.15))]
        head += stamens(6, length: 0.042, spread: 0.014, anther: 0.0026,
                        thread: Channels(226, 232, 196),
                        pollen: Channels(170, 76, 36))
        let pistil = Sculpt.tube(Sculpt.curve(Vec3(0, 0, 0),
                                              Vec3(0.025, 0.002, 0),
                                              Vec3(0.048, 0.006, 0), steps: 6),
                                 sides: 6) { 0.0011 + 0.0012 * $0 * $0 * $0 }
        head.append(Part(mesh: kit.add(Grower.opaque(pistil)),
                         look: plainLook(Channels(200, 220, 150), rough: 0.5)))
        return head
    }

    /// Подсолнух: толстый стебель с шершавыми листьями-сердцами и
    /// корзинка, повёрнутая к свету.
    mutating func sunflower() {
        pot(.classic)
        let base = green(Channels(74, 128, 50))
        let design = LeafLook(outline: .heart, aspect: 0.86, veins: .pinnate(6),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.3), teeth: 16,
                              toothDepth: 0.05)
        let look = leafLook(design, rough: 0.75, height: 384)
        let leaf = leafMesh(design, length: 0.115,
                            bend: Sculpt.Bend(arch: 0.3, fold: 0.12, wave: 0.01,
                                              waves: 4),
                            rows: 16, columns: 11)
        let stalk = pictureLook(Leafart.bark(Channels(110, 150, 70),
                                             dark: Channels(80, 110, 50),
                                             seed: seed), rough: 0.7)
        let head = sunflowerHead(bloom(Channels(250, 192, 24)))
        var paths: [[Vec3]] = []
        for index in 0 ..< Int.random(in: 1 ... 2, using: &rng) {
            let yaw = Float(index) * 2.6 + random(0 ... 0.5)
            let height = (random(0.3 ... 0.36) - 0.07 * Float(index)) * stretch
            let lean = random(0.01 ... 0.03)
            let path = Sculpt.curve(
                Grower.around(Vec3(0.006, Grower.soil - 0.006, 0), yaw),
                Grower.around(Vec3(lean * 0.3, Grower.soil + height * 0.6, 0),
                              yaw),
                Grower.around(Vec3(lean, Grower.soil + height, 0), yaw),
                steps: 16)
            paths.append(path)
            for step in stride(from: 2, through: 14, by: 2) {
                let t = Float(step) / 16
                let turn = yaw + Float(step) * 1.4
                let out = path[step] + Grower.around(Vec3(0.012, 0.004, 0), turn)
                paths.append([path[step],
                              (path[step] + out) / 2 + Vec3(0, 0.003, 0), out])
                kit.place(leaf, look,
                          Pose(base: out, yaw: turn, rise: random(0.05 ... 0.35),
                               roll: random(-0.2 ... 0.2),
                               size: 1.15 - 0.55 * t),
                          sag: 0.6, sway: 0.02, delay: t, phase: random(0 ... 1))
            }
            // Корзинка смотрит вверх и вбок — к свету: её видно отовсюду.
            place(flower: head, Pose(base: path[16], yaw: yaw + 0.4,
                                     rise: random(0.85 ... 1.05)),
                  sag: 0.4, delay: 0.85)
        }
        stems(paths, look: stalk, sides: 8) { 0.0055 - 0.002 * $0 }
    }

    /// Корзинка: тёмный диск семечек, два круга жёлтых язычков и зелёная
    /// обёртка сзади.
    mutating func sunflowerHead(_ colour: Channels) -> Head {
        let ray = LeafLook(outline: .petal, aspect: 0.3, veins: .fan(4),
                           base: colour, tip: lighter(colour, 0.12),
                           vein: darker(colour, 0.12), glow: 0.1, mottle: 0.06)
        let look = petalLook(ray, rough: 0.55)
        let bend = Sculpt.Bend(arch: -0.06, fold: 0.18, cup: -0.05)
        var rays = whorl(ray, length: 0.04, open: Float.pi / 2 - 0.12,
                         bend: bend, turns: Grower.evenly(18), root: 0.026,
                         rows: 8, columns: 5)
        rays.merge(whorl(ray, length: 0.036, open: Float.pi / 2 - 0.25,
                         bend: bend, turns: Grower.evenly(18, offset: 0.5),
                         shift: 0.0015, root: 0.024, rows: 8, columns: 5))
        let seeds = pictureLook(Leafart.skin(Channels(84, 54, 28), seed: seed),
                                rough: 0.9)
        let disc = Sculpt.ball(radius: 0.03, segments: 24, rings: 8)
            .stretched(Vec3(0.3, 1, 1))
        return [Part(mesh: kit.add(rays), look: look),
                Part(mesh: kit.add(disc), look: seeds),
                sepals(16, length: 0.026, color: Channels(70, 116, 48),
                       open: 1.75)]
    }

    /// Лаванда: серо-зелёные узкие листья внизу и прямые стебли с
    /// колосками из мутовок лиловых цветочков.
    mutating func lavender() {
        pot(.classic)
        let base = green(Channels(120, 148, 120))
        let design = LeafLook(outline: .strap, aspect: 0.12, veins: .parallel(1),
                              base: base, tip: lighter(base, 0.12),
                              vein: lighter(base, 0.2), mottle: 0.1)
        let look = leafLook(design, rough: 0.85, height: 128)
        let leaf = leafMesh(design, length: 0.04,
                            bend: Sculpt.Bend(arch: 0.25, fold: 0.3),
                            rows: 8, columns: 4)
        let stalk = plainLook(Channels(130, 150, 110), rough: 0.8)
        var spike = Mesh3D()
        for tier in 0 ..< 9 {
            let x = 0.004 + Float(tier) * 0.0068
            let shrink = 1 - 0.45 * Float(tier) / 8
            for floret in 0 ..< 6 {
                let turn = Float(floret) * Float.pi / 3 + Float(tier) * 0.5
                let out = 0.0035 * shrink
                spike.merge(Sculpt.ball(radius: 0.0026 * shrink, segments: 6,
                                        rings: 4)
                    .stretched(Vec3(0.9, 1, 1.3))
                    .moved(by: Vec3(x, out * cos(turn), out * sin(turn))))
            }
        }
        let ear = kit.add(spike)
        let earLook = plainLook(bloom(Channels(132, 104, 196)), rough: 0.8)
        var paths: [[Vec3]] = []
        let count = count(12 ... 18)
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963
            let spread = random(0.02 ... 0.08)
            let height = random(0.18 ... 0.28) * stretch
            let path = Sculpt.curve(
                Grower.around(Vec3(0.004, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(spread * 0.3, Grower.soil + height * 0.5, 0),
                              yaw),
                Grower.around(Vec3(spread, Grower.soil + height, 0), yaw),
                steps: 12)
            paths.append(path)
            let ahead = (path[12] - path[10]).unit
            let share = Float(index) / Float(count)
            kit.place(ear, earLook,
                      Pose(base: path[11], yaw: atan2(-ahead.z, ahead.x),
                           rise: asin(min(max(ahead.y, -1), 1))),
                      sag: 0.3, sway: 0.03, delay: 0.7 + 0.2 * share,
                      phase: random(0 ... 1))
            for node in 1 ... 4 {
                for side: Float in [1, -1] {
                    kit.place(leaf, look,
                              Pose(base: path[node],
                                   yaw: yaw + Float(node) * 1.6
                                       + (side > 0 ? 0 : .pi),
                                   rise: random(0.4 ... 0.9),
                                   size: random(0.8 ... 1.1)),
                              sag: 0.4, sway: 0.01, delay: share * 0.6,
                              phase: random(0 ... 1))
                }
            }
        }
        stems(paths, look: stalk, sides: 4) { _ in 0.0011 }
    }

    /// Хризантема: кустик из многих стеблей с резными листьями, на каждом
    /// — ромашка.
    mutating func chrysanthemum() {
        pot(.classic)
        let base = green(Channels(58, 106, 56))
        let design = LeafLook(outline: .ovate, aspect: 0.66, veins: .pinnate(5),
                              base: base, tip: lighter(base, 0.08),
                              vein: lighter(base, 0.25), teeth: 5,
                              toothDepth: 0.28, scallops: true)
        let look = leafLook(design, rough: 0.75, height: 256)
        let leaf = leafMesh(design, length: 0.045,
                            bend: Sculpt.Bend(arch: 0.2, fold: 0.1, wave: 0.02,
                                              waves: 3),
                            rows: 12, columns: 9)
        let stalk = plainLook(Channels(80, 120, 64), rough: 0.7)
        let head = daisy(bloom(Channels(250, 250, 244)))
        var paths: [[Vec3]] = []
        let count = count(9 ... 13)
        for index in 0 ..< count {
            let yaw = Float(index) * 2.399_963
            let spread = random(0.02 ... 0.07)
            let height = random(0.13 ... 0.2) * stretch
            let path = Sculpt.curve(
                Grower.around(Vec3(0.005, Grower.soil - 0.004, 0), yaw),
                Grower.around(Vec3(spread * 0.4, Grower.soil + height * 0.6, 0),
                              yaw),
                Grower.around(Vec3(spread, Grower.soil + height, 0), yaw),
                steps: 10)
            paths.append(path)
            let share = Float(index) / Float(count)
            for node in stride(from: 2, through: 8, by: 2) {
                kit.place(leaf, look,
                          Pose(base: path[node], yaw: yaw + Float(node) * 2.2,
                               rise: random(0.1 ... 0.5),
                               roll: random(-0.2 ... 0.2),
                               size: random(0.85 ... 1.1)),
                          sag: 0.5, sway: 0.015, delay: share,
                          phase: random(0 ... 1))
            }
            let ahead = (path[10] - path[9]).unit
            place(flower: head,
                  Pose(base: path[10], yaw: atan2(-ahead.z, ahead.x),
                       rise: random(0.9 ... 1.3)),
                  sag: 0.4, delay: 0.75 + 0.2 * share)
        }
        stems(paths, look: stalk, sides: 5) { 0.0022 - 0.0006 * $0 }
    }

    /// Ромашка: два круга узких язычков и жёлтая выпуклая серединка.
    mutating func daisy(_ colour: Channels) -> Head {
        let ray = LeafLook(outline: .petal, aspect: 0.24, veins: .fan(3),
                           base: colour, tip: lighter(colour, 0.05),
                           vein: darker(colour, 0.06), glow: 0.15, mottle: 0.04)
        let look = petalLook(ray, rough: 0.55)
        let bend = Sculpt.Bend(arch: -0.05, fold: 0.15, cup: -0.05)
        var rays = whorl(ray, length: 0.019, open: Float.pi / 2 - 0.1,
                         bend: bend, turns: Grower.evenly(16), root: 0.004,
                         rows: 6, columns: 5)
        rays.merge(whorl(ray, length: 0.017, open: Float.pi / 2 - 0.3,
                         bend: bend, turns: Grower.evenly(16, offset: 0.5),
                         shift: 0.0012, root: 0.0035, rows: 6, columns: 5))
        return [Part(mesh: kit.add(rays), look: look),
                dome(0.0055, color: Channels(246, 196, 40), squash: 0.6),
                sepals(12, length: 0.008, color: Channels(66, 110, 58),
                       open: 1.8)]
    }
}
