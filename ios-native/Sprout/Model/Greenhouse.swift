import Foundation

/// Облик растения. Габитус — от вида, а мелочи — число листьев, их наклон,
/// цвет горшка — от номера растения: два Баксика похожи, но не одинаковы, и
/// каждый раз те же.
enum Habit: Equatable, Sendable {
    /// Крупные листья на черешках: монстера, фикус.
    case broad
    /// Длинные узкие листья из середины: драцена, пальма.
    case blades
    /// Толстые листья розеткой: алоэ, толстянка.
    case rosette
    case cactus
    /// Много мелких листьев на стеблях: базилик, плющ.
    case bush
    /// Вайи с листочками: папоротник.
    case fern
}

struct Bloom: Equatable, Sendable {
    var petals: Int
    var size: Float
    /// Насколько лепестки сомкнуты: 0 — плоский, к π/2 — бутон.
    var cup: Float
    var color: Channels
    var heart: Channels
    /// Серединка — доля от лепестка.
    var heartSize: Float
    var count: Int
}

/// Часть веточки одним цветом. Вянущие желтеют к сухой земле, лепестки и
/// серединки — нет.
struct Part: Sendable {
    var mesh: Mesh3D
    var color: Channels
    var wilts: Bool
}

/// Лист, вайя или цветок — то, что никнет и покачивается. Сетка лежит вдоль
/// +X от точки крепления; в сцене её поднимают на `rise` и поворачивают на
/// `yaw` вокруг вертикали.
struct Sprig: Sendable {
    var parts: [Part]
    var base: Vec3
    var yaw: Float
    var rise: Float
    /// Насколько опускается у сухой земли, в радианах.
    var sag: Float
    /// 0…1 — очередь при появлении.
    var delay: Float
    /// 0…1 — чтобы листья качались не в такт.
    var phase: Float

    /// Точка сетки в координатах растения при этом наклоне.
    func place(_ point: Vec3, lean: Float = 0) -> Vec3 {
        point.turned(around: Vec3(0, 0, 1), by: rise - lean)
            .turned(around: Vec3(0, 1, 0), by: yaw) + base
    }
}

/// Растение целиком, в метрах; начало — середина дна горшка.
struct Specimen: Sendable {
    var pot: Mesh3D
    var potColor: Channels
    /// Шероховатость: терракота матовая, глазурь блестит.
    var potRough: Float
    var soil: Mesh3D
    var stems: Mesh3D
    var stemColor: Channels
    /// Ствол кактуса; у прочих пусто.
    var body: Mesh3D
    var bodyColor: Channels
    var sprigs: [Sprig]
    var height: Float
    var spread: Float
}

/// Случайность от номера растения: `hashValue` в Swift от запуска к запуску
/// разный, а растение должно выглядеть одинаково.
struct Seeded: RandomNumberGenerator {
    private var state: UInt64

    init(_ text: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        state = hash
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        return z ^ (z >> 31)
    }
}

/// Рецепты объёмных растений и то, как они живут влажностью.
enum Greenhouse {
    /// Горшок: внешний край по верху, внутренний, уровень земли и кромка.
    static let potRadius: Float = 0.082
    static let potInner: Float = 0.068
    static let soil: Float = 0.112
    static let rim: Float = 0.133

    // MARK: - Вид

    static func habit(of species: String) -> Habit {
        let name = species.lowercased()
        return habits.first { name.contains($0.stem) }?.habit ?? .broad
    }

    private static let habits: [(stem: String, habit: Habit)] = [
        ("кактус", .cactus),
        ("алоэ", .rosette), ("суккулент", .rosette), ("толстянк", .rosette),
        ("каланхоэ", .rosette), ("эхевери", .rosette), ("хавортия", .rosette),
        ("папорот", .fern), ("нефролепис", .fern), ("мох", .fern),
        ("пальм", .blades), ("драцен", .blades), ("сансевиер", .blades),
        ("хлорофит", .blades), ("бамбук", .blades), ("трав", .blades),
        ("орхиде", .blades), ("тюльпан", .blades), ("лили", .blades),
        ("юкк", .blades), ("замиокулькас", .blades),
        ("базилик", .bush), ("мят", .bush), ("розмарин", .bush),
        ("зелень", .bush), ("плющ", .bush), ("хойя", .bush),
        ("кустик", .bush), ("пеларгони", .bush), ("герань", .bush),
        ("фиалк", .bush), ("росток", .bush), ("роза", .bush),
        ("ромашк", .bush), ("бегони", .bush), ("сциндапсус", .bush),
        ("традесканц", .bush),
    ]

