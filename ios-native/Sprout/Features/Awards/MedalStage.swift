import RealityKit
import SwiftUI
import UIKit

/// Объёмная медаль: настоящий диск с ободком и насечкой по гурту, а
/// растение и чеканка на поле — картой нормалей под светом студии:
/// поворачиваешь медаль — и блики бегут по листьям. На обороте —
/// гравировка: за что, когда и какой уровень. Крутится пальцем, как в
/// «Фитнесе»; отпустили — доворачивается лицом, с разгону — через лишний
/// оборот. Позади — искры её металла: чем быстрее крутится, тем их больше.
/// Появляется как карточка растения — растёт на месте, лицом к зрителю.
struct MedalStage: View {
    let rank: Rank
    let earned: Bool

    /// Дата на обороте; у неполученной — «Ещё впереди».
    var date: Date?

    @State private var rig = MedalRig()
    @State private var sparks = Sparks()
    @State private var ready = false

    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        ZStack {
            MedalSparks(rig: rig, sparks: sparks, alloy: rank.alloy,
                        earned: earned, lit: ready)
                .allowsHitTesting(false)
            RealityView { content in
                // По умолчанию на iOS — камера AR; медали нужна своя сцена.
                content.camera = .virtual
                let made = await MedalCraft.medal(rank, earned: earned,
                                                  date: date)
                content.add(made.root)
                content.add(MedalCraft.camera())
                for light in MedalCraft.lights() { content.add(light) }
                rig.medal = made.spinner
                ready = true
                if !still { sparks.burst(earned ? 90 : 24) }
            }
            .backgroundStyle(Color.clear)
            .scaleEffect(ready || still ? 1 : Motion.medalScale)
            .opacity(ready ? 1 : 0)
            .animation(still ? nil : Motion.medal, value: ready)
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { rig.turn(by: $0.translation.width) }
            .onEnded { rig.release(speed: $0.velocity.width) })
        .accessibilityElement()
        .accessibilityLabel(rank.title)
        .accessibilityAddTraits(.isImage)
    }
}

/// Поворот медали. Своим циклом, а не анимацией RealityKit: та вела бы
/// поворот кратчайшей дугой, и лишний оборот с разгона схлопнулся бы. Знает
/// и свою скорость — по ней искрят частицы.
@MainActor
final class MedalRig {
    var medal: Entity?

    private var angle: Float = 0
    private var start: Float?
    private var motion: Task<Void, Never>?

    /// Радиан в секунду, сглаженно; и когда медаль в последний раз двигалась.
    private var speed: Double = 0
    private var moved = Date.distantPast
    private var previous: Float = 0

    /// Пунктов пальца на радиан: ширина медали — примерно пол-оборота.
    private static let reach: Float = 90

    func turn(by width: CGFloat) {
        motion?.cancel()
        if start == nil { start = angle }
        angle = (start ?? 0) + Float(width) / Self.reach
        apply()
    }

    /// Разгон добавляет оборотов; встаёт медаль всегда лицом.
    func release(speed: CGFloat) {
        start = nil
        let fling = Float(speed) / Self.reach * 0.3
        let turn = 2 * Float.pi
        let target = ((angle + fling) / turn).rounded() * turn
        glide(to: target, seconds: 0.9 + Double(min(abs(fling), 12)) * 0.05)
        Feel.pick()
    }

    /// Скорость на сейчас: остановилась — искры гаснут за полсекунды.
    func spin(at date: Date) -> Double {
        speed * exp(-max(date.timeIntervalSince(moved), 0) * 6)
    }

