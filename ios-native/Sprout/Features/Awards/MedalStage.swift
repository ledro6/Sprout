import RealityKit
import SwiftUI

/// Объёмная медаль: настоящий диск с ободком, а растение на поле —
/// барельефом, картой нормалей под светом сцены: поворачиваешь медаль — и
/// свет бежит по листьям. Крутится пальцем, как в «Фитнесе»; отпустили —
/// доворачивается лицом, с разгону — через лишний оборот.
struct MedalStage: View {
    let award: Award
    let earned: Bool

    /// Появиться вращением — как новая медаль в «Фитнесе».
    var spinIn = false

    @State private var rig = MedalRig()

    var body: some View {
        RealityView { content in
            let medal = await MedalCraft.medal(award, earned: earned)
            content.add(medal)
            content.add(MedalCraft.camera())
            for light in MedalCraft.lights() { content.add(light) }
            rig.medal = medal
            if spinIn { rig.spinIn() }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { rig.turn(by: $0.translation.width) }
            .onEnded { rig.release(speed: $0.velocity.width) })
        .accessibilityElement()
        .accessibilityLabel(award.title)
        .accessibilityAddTraits(.isImage)
    }
}

/// Поворот медали. Своим циклом, а не анимацией RealityKit: та вела бы
/// поворот кратчайшей дугой, и полтора оборота при появлении схлопнулись бы
/// в пол-оборота.
@MainActor
final class MedalRig {
    var medal: Entity?

    private var angle: Float = 0
    private var start: Float?
    private var motion: Task<Void, Never>?

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

    func spinIn() {
        angle = -3 * .pi
        apply()
        glide(to: 0, seconds: 1.6)
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
        medal?.orientation = simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))
    }
}

/// Сетки, материалы, свет и камера медали.
@MainActor
enum MedalCraft {
    /// Ободок и тыл: диск телом вращения, профиль — от середины тыла
    /// наружу, по кромке вверх, через валик ободка к краю поля. Метры.
    static let rim = Sculpt.lathe([
        SIMD2(0, -0.004), SIMD2(0.046, -0.004), SIMD2(0.0492, -0.0034),
        SIMD2(0.05, -0.0015), SIMD2(0.05, 0.0015), SIMD2(0.0492, 0.0038),
        SIMD2(0.0465, 0.0046), SIMD2(0.0432, 0.0042), SIMD2(0.0415, 0.0028),
        SIMD2(0.041, 0.0022),
    ], segments: 96)

    /// Поле — отдельной сеткой, с текстурой сверху: на нём барельеф.
    static let face = Sculpt.lathe([SIMD2(0.041, 0.0022), SIMD2(0, 0.0022)],
                                   segments: 96)
        .mappedFromAbove(radius: 0.041)

    /// Медаль — перед началом координат, камера — в нём: так медаль видна и
    /// своей камерой, и камерой по умолчанию, что смотрит из нуля вдоль −z.
    static let spot = SIMD3<Float>(0, 0, -0.26)

    static func medal(_ award: Award, earned: Bool) async -> Entity {
        let root = Entity()
        root.position = spot
        let coin = Entity()
        // Диск лежит в плоскости пола; встаёт лицом к зрителю.
        coin.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        root.addChild(coin)
        let tone = earned ? award.alloy.body : Alloy.steel
        let polished = Craft.paint(tone, rough: earned ? 0.18 : 0.45,
                                   metal: earned ? 0.9 : 0.55)
        if let body = Craft.model(rim, polished) { coin.addChild(body) }
        var satin = Craft.paint(tone, rough: earned ? 0.34 : 0.6,
                                metal: earned ? 0.85 : 0.5)
        let normals = await Medals.shared.normals(award)
        if let image = Craft.image(normals),
           let relief = try? TextureResource.generate(
               from: image, options: .init(semantic: .normal)) {
            satin.normal = .init(texture: .init(relief))
        }
        if let field = Craft.model(face, satin) { coin.addChild(field) }
        return root
    }

    static func camera() -> Entity {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 38
        camera.look(at: spot, from: .zero, relativeTo: nil)
        return camera
    }

    /// Ключевой свет слева сверху — как на картинке медали, заполняющий
    /// справа снизу и контровой сзади: металл без отражений темнеет, и
    /// блики ему нужны со всех сторон.
    static func lights() -> [Entity] {
        let key = DirectionalLight()
        key.light.intensity = 3200
        key.look(at: spot, from: spot + SIMD3(-0.3, 0.35, 0.45), relativeTo: nil)
        let fill = PointLight()
        fill.light.intensity = 14_000
        fill.light.attenuationRadius = 2
        fill.position = spot + SIMD3(0.22, -0.12, 0.3)
        let back = PointLight()
        back.light.intensity = 9_000
        back.light.attenuationRadius = 2
        back.position = spot + SIMD3(0, 0.2, -0.25)
        return [key, fill, back]
    }
}