    /// Свисают через край горшка.
    private static let trailing = ["плющ", "хойя", "сциндапсус", "традесканц"]

    /// Жёсткие листья торчком, почти без изгиба.
    private static let stiff = ["сансевиер", "замиокулькас", "юкк"]

    static func bloom(of species: String) -> Bloom? {
        let name = species.lowercased()
        return blooms.first { name.contains($0.stem) }?.bloom
    }

    private static let blooms: [(stem: String, bloom: Bloom)] = [
        ("тюльпан", Bloom(petals: 6, size: 0.05, cup: 1.15,
                          color: Channels(226, 40, 52),
                          heart: Channels(250, 210, 60), heartSize: 0.18,
                          count: 2)),
        ("роза", Bloom(petals: 9, size: 0.032, cup: 0.85,
                       color: Channels(214, 50, 90),
                       heart: Channels(180, 30, 70), heartSize: 0.3,
                       count: 3)),
        ("фиалк", Bloom(petals: 5, size: 0.016, cup: 0.15,
                        color: Channels(128, 70, 200),
                        heart: Channels(250, 220, 80), heartSize: 0.2,
                        count: 5)),
        ("орхиде", Bloom(petals: 5, size: 0.035, cup: 0.2,
                         color: Channels(236, 120, 200),
                         heart: Channels(250, 240, 250), heartSize: 0.22,
                         count: 3)),
        ("бегони", Bloom(petals: 5, size: 0.022, cup: 0.4,
                         color: Channels(250, 110, 100),
                         heart: Channels(255, 214, 90), heartSize: 0.25,
                         count: 4)),
        ("пеларгони", Bloom(petals: 5, size: 0.016, cup: 0.3,
                            color: Channels(235, 45, 50),
                            heart: Channels(250, 230, 200), heartSize: 0.2,
                            count: 6)),
        ("герань", Bloom(petals: 5, size: 0.016, cup: 0.3,
                         color: Channels(235, 45, 50),
                         heart: Channels(250, 230, 200), heartSize: 0.2,
                         count: 6)),
        ("лили", Bloom(petals: 6, size: 0.05, cup: 0.7,
                       color: Channels(250, 246, 238),
                       heart: Channels(240, 190, 60), heartSize: 0.15,
                       count: 2)),
        ("ромашк", Bloom(petals: 14, size: 0.028, cup: 0.1,
                         color: Channels(252, 252, 250),
                         heart: Channels(250, 200, 40), heartSize: 0.35,
                         count: 4)),
        ("подсолнух", Bloom(petals: 18, size: 0.04, cup: 0.15,
                            color: Channels(252, 196, 20),
                            heart: Channels(110, 70, 30), heartSize: 0.55,
                            count: 1)),
        ("каланхоэ", Bloom(petals: 4, size: 0.012, cup: 0.3,
                           color: Channels(255, 120, 40),
                           heart: Channels(255, 200, 80), heartSize: 0.25,
                           count: 7)),
        ("спатифил", Bloom(petals: 1, size: 0.06, cup: 0.9,
                           color: Channels(250, 250, 244),
                           heart: Channels(240, 230, 190), heartSize: 0.15,
                           count: 3)),
        ("цвет", Bloom(petals: 5, size: 0.025, cup: 0.4,
                       color: Channels(245, 120, 170),
                       heart: Channels(255, 220, 90), heartSize: 0.25,
                       count: 3)),
    ]

    private static let greens = [
        Channels(64, 150, 70), Channels(48, 132, 72), Channels(86, 164, 74),
        Channels(98, 156, 70), Channels(58, 140, 98),
    ]

    private static let pots: [(color: Channels, rough: Float)] = [
        (Channels(196, 106, 72), 0.8), (Channels(236, 230, 218), 0.3),
        (Channels(143, 168, 140), 0.35), (Channels(58, 60, 66), 0.3),
        (Channels(222, 170, 160), 0.4),
    ]