    private func glide(to target: Float, seconds: Double) {
        motion?.cancel()
        let from = angle
        motion = Task { @MainActor in
            let clock = ContinuousClock()
            let begin = clock.now
            while !Task.isCancelled {
                let t = min((clock.now - begin) / .seconds(seconds), 1)
                let eased = 1 - pow(1 - t, 3)
                angle = from + (target - from) * Float(eased)
                apply()
                if t >= 1 { break }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func apply() {
        let now = Date()
        let step = now.timeIntervalSince(moved)
        if step > 0.001, step < 0.25 {
            let instant = Double(angle - previous) / step
            speed = speed * 0.6 + instant * 0.4
        } else {
            speed = 0
        }
        previous = angle
        moved = now
        medal?.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
    }
}

/// Сетки, материалы, свет и камера медали.
@MainActor
enum MedalCraft {
    /// Ободок: от края тыла наружу, по кромке вверх, через валик к краю
    /// поля. Кромка — с насечкой, как гурт монеты. Метры.
    static let rim = Sculpt.lathe([
        SIMD2(0.043, -0.004), SIMD2(0.046, -0.004), SIMD2(0.0492, -0.0034),
        SIMD2(0.05, -0.0015), SIMD2(0.05, 0.0015), SIMD2(0.0492, 0.0038),
        SIMD2(0.0465, 0.0046), SIMD2(0.0432, 0.0042), SIMD2(0.0415, 0.0028),
        SIMD2(0.041, 0.0022),
    ], segments: 600, ribs: 150, ribDepth: 0.006, ribFrom: 0.0499)

    /// Поле — отдельной сеткой, с текстурой сверху: на нём барельеф.
    static let face = Sculpt.lathe([SIMD2(0.041, 0.0022), SIMD2(0, 0.0022)],
                                   segments: 192)
        .mappedFromAbove(radius: 0.041)

    /// Тыл — своей сеткой и текстурой. Его видно, когда медаль повёрнута
    /// на пол-оборота: право и лево там меняются местами, поэтому u идёт
    /// навстречу x — иначе надпись читалась бы в зеркале.
    static let back: Mesh3D = {
        var mesh = Sculpt.lathe([SIMD2(0, -0.004), SIMD2(0.043, -0.004)],
                                segments: 192)
        let radius: Float = 0.043
        mesh.uvs = mesh.positions.map {
            SIMD2(0.5 - $0.x / (2 * radius), 0.5 + $0.z / (2 * radius))
        }
        return mesh
    }()

    /// Медаль — перед началом координат, камера — в нём: так медаль видна и
    /// своей камерой, и камерой по умолчанию, что смотрит из нуля вдоль −z.
    static let spot = SIMD3<Float>(0, 0, -0.26)

    /// Корень стоит на месте и держит свет студии, крутится — вложенная
    /// медаль: отражения остаются в комнате, и блики бегут по металлу.
    struct Made {
        let root: Entity
        let spinner: Entity
    }

    static func medal(_ rank: Rank, earned: Bool, date: Date?) async -> Made {
        let root = Entity()
        root.position = spot
        let spinner = Entity()
        root.addChild(spinner)
        let coin = Entity()
        // Диск лежит в плоскости пола; встаёт лицом к зрителю.
        coin.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        spinner.addChild(coin)
        let tone = earned ? rank.alloy.body : Alloy.steel
        let polished = Craft.paint(tone, rough: earned ? 0.16 : 0.45,
                                   metal: earned ? 0.95 : 0.55)
        var satin = Craft.paint(tone, rough: earned ? 0.3 : 0.6,
                                metal: earned ? 0.9 : 0.5)
        var engraved = satin
        if let image = Craft.image(await Medals.shared.normals(rank)),
           let relief = try? await TextureResource(
               image: image, options: .init(semantic: .normal)) {
            satin.normal = .init(texture: .init(relief))
        }
        let letters = lettering(rank, earned: earned, date: date,
                                size: Medals.depth)
        if let image = Craft.image(await Medals.shared.back(letters)),
           let relief = try? await TextureResource(
               image: image, options: .init(semantic: .normal)) {
            engraved.normal = .init(texture: .init(relief))
        }
        let models = [Craft.model(rim, polished), Craft.model(face, satin),
                      Craft.model(back, engraved)].compactMap { $0 }
        for model in models { coin.addChild(model) }
        if let room = Craft.image(await Medals.shared.room()),
           let environment = try? await EnvironmentResource(
               equirectangular: room) {
            let studio = Entity()
            studio.components.set(ImageBasedLightComponent(
                source: .single(environment), intensityExponent: 0.8))
            root.addChild(studio)
            for model in models {
                model.components.set(
                    ImageBasedLightReceiverComponent(imageBasedLight: studio))
            }
        }
        return Made(root: root, spinner: spinner)
    }

    /// Гравировка оборота — белые буквы на чёрном, доли единицы, ряды
    /// сверху вниз: название ступени, дата и уровень. Буквы рисует UIKit —
    /// кириллицу своими руками не нарисовать.
    static func lettering(_ rank: Rank, earned: Bool, date: Date?,
                          size: Int) -> [Float] {
        let side = CGFloat(size)
        func font(_ share: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let plain = UIFont.systemFont(ofSize: side * share, weight: weight)
            guard let rounded = plain.fontDescriptor.withDesign(.rounded) else {
                return plain
            }
            return UIFont(descriptor: rounded, size: side * share)
        }
        let when = earned
            ? (date ?? Date()).formatted(Date.FormatStyle(date: .long,
                                                          time: .omitted)
                .locale(Lang.locale))
            : Lang.text("Ещё впереди")
        let lines: [(String, UIFont)] = [
            (rank.title, font(0.085, .bold)),
            (when, font(0.052, .semibold)),
            (Lang.format("Уровень %1$lld из %2$lld", rank.level,
                         rank.award.levels), font(0.045, .medium)),
        ]
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let width = side * 0.62
        let texts = lines.map { text, font in
            NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ])
        }
        let heights = texts.map {
            ceil($0.boundingRect(with: CGSize(width: width,
                                              height: .greatestFiniteMagnitude),
                                 options: [.usesLineFragmentOrigin],
                                 context: nil).height)
        }
        let gap = side * 0.03
        let total = heights.reduce(0, +) + gap * CGFloat(texts.count - 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format).image {
            context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            var top = (side - total) / 2
            for (text, height) in zip(texts, heights) {
                text.draw(with: CGRect(x: (side - width) / 2, y: top,
                                       width: width, height: height),
                          options: [.usesLineFragmentOrigin], context: nil)
                top += height + gap
            }
        }
        var gray = [UInt8](repeating: 0, count: size * size)
        guard let picture = image.cgImage else {
            return [Float](repeating: 0, count: size * size)
        }
        gray.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: size,
                                    height: size, bitsPerComponent: 8,
                                    bytesPerRow: size,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue)
            context?.draw(picture, in: CGRect(x: 0, y: 0, width: size,
                                              height: size))
        }
        return gray.map { Float($0) / 255 }
    }

    static func camera() -> Entity {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 38
        camera.look(at: spot, from: .zero, relativeTo: nil)
        return camera
    }

    /// Ключевой свет слева сверху — как на картинке медали, заполняющий
    /// справа снизу и контровой сзади. Отражения даёт студия, свет — лепку
    /// барельефа.
    static func lights() -> [Entity] {
        let key = DirectionalLight()
        key.light.intensity = 2600
        key.look(at: spot, from: spot + SIMD3(-0.3, 0.35, 0.45), relativeTo: nil)
        let fill = PointLight()
        fill.light.intensity = 11_000
        fill.light.attenuationRadius = 2
        fill.position = spot + SIMD3(0.22, -0.12, 0.3)
        let back = PointLight()
        back.light.intensity = 9_000
        back.light.attenuationRadius = 2
        back.position = spot + SIMD3(0, 0.2, -0.25)
        return [key, fill, back]
    }
}

