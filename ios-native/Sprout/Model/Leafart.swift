import Foundation

/// Рисунок листа или лепестка: контур, жилки, окраска. Всё в координатах
/// текстуры: u — поперёк, v — от черешка (0) к кончику (1).
struct LeafLook: Equatable, Sendable {
    enum Outline: Equatable, Sendable {
        /// Яйцевидный — фикус, базилик.
        case ovate
        /// Узкий, с острым кончиком — спатифиллум, листочки.
        case lanceolate
        /// Сердцевидный с лопастями у черешка — монстера, сциндапсус.
        case heart
        /// Эллипс — фикус каучуконосный, орхидея.
        case oval
        /// Меч — сансевиерия.
        case sword
        /// Ремень — хлорофитум, драцена, тюльпан.
        case strap
        /// Круглый с выемкой — фиалка, пеларгония.
        case round
        /// Лопатка, шире к кончику — эхеверия.
        case spoon
        /// Косое крыло — бегония.
        case wing
        /// Лепесток: закруглён к кончику.
        case petal
        /// Покрывало спатифиллума: острое.
        case spathe
        /// Широкий лепесток с узким ноготком и круглым верхом — роза,
        /// фиалка, орхидея.
        case broad
        /// Лепесток тюльпана: шире всего за серединой, кончик круглый.
        case tepal
        /// Губа орхидеи: две боковые лопасти и средняя.
        case lip
    }

    enum Veins: Equatable, Sendable {
        case pinnate(Int)
        case palmate(Int)
        case parallel(Int)
        /// Веером от ноготка — жилки лепестка, тонкие и тающие к краю.
        case fan(Int)
        case none
    }

    enum Pattern: Equatable, Sendable {
        case plain
        /// Светлая полоса по середине — хлорофитум.
        case stripe(Channels, Float)
        /// Кайма — сансевиерия, драцена.
        case edges(Channels, Float)
        /// Мраморные разводы — пёстрый плющ.
        case marbled(Channels, Float)
        /// Поперечные волны — сансевиерия.
        case bands(Channels, Int)
        /// Пятна — бегония.
        case spots(Channels, Int)
        /// Тёмное кольцо — пеларгония.
        case zone(Channels)
        /// Россыпь штрихов — алоэ.
        case speckles(Channels)
        /// Румянец к кончику — эхеверия, лепестки.
        case blush(Channels)
    }

    var outline: Outline
    var aspect: Float
    var veins: Veins = .none
    var base: Channels
    var tip: Channels? = nil
    var vein = Channels(170, 200, 120)
    var margin: Channels? = nil
    var marginWidth: Float = 0.02
    var pattern: Pattern = .plain
    var teeth = 0
    var toothDepth: Float = 0
    /// Зубцы скруглены — городчатый край, как у пеларгонии.
    var scallops = false
    /// Прорези от края к жилке — монстера.
    var slits = 0
    /// Окошки вдоль жилки — монстера.
    var holes = 0
    /// Одна половина шире другой — бегония.
    var asymmetry: Float = 0
    /// Зев: свой цвет у основания, тающий к середине, — глазок фиалки,
    /// тёмное донце тюльпана, жёлтое горло розы.
    var throat: Channels? = nil
    var throatReach: Float = 0.35
    /// Светлая кромка — лепесток на просвет.
    var glow: Float = 0
    /// Пятнистость: у листа живая, у лепестка — шёлк.
    var mottle: Float = 0.2
}

/// Рисует листья, лепестки, кору, горшки и землю. Всё своими руками, по
/// числам: контуры, жилки, пятна — из формул и зерна.
enum Leafart {
    /// Где черешок входит в лист с лопастями: доля длины от низа текстуры.
    static let notch: Float = 0.13

    /// Прежний цвет к новому на долю `k`; прозрачность — полная.
    static func blend(_ old: Ink, _ color: Channels, _ k: Float) -> Ink {
        let ink = color.ink()
        let kept: Ink = old * (1 - k)
        let added: Ink = Ink(ink.x, ink.y, ink.z, 1) * k
        return kept + added
    }