    // MARK: - Рост

    static func grow(_ plant: Plant) -> Specimen {
        var rng = Seeded(plant.id)
        let name = plant.species.lowercased()
        let habit = habit(of: plant.species)
        let green = greens[Int.random(in: 0 ..< greens.count, using: &rng)]
        let pot = pots[Int.random(in: 0 ..< pots.count, using: &rng)]

        var crown = Crown()
        switch habit {
        case .broad: broad(&crown, green, &rng)
        case .blades:
            blades(&crown, green, stiff: stiff.contains { name.contains($0) },
                   &rng)
        case .rosette: rosette(&crown, &rng)
        case .cactus: cactus(&crown, &rng)
        case .bush:
            bush(&crown, green,
                 trailing: trailing.contains { name.contains($0) }, &rng)
        case .fern: fern(&crown, green, &rng)
        }
        if let bloom = bloom(of: plant.species) {
            flowers(&crown, bloom, &rng)
        }

        let points = crown.sprigs.flatMap { sprig in
            sprig.parts.flatMap { $0.mesh.positions.map { sprig.place($0) } }
        } + crown.stems.positions + crown.body.positions
        let height = max(points.map(\.y).max() ?? rim, rim)
        let spread = max(points.map { ($0.x * $0.x + $0.z * $0.z)
                .squareRoot() }.max() ?? 0, potRadius)
        return Specimen(pot: potMesh, potColor: pot.color,
                        potRough: pot.rough, soil: soilMesh,
                        stems: crown.stems, stemColor: crown.stemColor,
                        body: crown.body, bodyColor: crown.bodyColor,
                        sprigs: crown.sprigs, height: height, spread: spread)
    }

    /// То, что растёт из горшка, пока его собирают.
    private struct Crown {
        var stems = Mesh3D()
        var stemColor = Channels(88, 128, 60)
        var body = Mesh3D()
        var bodyColor = Channels(72, 132, 80)
        var sprigs: [Sprig] = []

        /// Верх листвы — над ним встают цветы.
        var top: Float {
            let leaves = sprigs.flatMap { sprig in
                sprig.parts.flatMap { $0.mesh.positions.map { sprig.place($0) } }
            }
            return max(leaves.map(\.y).max() ?? 0, stems.top, body.top,
                       Greenhouse.soil + 0.05)
        }
    }

    private static let up = Vec3(0, 1, 0)

    private static func around(_ point: Vec3, _ yaw: Float) -> Vec3 {
        point.turned(around: up, by: yaw)
    }

    /// Квадратичная кривая Безье — стебель с одним изгибом.
    private static func curve(_ a: Vec3, _ b: Vec3, _ c: Vec3,
                              steps: Int = 8) -> [Vec3] {
        (0 ... steps).map { step in
            let t = Float(step) / Float(steps)
            return a * ((1 - t) * (1 - t)) + b * (2 * (1 - t) * t) + c * (t * t)
        }
    }

    private static func vary(_ color: Channels, _ rng: inout Seeded,
                             by amount: Double = 10) -> Channels {
        func shift(_ value: Double) -> Double {
            min(max(value + Double.random(in: -amount ... amount, using: &rng),
                    0), 255)
        }
        return Channels(shift(color.red), shift(color.green), shift(color.blue))
    }

    private static func random(_ range: ClosedRange<Float>,
                               _ rng: inout Seeded) -> Float {
        Float.random(in: range, using: &rng)
    }