/// Искры позади медали: ореол её металла и частицы, что слетают с кромки,
/// когда медаль крутят. Стоит — редкие огоньки мерцают вокруг; раскрутили —
/// сыплются веером. Холстом по кадрам, как блёстки праздника.
struct MedalSparks: View {
    let rig: MedalRig
    let sparks: Sparks
    let alloy: Alloy
    let earned: Bool

    /// Медаль уже на месте — до этого и ореолу светить незачем.
    let lit: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        TimelineView(.animation(paused: still)) { frame in
            Canvas { context, size in
                let spin = rig.spin(at: frame.date)
                let energy = min(abs(spin) / 8, 1.6)
                if !still {
                    sparks.step(to: frame.date, energy: earned ? energy : energy * 0.4,
                                spin: spin, idle: earned ? 7 : 2, in: size)
                }
                halo(&context, size: size, energy: energy)
                draw(&context)
            }
        }
        .opacity(lit ? 1 : 0)
        .animation(Motion.medal, value: lit)
    }

    private var light: Channels { earned ? alloy.light : Alloy.steelLight }
    private var deep: Channels { earned ? alloy.body : Alloy.steel }

    private func colour(_ channels: Channels) -> Color {
        Color(red: channels.red / 255, green: channels.green / 255,
              blue: channels.blue / 255)
    }

    /// Ореол — мягкий круг цвета металла; разгорается, пока медаль крутится.
    private func halo(_ context: inout GraphicsContext, size: CGSize,
                      energy: Double) {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.48
        let strength = (scheme == .dark ? 0.22 : 0.14) + 0.2 * min(energy, 1)
        let tone = colour(scheme == .dark ? light : deep)
        context.fill(
            Path(ellipseIn: CGRect(x: middle.x - radius, y: middle.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [tone.opacity(earned ? strength : strength / 2),
                                  tone.opacity(0)]),
                center: middle, startRadius: radius * 0.3,
                endRadius: radius))
    }

    private func draw(_ context: inout GraphicsContext) {
        var layer = context
        // В темноте искры светят, складываясь; на светлом фоне сложение
        // дало бы белое на белом — там они просто цветные.
        if scheme == .dark { layer.blendMode = .plusLighter }
        let bright = colour(light)
        let dim = colour(deep)
        for mote in sparks.motes {
            let alpha = mote.alpha
            guard alpha > 0.01 else { continue }
            let tint = scheme == .dark
                ? (mote.tone > 0.7 ? Color.white : bright)
                : (mote.tone > 0.6 ? bright : dim)
            let glow = mote.size * 2.8
            layer.fill(Path(ellipseIn: CGRect(x: mote.x - glow, y: mote.y - glow,
                                              width: glow * 2, height: glow * 2)),
                       with: .color(tint.opacity(alpha * 0.22)))
            if mote.star {
                let arm = mote.size * 3
                let waist = mote.size * 0.45
                var star = Path()
                star.move(to: CGPoint(x: mote.x, y: mote.y - arm))
                star.addLine(to: CGPoint(x: mote.x + waist, y: mote.y - waist))
                star.addLine(to: CGPoint(x: mote.x + arm, y: mote.y))
                star.addLine(to: CGPoint(x: mote.x + waist, y: mote.y + waist))
                star.addLine(to: CGPoint(x: mote.x, y: mote.y + arm))
                star.addLine(to: CGPoint(x: mote.x - waist, y: mote.y + waist))
                star.addLine(to: CGPoint(x: mote.x - arm, y: mote.y))
                star.addLine(to: CGPoint(x: mote.x - waist, y: mote.y - waist))
                star.closeSubpath()
                layer.fill(star, with: .color(tint.opacity(alpha)))
            } else {
                layer.fill(Path(ellipseIn: CGRect(
                    x: mote.x - mote.size, y: mote.y - mote.size,
                    width: mote.size * 2, height: mote.size * 2)),
                           with: .color(tint.opacity(alpha)))
            }
        }
    }
}