    // MARK: - Контур

    /// Полуширина по длине, в долях наибольшей.
    static func half(_ outline: LeafLook.Outline, _ t: Float) -> Float {
        let t = min(max(t, 0), 1)
        switch outline {
        case .ovate: return pow(sin(Float.pi * pow(t, 0.8)), 0.8)
        case .lanceolate: return pow(sin(Float.pi * pow(t, 0.62)), 1.1)
        case .heart: return pow(sin(Float.pi * (0.14 + 0.86 * pow(t, 0.9))), 0.7)
        case .oval: return pow(max(0, 1 - pow(2 * t - 1, 2)), 0.5)
            * (t > 0.9 ? 1 - (t - 0.9) * 4 : 1)
        case .sword: return min(1, t * 6) * pow(1 - t, 0.3)
        case .strap: return min(1, t * 10) * pow(max(0, 1 - pow(t, 4)), 0.5)
        case .round: return pow(max(0, sin(Float.pi * (0.1 + 0.9 * t))), 0.55)
        case .spoon: return pow(sin(Float.pi * pow(t, 1.5)), 0.7)
        case .wing: return pow(sin(Float.pi * (0.1 + 0.9 * pow(t, 0.75))), 0.8)
        case .petal: return pow(sin(Float.pi * pow(t, 0.55)), 0.55)
        case .spathe: return pow(sin(Float.pi * pow(t, 0.7)), 0.9)
        case .broad:
            // Верх — полукруг, низ сужается в ноготок.
            let round = max(0, t * (1 - t)).squareRoot() * 2
            return round * pow(min(t / 0.4, 1), 0.9)
        case .tepal: return pow(sin(Float.pi * pow(t, 1.36)), 0.5)
        case .lip:
            let sides = 0.95 * exp(-pow((t - 0.3) / 0.16, 2))
            let middle = 0.62 * exp(-pow((t - 0.8) / 0.14, 2))
            let neck = 0.3 * pow(sin(Float.pi * pow(t, 0.5)), 0.6)
            return min(1, t * 8) * max(sides, middle, neck)
        }
    }

    /// У этих листьев лопасти уходят ниже черешка.
    static func lobed(_ outline: LeafLook.Outline) -> Bool {
        outline == .heart || outline == .round || outline == .wing
    }

    /// Край с зубцами: пила или городки.
    static func edge(_ look: LeafLook, _ t: Float) -> Float {
        let width = half(look.outline, t)
        guard look.teeth > 0 else { return width }
        let phase = t * Float(look.teeth)
        let tooth = look.scallops
            ? abs(sin(Float.pi * phase))
            : phase - floor(phase)
        return width * (1 - look.toothDepth * (1 - tooth))
    }

    /// Контур листа в координатах текстуры; у листьев с лопастями низ
    /// закруглён к выемке черешка.
    static func outline(_ look: LeafLook, steps: Int = 96) -> [SIMD2<Float>] {
        let reach: Float = 0.48
        func side(_ sign: Float, _ t: Float) -> SIMD2<Float> {
            let lean = sign < 0 ? 1 + look.asymmetry : 1 - look.asymmetry
            return SIMD2(0.5 + sign * reach * edge(look, t) * lean, t)
        }
        let rise = (0 ... steps).map { Float($0) / Float(steps) }
        var right = rise.map { side(1, $0) }
        var left = rise.reversed().map { side(-1, $0) }
        if lobed(look.outline) {
            let low = SIMD2<Float>(0.5, notch)
            let rightLobe = lobe(from: low, to: right[0])
            let leftLobe = lobe(from: left[left.count - 1], to: low)
            right = rightLobe + right
            left += leftLobe
        }
        return right + left
    }

    /// Скруглённая лопасть от выемки к краю.
    private static func lobe(from a: SIMD2<Float>,
                             to b: SIMD2<Float>) -> [SIMD2<Float>] {
        let bend = SIMD2<Float>((a.x + b.x) / 2, -0.02)
        return (0 ..< 8).map { step in
            let t = Float(step) / 8
            let first: SIMD2<Float> = a * ((1 - t) * (1 - t))
            let middle: SIMD2<Float> = bend * (2 * (1 - t) * t)
            let last: SIMD2<Float> = b * (t * t)
            return first + middle + last
        }
    }