    private static func broad(_ crown: inout Crown, _ green: Channels,
                              _ rng: inout Seeded) {
        let count = Int.random(in: 6 ... 9, using: &rng)
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.2 ... 0.2, &rng))
                / Float(count)
            let reach = random(0.03 ... 0.08, &rng)
            let lift = random(0.1 ... 0.24, &rng)
            let end = around(Vec3(reach, soil + lift, 0), yaw)
            crown.stems.merge(Sculpt.tube(
                curve(around(Vec3(0.006, soil - 0.004, 0), yaw),
                      around(Vec3(reach * 0.25, soil + lift * 0.85, 0), yaw),
                      end),
                sides: 6) { 0.0045 - 0.0015 * $0 })
            let leaf = Sculpt.leaf(length: random(0.11 ... 0.16, &rng),
                                   width: random(0.08 ... 0.11, &rng),
                                   arch: 0.22, fold: 0.18, outline: .heart)
            crown.sprigs.append(Sprig(
                parts: [Part(mesh: leaf, color: vary(green, &rng),
                             wilts: true)],
                base: end, yaw: yaw, rise: random(0.1 ... 0.45, &rng),
                sag: 0.75, delay: Float(index) / Float(count),
                phase: random(0 ... 1, &rng)))
        }
    }

    private static func blades(_ crown: inout Crown, _ green: Channels,
                               stiff: Bool, _ rng: inout Seeded) {
        let count = stiff ? Int.random(in: 6 ... 9, using: &rng)
            : Int.random(in: 11 ... 16, using: &rng)
        let color = stiff ? Channels(50, 100, 60) : green
        for index in 0 ..< count {
            // Золотой угол: листья не встают друг над другом.
            let yaw = Float(index) * 2.399_963
            let base = around(Vec3(random(0.004 ... 0.014, &rng), soil, 0), yaw)
            let blade = Sculpt.leaf(
                length: stiff ? random(0.16 ... 0.24, &rng)
                    : random(0.14 ... 0.24, &rng),
                width: stiff ? random(0.032 ... 0.042, &rng)
                    : random(0.016 ... 0.028, &rng),
                arch: stiff ? 0.04 : random(0.35 ... 0.6, &rng),
                fold: stiff ? 0.15 : 0.3, outline: .blade)
            crown.sprigs.append(Sprig(
                parts: [Part(mesh: blade, color: vary(color, &rng),
                             wilts: true)],
                base: base, yaw: yaw,
                rise: stiff ? random(1.3 ... 1.5, &rng)
                    : random(0.85 ... 1.35, &rng),
                sag: stiff ? 0.2 : 0.55,
                delay: Float(index) / Float(count),
                phase: random(0 ... 1, &rng)))
        }
    }

    /// Внешние листья длиннее и ниже, внутренние короче и круче.
    private static func rosette(_ crown: inout Crown, _ rng: inout Seeded) {
        let count = Int.random(in: 8 ... 13, using: &rng)
        let color = Channels(110, 164, 116)
        for index in 0 ..< count {
            let inner = Float(index) / Float(count)
            let yaw = Float(index) * 2.399_963
            let leaf = Sculpt.leaf(
                length: 0.13 - 0.05 * inner + random(-0.01 ... 0.01, &rng),
                width: random(0.032 ... 0.044, &rng), arch: 0.08, fold: 0.5,
                outline: .blade)
            crown.sprigs.append(Sprig(
                parts: [Part(mesh: leaf, color: vary(color, &rng, by: 8),
                             wilts: true)],
                base: around(Vec3(0.008 + 0.012 * (1 - inner), soil, 0), yaw),
                yaw: yaw, rise: 0.55 + 0.75 * inner, sag: 0.25,
                delay: inner, phase: random(0 ... 1, &rng)))
        }
    }

    /// Ствол с рёбрами и одна-две «руки». Ему никнуть нечем — вянет цветом.
    private static func cactus(_ crown: inout Crown, _ rng: inout Seeded) {
        let tall = random(0.12 ... 0.19, &rng)
        crown.body = Sculpt.lathe([
            SIMD2(0.036, soil - 0.004), SIMD2(0.039, soil + 0.02),
            SIMD2(0.038, soil + tall * 0.8), SIMD2(0.03, soil + tall * 0.95),
            SIMD2(0.016, soil + tall + 0.008), SIMD2(0, soil + tall + 0.012),
        ], segments: 40, ribs: 10, ribDepth: 0.09)
        crown.bodyColor = Channels(72, 132, 80)
        let arms = Int.random(in: 0 ... 2, using: &rng)
        for index in 0 ..< arms {
            let yaw = Float(index) * Float.pi + random(-0.5 ... 0.5, &rng)
            let at = soil + tall * random(0.35 ... 0.6, &rng)
            let length = random(0.04 ... 0.07, &rng)
            var path = [Vec3(0.028, at, 0), Vec3(0.045, at + 0.002, 0),
                        Vec3(0.058, at + 0.01, 0), Vec3(0.064, at + 0.022, 0)]
            for step in 1 ... 8 {
                path.append(Vec3(0.066, at + 0.022 + length * Float(step) / 8,
                                 0))
            }
            let arm = Sculpt.tube(path.map { around($0, yaw) }, sides: 16) { t in
                t < 0.85 ? 0.017
                    : 0.017 * max(0, 1 - pow((t - 0.85) / 0.15, 2)).squareRoot()
            }
            crown.body.merge(arm)
        }
    }

    /// Стебли с листьями по очереди. У вьющихся через один стебель свисает
    /// через край, остальные держат шапку над горшком — как у живого плюща.
    private static func bush(_ crown: inout Crown, _ green: Channels,
                             trailing vine: Bool, _ rng: inout Seeded) {
        let count = Int.random(in: 4 ... 6, using: &rng)
        for index in 0 ..< count {
            let trailing = vine && index.isMultiple(of: 2)
            let yaw = 2 * Float.pi * (Float(index) + random(-0.25 ... 0.25, &rng))
                / Float(count)
            let height = random(0.1 ... 0.2, &rng)
            let lean = random(0.01 ... 0.04, &rng)
            let start = around(Vec3(0.004, soil - 0.004, 0), yaw)
            let bend = trailing
                ? around(Vec3(0.07, soil + 0.06, 0), yaw)
                : around(Vec3(lean * 0.3, soil + height * 0.6, 0), yaw)
            let end = trailing
                ? around(Vec3(0.12 + lean, soil - 0.05 - height * 0.3, 0), yaw)
                : around(Vec3(lean, soil + height, 0), yaw)
            let path = curve(start, bend, end, steps: 10)
            crown.stems.merge(Sculpt.tube(path, sides: 5) {
                0.0028 - 0.0012 * $0
            })
            let leaves = Int.random(in: 4 ... 7, using: &rng)
            for leafIndex in 0 ..< leaves {
                let t = 0.3 + 0.7 * Float(leafIndex) / Float(leaves - 1)
                let at = path[min(Int((t * 10).rounded()), 10)]
                let side: Float = leafIndex.isMultiple(of: 2) ? 1 : -1
                let length = random(0.034 ... 0.056, &rng)
                let leaf = Sculpt.leaf(length: length, width: length * 0.62,
                                       arch: 0.15, fold: 0.2, outline: .oval,
                                       steps: 8)
                crown.sprigs.append(Sprig(
                    parts: [Part(mesh: leaf, color: vary(green, &rng),
                                 wilts: true)],
                    base: at, yaw: yaw + side * random(0.8 ... 1.6, &rng),
                    rise: trailing ? random(-0.2 ... 0.3, &rng)
                        : random(0.2 ... 0.6, &rng),
                    sag: 0.65,
                    delay: (Float(index) + t) / Float(count + 1),
                    phase: random(0 ... 1, &rng)))
            }
        }
    }

    /// Вайя — одна сетка: жилка и пары листочков. Никнет целиком.
    private static func fern(_ crown: inout Crown, _ green: Channels,
                             _ rng: inout Seeded) {
        let count = Int.random(in: 7 ... 11, using: &rng)
        for index in 0 ..< count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.2 ... 0.2, &rng))
                / Float(count)
            let length = random(0.17 ... 0.26, &rng)
            let spine = (0 ... 12).map { step -> Vec3 in
                let t = Float(step) / 12
                return Vec3(length * t, -0.35 * length * t * t, 0)
            }
            var frond = Sculpt.tube(spine, sides: 5) { 0.0022 - 0.0014 * $0 }
            for pair in 1 ... 11 {
                let t = Float(pair) / 12
                let at = spine[pair]
                let size = 0.04 * (1 - t * 0.7)
                for side: Float in [1, -1] {
                    let leaflet = Sculpt.leaf(length: size, width: size * 0.42,
                                              arch: 0.1, fold: 0.1,
                                              outline: .blade, steps: 6)
                        .turned(around: up, by: side * (Float.pi / 2 - 0.35))
                        .moved(by: at)
                    frond.merge(leaflet)
                }
            }
            crown.sprigs.append(Sprig(
                parts: [Part(mesh: frond, color: vary(green, &rng),
                             wilts: true)],
                base: around(Vec3(0.008, soil, 0), yaw), yaw: yaw,
                rise: random(0.55 ... 0.95, &rng), sag: 0.5,
                delay: Float(index) / Float(count),
                phase: random(0 ... 1, &rng)))
        }
    }

    /// Цветы встают над листвой, каждый на своём стебле, и распускаются
    /// последними.
    private static func flowers(_ crown: inout Crown, _ bloom: Bloom,
                                _ rng: inout Seeded) {
        let top = crown.top
        for index in 0 ..< bloom.count {
            let yaw = 2 * Float.pi * (Float(index) + random(-0.3 ... 0.3, &rng))
                / Float(bloom.count)
            let reach = bloom.count == 1 ? 0 : random(0.01 ... 0.05, &rng)
            let height = top + random(0.01 ... 0.05, &rng)
            let base = around(Vec3(reach, height, 0), yaw)
            crown.stems.merge(Sculpt.tube(
                curve(around(Vec3(0.004, soil - 0.004, 0), yaw),
                      around(Vec3(reach * 0.2, (soil + height) / 2, 0), yaw),
                      base),
                sides: 5) { _ in 0.0025 })
            let head = Sculpt.blossom(petals: bloom.petals, size: bloom.size,
                                      cup: bloom.cup,
                                      heart: bloom.size * bloom.heartSize)
            crown.sprigs.append(Sprig(
                parts: [Part(mesh: head.petals,
                             color: vary(bloom.color, &rng, by: 8),
                             wilts: false),
                        Part(mesh: head.heart, color: bloom.heart,
                             wilts: false)],
                base: base, yaw: yaw, rise: random(1.1 ... 1.45, &rng),
                sag: 0.7,
                delay: 0.6 + 0.4 * Float(index) / Float(bloom.count),
                phase: random(0 ... 1, &rng)))
        }
    }

    // MARK: - Горшок и земля

    /// Снаружи вверх, через кромку и внутрь до земли: нормали внутренней
    /// стенки смотрят внутрь, её видно сверху.
    ///
    /// Кольца у самых рёбер держат их чёткими: иначе сглаженные нормали
    /// растеклись бы по всей стенке и горшок читался бы обмылком.
    static let potMesh = Sculpt.lathe([
        SIMD2(0, 0.004), SIMD2(0.05, 0), SIMD2(0.055, 0.006),
        SIMD2(0.0562, 0.014), SIMD2(0.0646, 0.062), SIMD2(0.0733, 0.11),
        SIMD2(0.074, 0.118), SIMD2(0.081, 0.121), SIMD2(potRadius, rim - 0.001),
        SIMD2(0.074, rim), SIMD2(0.07, 0.126), SIMD2(potInner, soil - 0.004),
    ], segments: 48)

    static let soilMesh = Sculpt.lathe([
        SIMD2(potInner + 0.0015, soil - 0.002), SIMD2(0.045, soil + 0.005),
        SIMD2(0, soil + 0.008),
    ], segments: 48)

    // MARK: - Как живёт влажностью

    /// 0 — листья бодрые, 1 — совсем поникли. Никнут ниже половины, плавно.
    static func sag(_ moisture: Double) -> Float {
        let dry = min(max((0.5 - moisture) / 0.5, 0), 1)
        return Float(dry * dry * (3 - 2 * dry))
    }

    /// Желтизна — с порога тревоги, не больше семи десятых: сухой лист ещё
    /// зелёный, иначе он читался бы мёртвым.
    static func wilt(_ moisture: Double) -> Double {
        let dry = min(max((Thirst.warnBelow - moisture) / Thirst.warnBelow, 0),
                      1)
        return 0.7 * dry
    }

    static let straw = Channels(186, 156, 72)

    static func leafColor(_ base: Channels, moisture: Double) -> Channels {
        .mix(base, straw, wilt(moisture))
    }

    static let drySoil = Channels(139, 104, 74)
    static let wetSoil = Channels(62, 42, 30)

    static func soilColor(_ moisture: Double) -> Channels {
        .mix(drySoil, wetSoil, moisture)
    }

    static let calmRing = Channels(71, 181, 228)
    static let warnRing = Channels(255, 149, 0)
    static let alarmRing = Channels(255, 59, 48)

    /// Кольцо влажности — теми же цветами, что тень на карточке, но плавно.
    static func ringColor(_ moisture: Double) -> Channels {
        if moisture >= Thirst.warnBelow { return calmRing }
        if moisture >= Thirst.alarmBelow {
            return .mix(warnRing, calmRing, (moisture - Thirst.alarmBelow)
                        / (Thirst.warnBelow - Thirst.alarmBelow))
        }
        return .mix(alarmRing, warnRing, moisture / Thirst.alarmBelow)
    }

    /// Появление: пружина с небольшим перелётом, к единице ровно к концу.
    static func unfurl(_ t: Double) -> Double {
        guard t > 0 else { return 0 }
        guard t < 1 else { return 1 }
        return 1 - exp(-6 * t) * cos(7.5 * t)
    }
}