/// Частицы искр: рождаются у кромки медали, летят наружу, тормозят,
/// всплывают и гаснут. Живут в классе, а не в состоянии вью: холст
/// двигает их каждый кадр, и перерисовка SwiftUI на это не нужна.
@MainActor
final class Sparks {
    struct Mote {
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        var age: Double = 0
        var life: Double
        var size: Double
        var tone: Double
        var twinkle: Double
        var star: Bool

        /// Разгорается, мерцает и гаснет к концу жизни.
        var alpha: Double {
            let arc = sin(.pi * min(age / life, 1))
            return max(arc, 0) * (0.65 + 0.35 * sin(twinkle + age * 9))
        }
    }

    private(set) var motes: [Mote] = []

    private var last: Date?
    private var owed: Double = 0
    private var pending = 0
    private var seed: UInt64 = 0x2545_F491_4F6C_DD1D

    /// Сколько частиц нельзя превысить: холст рисует каждую дважды.
    private static let limit = 420

    /// Вспышка — при появлении медали.
    func burst(_ count: Int) { pending += count }

    func step(to now: Date, energy: Double, spin: Double, idle: Double,
              in size: CGSize) {
        let dt = min(max(now.timeIntervalSince(last ?? now), 0), 0.05)
        last = now
        let radius = min(size.width, size.height) * 0.29
        owed += dt * (idle + 170 * energy)
        var births = Int(owed)
        owed -= Double(births)
        births += pending
        let bursting = pending > 0
        pending = 0
        for _ in 0 ..< max(min(births, Self.limit - motes.count), 0) {
            spawn(radius: radius, in: size,
                  energy: bursting ? 1.2 : energy, spin: spin)
        }
        guard dt > 0 else { return }
        let drag = exp(-1.6 * dt)
        motes = motes.compactMap { mote in
            var next = mote
            next.age += dt
            guard next.age < next.life else { return nil }
            next.x += next.vx * dt
            next.y += next.vy * dt
            next.vx *= drag
            next.vy = next.vy * drag - 16 * dt
            return next
        }
    }

    private func spawn(radius: Double, in size: CGSize, energy: Double,
                       spin: Double) {
        let angle = random() * 2 * .pi
        let reach = radius * (0.82 + 0.25 * random())
        let way = (cos(angle), sin(angle))
        let speed = 16 + 40 * random() + 230 * energy * random()
        // Крутится вокруг вертикали — искры сносит вбок, по ходу вращения.
        let side = (spin >= 0 ? 1.0 : -1.0) * energy * 110 * random()
        motes.append(Mote(
            x: size.width / 2 + way.0 * reach,
            y: size.height / 2 + way.1 * reach,
            vx: way.0 * speed + side,
            vy: way.1 * speed - 8,
            life: 0.8 + 1.6 * random(),
            size: 1.1 + 2.4 * random(),
            tone: random(),
            twinkle: random() * 2 * .pi,
            star: random() < 0.22))
    }

    /// Свой генератор: частицы не трогают общий, и медаль искрит одинаково.
    private func random() -> Double {
        seed ^= seed << 13
        seed ^= seed >> 7
        seed ^= seed << 17
        return Double(seed >> 11) / Double(1 << 53)
    }
}