    /// Где начинается жилка: у лопастных — в выемке.
    static func start(_ outline: LeafLook.Outline) -> Float {
        lobed(outline) ? notch : 0.02
    }

    // MARK: - Лист

    /// Цвет с прозрачностью по контуру и карта нормалей для рельефа жилок.
    static func leaf(_ look: LeafLook, seed: UInt32,
                     height: Int = 512) -> (color: Picture, normal: Picture) {
        let width = max(32, Int((Float(height) * look.aspect / 8).rounded()) * 8)
        var picture = Picture(width: width, height: height, fill: look.base.ink())
        let tip = (look.tip ?? look.base).ink()
        let far = SIMD3(tip.x, tip.y, tip.z)
        // Переход к кончику и лёгкая пятнистость — живой лист не заливкой.
        picture.shade { uv, old in
            let blend = pow(uv.y, 1.4)
            let near = SIMD3(old.x, old.y, old.z) * (1 - blend)
            var color = near + far * blend
            let mottle = Noise.fractal(uv.x, uv.y * 2, cells: 6, seed: seed)
            color *= 1 - look.mottle / 2 + look.mottle * mottle
            // У жилки чуть светлее, к краю темнее — объём без света.
            color *= 1.04 - 0.12 * abs(uv.x - 0.5) * 2
            return Ink(color.x, color.y, color.z, 1)
        }
        if let throat = look.throat {
            let reach = look.throatReach
            picture.shade { uv, old in
                let d = ((uv.x - 0.5) * (uv.x - 0.5) * 1.4 + uv.y * uv.y)
                    .squareRoot()
                let k = pow(max(0, 1 - d / reach), 1.3)
                return Leafart.blend(old, throat, k)
            }
        }
        paint(look.pattern, on: &picture, look: look, seed: seed)
        var relief = Relief(width: max(16, width / 2), height: height / 2)
        veins(look, picture: &picture, relief: &relief)
        if look.glow > 0 {
            picture.shade { uv, old in
                let reach = max(half(look.outline, uv.y) * 0.48, 1e-3)
                let away = abs(uv.x - 0.5) / reach
                let rim = max(away, uv.y > 0.8 ? (uv.y - 0.8) / 0.2 : 0)
                let k = pow(min(max((rim - 0.7) / 0.3, 0), 1), 2) * look.glow
                return Leafart.blend(old, Channels(255, 252, 246), k)
            }
        }
        if let margin = look.margin {
            let line = outline(look)
            picture.stroke(line + [line[0]], width: { _ in look.marginWidth },
                           margin.ink())
        }
        var cover = Picture.coverage(outline(look).map(picture.spot),
                                     width: width, height: height)
        cut(look, cover: &cover, width: width, height: height, seed: seed)
        picture.clip(to: cover)
        relief.soften(1)
        return (picture, relief.normals(strength: 6))
    }