/// Лейка: корпус, ручка, носик и сеточка. Носик смотрит вдоль +X; начало —
/// середина корпуса, вокруг неё лейка и наклоняется.
enum WateringCan {
    static let spoutStart = SIMD2<Float>(0.035, -0.032)
    static let spoutEnd = SIMD2<Float>(0.13, 0.047)

    static var nozzle: SIMD2<Float> {
        let way = spoutEnd - spoutStart
        return way / (way * way).sum().squareRoot()
    }

    /// Откуда вылетает вода: срез сеточки.
    static var tip: SIMD2<Float> { spoutEnd + nozzle * 0.0165 }

    static let mesh: Mesh3D = {
        var can = Sculpt.lathe([
            SIMD2(0, -0.056), SIMD2(0.05, -0.056), SIMD2(0.056, -0.05),
            SIMD2(0.056, 0.035), SIMD2(0.052, 0.047), SIMD2(0.034, 0.056),
            SIMD2(0.03, 0.06), SIMD2(0.03, 0.064), SIMD2(0, 0.064),
        ], segments: 40)
        can.merge(Sculpt.tube([Vec3(spoutStart.x, spoutStart.y, 0),
                               Vec3(spoutEnd.x, spoutEnd.y, 0)],
                              sides: 14) { 0.009 - 0.0035 * $0 })
        let handle = (0 ... 16).map { step -> Vec3 in
            let angle = (190 - 180 * Float(step) / 16) * Float.pi / 180
            return Vec3(-0.01 + 0.045 * cos(angle), 0.055 + 0.045 * sin(angle),
                        0)
        }
        can.merge(Sculpt.tube(handle, sides: 10) { _ in 0.0055 })
        let turn = atan2(nozzle.y, nozzle.x) - Float.pi / 2
        let rose = Sculpt.lathe([
            SIMD2(0, 0), SIMD2(0.007, 0), SIMD2(0.017, 0.013),
            SIMD2(0.0175, 0.016), SIMD2(0, 0.0165),
        ], segments: 20)
            .turned(around: Vec3(0, 0, 1), by: turn)
            .moved(by: Vec3(spoutEnd.x, spoutEnd.y, 0))
        can.merge(rose)
        return can
    }()
}

