import Foundation

/// Рецепты видов сверх первых двадцати — из тех же частей, что в `Botany`:
/// лист-карточка с рисунком, мясистый лист, стебли трубками, цветы кругами
/// лепестков.
extension Grower {
    // MARK: - Листва

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

    // MARK: - Суккуленты

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

    // MARK: - Цветы

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