    private static func paint(_ pattern: LeafLook.Pattern,
                              on picture: inout Picture, look: LeafLook,
                              seed: UInt32) {
        switch pattern {
        case .plain:
            break
        case .stripe(let color, let share):
            let band = (0 ... 48).map { step -> SIMD2<Float> in
                let t = Float(step) / 48
                return SIMD2(0.5 + share * half(look.outline, t) * 0.48, t)
            } + (0 ... 48).reversed().map { step -> SIMD2<Float> in
                let t = Float(step) / 48
                return SIMD2(0.5 - share * half(look.outline, t) * 0.48, t)
            }
            picture.fill(band, color.ink(0.92))
        case .edges(let color, let share):
            picture.shade { uv, old in
                let reach = half(look.outline, uv.y) * 0.48
                let away = abs(uv.x - 0.5)
                guard reach > 0, away > reach * (1 - share) else { return old }
                let ink = color.ink()
                return Ink(ink.x, ink.y, ink.z, 1)
            }
        case .marbled(let color, let amount):
            picture.shade { uv, old in
                let n = Noise.fractal(uv.x * 1.5, uv.y * 3, cells: 5,
                                      seed: seed &+ 11)
                let k = min(max((n - (1 - amount)) * 6, 0), 1)
                return Leafart.blend(old, color, k)
            }
        case .bands(let color, let count):
            picture.shade { uv, old in
                let n = Noise.value(uv.x, uv.y, cells: 7, seed: seed &+ 5)
                let turn: Float = uv.y * Float(count) + uv.x * 0.6 + n * 0.8
                let wave = sin(turn * 2 * .pi)
                let k = max(0, wave - 0.2) * 0.8
                return Leafart.blend(old, color, k)
            }
        case .spots(let color, let count):
            var rng = Seeded("spots-\(seed)")
            for _ in 0 ..< count {
                let v = Float.random(in: 0.12 ... 0.85, using: &rng)
                let reach = half(look.outline, v) * 0.4
                let u = 0.5 + Float.random(in: -reach ... reach, using: &rng)
                picture.disc(SIMD2(u, v),
                             radius: Float.random(in: 0.012 ... 0.03, using: &rng),
                             color.ink(0.85))
            }
        case .zone(let color):
            picture.shade { uv, old in
                let dx = (uv.x - 0.5) * 2
                let dy = (uv.y - 0.45) * 2
                let ring = abs((dx * dx + dy * dy).squareRoot() - 0.62)
                let k = max(0, 1 - ring / 0.14) * 0.7
                return Leafart.blend(old, color, k)
            }
        case .speckles(let color):
            var rng = Seeded("speckles-\(seed)")
            for _ in 0 ..< 70 {
                let v = Float.random(in: 0.05 ... 0.9, using: &rng)
                let reach = half(look.outline, v) * 0.42
                let u = 0.5 + Float.random(in: -reach ... reach, using: &rng)
                picture.disc(SIMD2(u, v), radius: 0.035, squash: 0.18,
                             color.ink(0.8))
            }
        case .blush(let color):
            picture.shade { uv, old in
                let k = pow(max(0, uv.y - 0.55) / 0.45, 1.5) * 0.85
                return Leafart.blend(old, color, k)
            }
        }
    }