/// Полив лейкой по секундам: прилетела, наклонилась, льёт, выпрямилась,
/// улетела. Плоскость полива: x — от лейки к растению, ноль — ось горшка; y —
/// от пола. Всё в долях размера растения: растянули его щипком — лейка
/// растёт с ним, а струя всё равно попадает в горшок.
enum Pouring {
    static let arrive = 0.6
    static let tiltIn = 0.45
    static let pour = 2.1
    static let tiltOut = 0.4
    static let leave = 0.55

    static var total: Double { arrive + tiltIn + pour + tiltOut + leave }

    /// Наклон при поливе — пятьдесят пять градусов.
    static let angle: Float = 0.96
    /// Скорость струи при размере один, метры в секунду.
    static let speed: Float = 0.42
    /// Кончик носика над землёй при размере один — не ниже этого.
    static let lowest: Float = 0.1

    /// Лейка держится над листвой: иначе высокое растение она проткнула бы
    /// корпусом. Струя тогда длиннее и проходит сквозь листья — как в жизни.
    static func clearance(over height: Float) -> Float {
        max(lowest, height - Greenhouse.soil + 0.02)
    }
    static let gravity: Float = 9.8
    /// Капель в секунду.
    static let rate = 110.0
    /// Откуда лейка прилетает — назад и вверх от своего места.
    static let approach = SIMD2<Float>(-0.14, 0.12)

    struct Pose: Equatable {
        /// 0 — в стороне, 1 — на месте.
        var travel: Float
        var tilt: Float
        var emit: Bool
        var size: Float
    }

    static func pose(at t: Double) -> Pose {
        let tilted = arrive + tiltIn
        let poured = tilted + pour
        let righted = poured + tiltOut
        switch t {
        case ..<0:
            return Pose(travel: 0, tilt: 0, emit: false, size: 0)
        case ..<arrive:
            let k = Float(back(t / arrive))
            return Pose(travel: k, tilt: 0, emit: false,
                        size: min(max(k, 0), 1))
        case ..<tilted:
            return Pose(travel: 1, tilt: angle * smooth((t - arrive) / tiltIn),
                        emit: false, size: 1)
        case ..<poured:
            return Pose(travel: 1, tilt: angle, emit: true, size: 1)
        case ..<righted:
            return Pose(travel: 1,
                        tilt: angle * (1 - smooth((t - poured) / tiltOut)),
                        emit: false, size: 1)
        case ..<total:
            let k = smooth((t - righted) / leave)
            return Pose(travel: 1 - k, tilt: 0, emit: false, size: 1 - k)
        default:
            return Pose(travel: 0, tilt: 0, emit: false, size: 0)
        }
    }

    private static func smooth(_ x: Double) -> Float {
        let k = min(max(x, 0), 1)
        return Float(k * k * (3 - 2 * k))
    }