    /// Жилки: цветом на картинке и бороздкой на рельефе. Главная приподнята.
    private static func veins(_ look: LeafLook, picture: inout Picture,
                              relief: inout Relief) {
        let from = start(look.outline)
        let color = look.vein.ink(0.85)
        switch look.veins {
        case .none:
            return
        case .pinnate(let count):
            let spine = (0 ... 24).map {
                SIMD2<Float>(0.5, from + (0.97 - from) * Float($0) / 24)
            }
            picture.stroke(spine, width: { 0.03 * (1 - $0 * 0.8) }, color)
            relief.stroke(spine, width: { 0.05 * (1 - $0 * 0.8) }, by: 0.6)
            for index in 1 ... count {
                let v = from + (0.9 - from) * Float(index) / Float(count + 1)
                for sign: Float in [1, -1] {
                    let path = lateral(look, from: v, sign: sign)
                    picture.stroke(path, width: { 0.012 * (1 - $0 * 0.7) },
                                   color)
                    relief.stroke(path, width: { 0.03 * (1 - $0 * 0.6) },
                                  by: -0.45)
                }
            }
        case .palmate(let count):
            let center = SIMD2<Float>(0.5, from)
            for index in 0 ..< count {
                let angle = Float.pi * (0.12 + 0.76 * Float(index)
                    / Float(max(count - 1, 1)))
                let end = SIMD2<Float>(0.5 + cos(angle) * 0.44,
                                       from + sin(angle) * (0.95 - from))
                let path = (0 ... 12).map { step -> SIMD2<Float> in
                    let t = Float(step) / 12
                    let straight: SIMD2<Float> = center * (1 - t)
                    return straight + end * t
                }
                picture.stroke(path, width: { 0.02 * (1 - $0 * 0.8) }, color)
                relief.stroke(path, width: { 0.035 * (1 - $0 * 0.7) }, by: -0.4)
            }
        case .fan(let count):
            let root = SIMD2<Float>(0.5, from)
            for index in 0 ..< count {
                let share = (Float(index) + 0.5) / Float(count) * 2 - 1
                let path = (0 ... 16).map { step -> SIMD2<Float> in
                    let t = from + (0.93 - from) * Float(step) / 16
                    let reach = half(look.outline, t) * 0.44 * share
                    // Жилка идёт от ноготка и расходится с лепестком.
                    let ease = pow(Float(step) / 16, 0.7)
                    return SIMD2(root.x + reach * ease, t)
                }
                picture.stroke(path, width: { 0.009 * (1 - $0 * 0.75) },
                               look.vein.ink(0.45 * (1 - abs(share) * 0.4)))
                relief.stroke(path, width: { _ in 0.02 }, by: -0.2)
            }
        case .parallel(let count):
            for index in 0 ... count {
                let share = Float(index) / Float(max(count, 1)) * 2 - 1
                let path = (0 ... 24).map { step -> SIMD2<Float> in
                    let t = from + (0.96 - from) * Float(step) / 24
                    return SIMD2(0.5 + share * 0.4 * half(look.outline, t), t)
                }
                let main = index * 2 == count
                picture.stroke(path, width: { _ in main ? 0.035 : 0.012 },
                               look.vein.ink(main ? 0.8 : 0.35))
                relief.stroke(path, width: { _ in main ? 0.05 : 0.02 },
                              by: main ? 0.4 : -0.25)
            }
        }
    }

    /// Боковая жилка: от главной к краю, изгибаясь к кончику.
    private static func lateral(_ look: LeafLook, from v: Float,
                                sign: Float) -> [SIMD2<Float>] {
        let end = min(v + 0.14, 0.97)
        let reach = half(look.outline, end) * 0.46
        let a = SIMD2<Float>(0.5, v)
        let b = SIMD2<Float>(0.5 + sign * reach * 0.45, v + 0.05)
        let c = SIMD2<Float>(0.5 + sign * reach * 0.94, end)
        return (0 ... 10).map { step in
            let t = Float(step) / 10
            let first: SIMD2<Float> = a * ((1 - t) * (1 - t))
            let middle: SIMD2<Float> = b * (2 * (1 - t) * t)
            let last: SIMD2<Float> = c * (t * t)
            return first + middle + last
        }
    }

    /// Прорези и окошки монстеры — стираются из покрытия.
    private static func cut(_ look: LeafLook, cover: inout [Float], width: Int,
                            height: Int, seed: UInt32) {
        guard look.slits > 0 || look.holes > 0 else { return }
        let from = start(look.outline)
        var rng = Seeded("cut-\(seed)")
        func erase(_ shape: [SIMD2<Float>]) {
            let pixels = shape.map {
                SIMD2($0.x * Float(width), (1 - $0.y) * Float(height))
            }
            let hole = Picture.coverage(pixels, width: width, height: height)
            for index in cover.indices { cover[index] *= 1 - hole[index] }
        }
        let gaps = look.slits + 1
        for index in 1 ... max(look.slits, look.holes) {
            let v = from + (0.86 - from) * (Float(index) - 0.5) / Float(gaps)
            for sign: Float in [1, -1] {
                if index <= look.slits {
                    let reach = half(look.outline, v + 0.1) * 0.5
                    let depth = Float.random(in: 0.42 ... 0.62, using: &rng)
                    let wide = Float.random(in: 0.012 ... 0.022, using: &rng)
                    let outer = SIMD2<Float>(0.5 + sign * reach * 1.1, v + 0.1)
                    let inner = SIMD2<Float>(0.5 + sign * reach * (1 - depth),
                                             v + 0.02)
                    erase([outer + SIMD2(0, wide * 1.5), inner,
                           outer - SIMD2(0, wide * 1.5)])
                }
                if index <= look.holes {
                    let reach = half(look.outline, v) * 0.48
                    let center = SIMD2<Float>(0.5 + sign * reach * 0.3,
                                              v + 0.035)
                    let radius = Float.random(in: 0.025 ... 0.045, using: &rng)
                    let aspect = Float(width) / Float(height)
                    erase((0 ..< 16).map { step in
                        let angle = 2 * Float.pi * Float(step) / 16
                        return center + SIMD2(cos(angle) * radius * 0.7,
                                              sin(angle) * radius * aspect * 1.3)
                    })
                }
            }
        }
    }

    // MARK: - Вайя

    /// Вайя папоротника: стержень и десятки перышек по обе стороны, к
    /// кончику мельче. Всё рисуется на прозрачном — контур даёт сам рисунок.
    static func frond(_ color: Channels, seed: UInt32) -> Picture {
        let height = 512
        let width = 128
        var picture = Picture(width: width, height: height)
        var rng = Seeded("frond-\(seed)")
        let w = Float(width)
        let h = Float(height)
        func uv(_ pixel: SIMD2<Float>) -> SIMD2<Float> {
            SIMD2(pixel.x / w, 1 - pixel.y / h)
        }
        let pairs = 30
        for pair in 0 ..< pairs {
            let v = 0.03 + 0.94 * Float(pair) / Float(pairs)
            let reach = pow(sin(Float.pi * (0.08 + 0.92 * v)), 0.7)
            let length = w * 0.47 * reach
            let breadth = length * 0.3
            for side: Float in [1, -1] {
                let root = SIMD2<Float>(w / 2, (1 - v) * h
                    + (side > 0 ? 0 : 3))
                let angle = side * 1.05
                let along = SIMD2<Float>(sin(angle), -cos(angle))
                let across = SIMD2<Float>(-along.y, along.x)
                let shade = Float.random(in: 0.85 ... 1.08, using: &rng)
                let tint = color.ink()
                let ink = Ink(tint.x * shade, tint.y * shade, tint.z * shade, 1)
                let outline = (0 ... 12).map { step -> SIMD2<Float> in
                    let t = Float(step) / 12
                    let wide = breadth / 2 * pow(sin(Float.pi * pow(t, 0.7)), 0.9)
                    return uv(root + along * (length * t) + across * wide)
                } + (0 ... 12).reversed().map { step -> SIMD2<Float> in
                    let t = Float(step) / 12
                    let wide = breadth / 2 * pow(sin(Float.pi * pow(t, 0.7)), 0.9)
                    return uv(root + along * (length * t) - across * wide)
                }
                picture.fill(outline, ink)
                let spine = (0 ... 6).map { step -> SIMD2<Float> in
                    uv(root + along * (length * 0.9 * Float(step) / 6))
                }
                picture.stroke(spine, width: { _ in 0.012 },
                               Ink(tint.x * 1.2, tint.y * 1.15, tint.z * 1.1, 0.6))
            }
        }
        let rachis = (0 ... 24).map {
            SIMD2<Float>(0.5, 0.97 * Float($0) / 24)
        }
        picture.stroke(rachis, width: { 0.05 * (1 - $0 * 0.7) },
                       Channels(110, 130, 70).ink())
        return picture
    }

    // MARK: - Прочее

    /// Кора или стебель: продольные волокна и, если надо, узлы кольцами.
    static func bark(_ color: Channels, dark: Channels, rings: Int = 0,
                     seed: UInt32) -> Picture {
        var picture = Picture(width: 64, height: 256, fill: color.ink())
        picture.shade { uv, _ in
            let fiber = Noise.fractal(uv.x * 4, uv.y * 0.6, cells: 8, seed: seed)
            var k = fiber * 0.55
            if rings > 0 {
                let ring = abs(sin(uv.y * Float(rings) * .pi))
                k += max(0, 0.12 - ring) * 4
            }
            let base = color.ink()
            let deep = dark.ink()
            let mix = base * (1 - k) + deep * k
            return Ink(mix.x, mix.y, mix.z, 1)
        }
        return picture
    }