    /// С лёгким перелётом — лейка «садится» на место.
    private static func back(_ x: Double) -> Double {
        let k = min(max(x, 0), 1) - 1
        return 1 + 2.2 * k * k * k + 1.2 * k * k
    }

    /// Наклон носиком вниз — по часовой стрелке в плоскости полива.
    static func turn(_ point: SIMD2<Float>, by tilt: Float) -> SIMD2<Float> {
        SIMD2(point.x * cos(tilt) + point.y * sin(tilt),
              -point.x * sin(tilt) + point.y * cos(tilt))
    }

    /// Скорость капли на вылете. Время падения растёт как корень из высоты,
    /// поэтому и скорость — как корень из размера: иначе струя большой лейки
    /// перелетала бы горшок.
    static func launch(scale: Float, tilt: Float = angle) -> SIMD2<Float> {
        let direction: SIMD2<Float> = turn(WateringCan.nozzle, by: tilt)
        let pace: Float = speed * scale.squareRoot()
        return direction * pace
    }

    /// Где встать кончику носика в полный наклон, чтобы струя падала в
    /// середину горшка.
    static func tip(scale: Float, clearance: Float) -> SIMD2<Float> {
        let velocity = launch(scale: scale)
        let height = clearance * scale
        let time = (velocity.y + (velocity.y * velocity.y
            + 2 * gravity * height).squareRoot()) / gravity
        return SIMD2(-velocity.x * time, (Greenhouse.soil + clearance) * scale)
    }

    /// Середина лейки, когда она на месте.
    static func origin(scale: Float, clearance: Float) -> SIMD2<Float> {
        tip(scale: scale, clearance: clearance)
            - turn(WateringCan.tip * scale, by: angle)
    }

    /// Кончик носика при этой позе.
    static func spout(from origin: SIMD2<Float>, tilt: Float,
                      scale: Float) -> SIMD2<Float> {
        origin + turn(WateringCan.tip * scale, by: tilt)
    }
}

/// Капля струи или брызга.
struct Droplet: Sendable {
    var position: Vec3
    var velocity: Vec3
    var age: Float = 0
    /// Брызга от упавшей капли: в землю второй раз не впитывается.
    var splash = false

    mutating func fall(_ dt: Float) {
        velocity.y -= Pouring.gravity * dt
        position += velocity * dt
        age += dt
    }
}