    enum Glaze: Equatable, Sendable {
        /// Терракота: пористая, матовая.
        case clay
        /// Глазурь: гладкая, с редкими крапинками.
        case glaze
        /// Бетон: серый, в раковинах.
        case stone
    }

    /// Горшок: текстура сходится на шве — шум с периодом по u.
    static func pot(_ glaze: Glaze, _ color: Channels, seed: UInt32) -> Picture {
        var picture = Picture(width: 256, height: 128, fill: color.ink())
        picture.shade { uv, _ in
            let base = color.ink()
            switch glaze {
            case .clay:
                let pores = Noise.fractal(uv.x, uv.y * 0.5, cells: 16, seed: seed)
                let k = 0.82 + 0.3 * pores
                return Ink(base.x * k, base.y * k, base.z * k, 1)
            case .glaze:
                let speck = Noise.value(uv.x, uv.y * 0.5, cells: 64,
                                        seed: seed) > 0.93 ? 0.7 : 1
                let sheen = 0.95 + 0.08 * uv.y
                let k = Float(speck) * sheen
                return Ink(base.x * k, base.y * k, base.z * k, 1)
            case .stone:
                let grain = Noise.fractal(uv.x, uv.y * 0.5, cells: 24,
                                          seed: seed)
                let pit = Noise.value(uv.x, uv.y * 0.5, cells: 48,
                                      seed: seed &+ 3) > 0.9 ? 0.75 : 1
                let k = (0.85 + 0.25 * grain) * Float(pit)
                return Ink(base.x * k, base.y * k, base.z * k, 1)
            }
        }
        return picture
    }

    /// Земля: крошка разных оттенков и белые крупинки перлита.
    static func soil(_ color: Channels, seed: UInt32) -> Picture {
        var picture = Picture(width: 256, height: 256, fill: color.ink())
        picture.shade { uv, _ in
            let crumb = Noise.fractal(uv.x, uv.y, cells: 24, seed: seed)
            let k = 0.7 + 0.55 * crumb
            let base = color.ink()
            return Ink(base.x * k, base.y * k, base.z * k, 1)
        }
        var rng = Seeded("soil-\(seed)")
        for _ in 0 ..< 60 {
            picture.disc(SIMD2(Float.random(in: 0 ... 1, using: &rng),
                               Float.random(in: 0 ... 1, using: &rng)),
                         radius: Float.random(in: 0.004 ... 0.01, using: &rng),
                         Ink(0.93, 0.92, 0.88, 0.95))
        }
        return picture
    }

    /// Кожица кактуса и суккулентов: тон с мелкими точками.
    /// Початок спатифиллума: сотни бугорков-цветочков рядами со сдвигом.
    static func spadix(_ color: Channels) -> Picture {
        var picture = Picture(width: 64, height: 128, fill: color.ink())
        picture.shade { uv, _ in
            let row = (uv.y * 40).rounded(.down)
            let shift: Float = row.truncatingRemainder(dividingBy: 2) == 0
                ? 0 : 0.5
            let du = (uv.x * 10 + shift).truncatingRemainder(dividingBy: 1)
                - 0.5
            let dv = (uv.y * 40).truncatingRemainder(dividingBy: 1) - 0.5
            let bump = max(0, 1 - (du * du + dv * dv).squareRoot() * 2.2)
            let k = 0.82 + 0.3 * bump
            let base = color.ink()
            return Ink(base.x * k, base.y * k, base.z * (k - 0.04), 1)
        }
        return picture
    }

    static func skin(_ color: Channels, seed: UInt32) -> Picture {
        var picture = Picture(width: 128, height: 256, fill: color.ink())
        picture.shade { uv, _ in
            let dot = Noise.value(uv.x, uv.y, cells: 48, seed: seed)
            let k = (0.92 + 0.12 * uv.y) * (dot > 0.85 ? 1.12 : 1)
            let base = color.ink()
            return Ink(base.x * k, base.y * k, base.z * k, 1)
        }
        return picture
    }
}
