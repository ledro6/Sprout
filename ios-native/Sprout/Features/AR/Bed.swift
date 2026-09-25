import ARKit
import RealityKit
import SwiftUI

/// Растение на полу: якорь, модель и то, как она живёт — распускается,
/// никнет по влажности, покачивается, перекрашивает увядание. Скан стоит
/// как есть: он не никнет, зато он — само растение.
@MainActor
final class Bed {
    /// Шарнир на месте крепления детали и то, как она живёт.
    struct Part {
        let pivot: Entity
        let piece: Piece
    }

    let id: Plant.ID
    let kit: Kit
    let anchor: AnchorEntity
    let root: ModelEntity
    let frame = Entity()
    /// Где земля и какой ширины горлышко горшка — туда целит лейка. У скана
    /// горшок не размечен: земля — на трети высоты, горлышко — по ширине.
    let soil: Float
    let mouth: Float
    private var ring: ModelEntity?
    /// Вода на земле: круги от струи, сколько воды и куда бьёт струя.
    private var puddle: ModelEntity?
    private var wetness: Float = 0
    private var spot = SIMD2<Float>(0.5, 0.5)
    private var parts: [Part] = []
    /// Детали по материалам: увядание перекрашивает их разом.
    private var dressed: [Int: [ModelEntity]] = [:]
    private var textures: [String: TextureResource] = [:]

    /// Влажность на сцене: догоняет настоящую плавно — после полива листья
    /// поднимаются, а не прыгают.
    private(set) var shown: Double
    private var withered: Float = -1
    private var wetted: Double = -1
    private var ringed: Double = -1
    private let planted: Double

    init(id: Plant.ID, kit: Kit, figure: Entity? = nil, at point: Vec3,
         facing: Float, moisture: Double, planted: Double) {
        self.id = id
        self.kit = kit
        self.planted = planted
        shown = moisture
        if figure != nil {
            soil = min(max(kit.height * 0.3, 0.05), 0.35)
            mouth = min(max(kit.spread * 0.5, 0.04), 0.2)
        } else {
            soil = Greenhouse.soil
            mouth = Greenhouse.potInner
        }
        anchor = AnchorEntity(world: point)
        root = ModelEntity()
        let box = ShapeResource.generateBox(size: SIMD3(
            kit.spread * 2, kit.height, kit.spread * 2))
            .offsetBy(translation: SIMD3(0, kit.height / 2, 0))
        root.collision = CollisionComponent(shapes: [box])
        // Лицом к камере: у растения нет переда, но так первым виден тот же
        // бок, что и на фото в приложении.
        root.orientation = simd_quatf(angle: facing, axis: Vec3(0, 1, 0))
        frame.scale = SIMD3(repeating: 0.001)
        root.addChild(frame)
        build()
        if let figure {
            frame.addChild(figure)
        } else {
            puddle = makePuddle()
        }
        anchor.addChild(root)
    }

    /// Нажали по этой сущности или по её детали.
    func owns(_ entity: Entity) -> Bool {
        var node: Entity? = entity
        while let current = node {
            if current === root { return true }
            node = current.parent
        }
        return false
    }

    func live(_ dt: Double, clock: Double, moisture: Double, still: Bool) {
        // Щипок границ не знает — держим размер разумным.
        let scale = min(max(root.scale.x, 0.35), 3)
        if root.scale.x != scale { root.scale = SIMD3(repeating: scale) }
        let grown = Greenhouse.unfurl((clock - planted) / 0.9)
        frame.scale = SIMD3(repeating: Float(max(grown, 0.001)))

        shown += (moisture - shown) * (1 - exp(-dt * 2.2))
        let sag = Greenhouse.sag(shown)
        // Пока растение распускается, двигаются все детали; потом — только
        // живые: горшку и земле каждый кадр незачем.
        let growing = clock - planted < 2
        for part in parts where growing || part.piece.lives {
            let piece = part.piece
            let open = Greenhouse.unfurl(
                (clock - planted - Double(piece.delay) * 0.5) / 0.7)
            part.pivot.scale = SIMD3(repeating: piece.pose.size
                * Float(max(open, 0.001)))
            let wave = sin(clock * 1.3 + Double(piece.phase) * 2 * .pi)
            let sway = still ? 0 : piece.sway * Float(wave) * (1 - 0.5 * sag)
            part.pivot.orientation = Bed.orientation(piece.pose,
                                                     lean: piece.sag * sag - sway)
        }
        repaint()
        if abs(shown - ringed) > 0.004 { reshape() }
    }

    // MARK: - Вода на земле

    /// Струя бьёт в землю в `hit` (в пространстве якоря) — там круги и
    /// прибывает вода; перестала — лужица впитывается.
    func soak(_ hit: Vec3?, dt: Double) {
        guard let puddle else { return }
        let before = wetness
        if let hit {
            let local = frame.convert(position: hit, from: anchor)
            spot = SIMD2(0.5 + local.x / (2 * Greenhouse.potInner),
                         0.5 + local.z / (2 * Greenhouse.potInner))
            wetness = min(wetness + Float(dt) * 3, 1)
        } else {
            wetness = max(wetness - Float(dt) * 0.35, 0)
        }
        guard wetness > 0 || before > 0 else { return }
        puddle.isEnabled = wetness > 0
        if let material = WaterLook.puddle(strength: wetness, spot: spot) {
            puddle.model?.materials = [material]
        }
    }

    /// Плёнка воды по земле горшка — тем же куполом, что земля, чуть выше.
    private func makePuddle() -> ModelEntity? {
        let soil = Greenhouse.soil
        let film = Sculpt.lathe([
            SIMD2(Greenhouse.potInner - 0.002, soil - 0.0005),
            SIMD2(0.045, soil + 0.0065), SIMD2(0, soil + 0.0095),
        ], segments: 64).mappedFromAbove(radius: Greenhouse.potInner)
        guard let material = WaterLook.puddle(strength: 0, spot: spot),
              let made = Craft.model(film, material)
        else { return nil }
        made.isEnabled = false
        frame.addChild(made)
        return made
    }

    // MARK: - Сборка

    private func build() {
        withered = Greenhouse.wither(shown)
        wetted = shown
        let meshes = kit.meshes.map { Craft.resource($0) }
        let materials = kit.looks.map { material($0) }
        let sag = Greenhouse.sag(shown)
        parts = kit.pieces.compactMap { piece -> Part? in
            guard let mesh = meshes[piece.mesh] else { return nil }
            let model = ModelEntity(mesh: mesh,
                                    materials: [materials[piece.look]])
            Craft.shadow(model)
            dressed[piece.look, default: []].append(model)
            let pivot = Entity()
            pivot.position = piece.pose.base
            pivot.orientation = Bed.orientation(piece.pose, lean: piece.sag * sag)
            pivot.scale = SIMD3(repeating: 0.001)
            pivot.addChild(model)
            frame.addChild(pivot)
            return Part(pivot: pivot, piece: piece)
        }
        if let track = Craft.model(Sculpt.arc(inner: 0.098, outer: 0.11, sweep: 1,
                                              lift: 0.002),
                                   Craft.glow(Channels(255, 255, 255), opacity: 0.18)) {
            frame.addChild(track)
        }
        let ring = ModelEntity()
        ring.model = ModelComponent(mesh: .generateSphere(radius: 0.0001),
                                    materials: [Craft.glow(Greenhouse.calmRing,
                                                           opacity: 0.95)])
        frame.addChild(ring)
        self.ring = ring
    }

    /// Тот же порядок, что `Pose.turn`: свой поворот, подъём, поворот вокруг
    /// вертикали.
    static func orientation(_ pose: Pose, lean: Float) -> simd_quatf {
        let yaw = simd_quatf(angle: pose.yaw, axis: Pose.y)
        let rise = simd_quatf(angle: pose.rise - lean, axis: Pose.z)
        let roll = simd_quatf(angle: pose.roll, axis: Pose.x)
        return yaw * rise * roll
    }

    // MARK: - Краски

    /// Увядание — ступенями рисунка, земля темнеет оттенком. Перекраска —
    /// только когда ступень или влажность правда сменились.
    private func repaint() {
        let wither = Greenhouse.wither(shown)
        let rewilt = wither != withered
        let rewet = abs(shown - wetted) > 0.01
        guard rewilt || rewet else { return }
        withered = wither
        if rewet { wetted = shown }
        for (index, look) in kit.looks.enumerated()
            where (look.wilts && rewilt) || (look.wets && rewet) {
            let material = self.material(look)
            for entity in dressed[index] ?? [] {
                entity.model?.materials = [material]
            }
        }
    }

    /// Кольцо влажности на полу вокруг горшка: дуга — доля, цвет — тревога.
    private func reshape() {
        ringed = shown
        guard let ring else { return }
        let arc = Sculpt.arc(inner: 0.098, outer: 0.11, sweep: Float(shown),
                             lift: 0.003)
        guard let mesh = Craft.resource(arc) else {
            ring.isEnabled = false
            return
        }
        ring.isEnabled = true
        ring.model?.mesh = mesh
        ring.model?.materials = [Craft.glow(Greenhouse.ringColor(shown),
                                            opacity: 0.95)]
    }

    /// Материал из набора: рисунок, рельеф жилок, лак, вырез по контуру.
    /// Вырез — порогом прозрачности: край листа резкий, а листья не
    /// сортируются как стекло.
    private func material(_ look: Look) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        var tint = look.tint
        if look.wets {
            let wet = Greenhouse.wetTint(shown)
            tint = Channels(tint.red * wet.red / 255, tint.green * wet.green / 255,
                            tint.blue * wet.blue / 255)
        }
        let color = look.color.flatMap {
            texture($0, wither: look.wilts ? withered : 0, semantic: .color)
        }
        material.baseColor = .init(tint: Craft.color(tint),
                                   texture: color.map { .init($0) })
        if let index = look.normal,
           let relief = texture(index, wither: 0, semantic: .normal) {
            material.normal = .init(texture: .init(relief))
        }
        material.roughness = .init(floatLiteral: look.rough)
        material.metallic = .init(floatLiteral: 0)
        if look.gloss > 0 {
            material.clearcoat = .init(floatLiteral: look.gloss)
            material.clearcoatRoughness = .init(floatLiteral: 0.12)
        }
        if look.cutout, let index = look.color, let alpha = mask(index) {
            material.blending = .transparent(
                opacity: .init(scale: 1, texture: .init(alpha)))
            material.opacityThreshold = 0.5
        } else if look.opacity < 1 {
            material.blending = .transparent(
                opacity: .init(floatLiteral: look.opacity))
        }
        return material
    }

    private func texture(_ index: Int, wither: Float,
                         semantic: TextureResource.Semantic) -> TextureResource? {
        let key = "\(index)-\(wither)"
        if let known = textures[key] { return known }
        guard index < kit.pictures.count else { return nil }
        let picture = wither > 0 ? kit.pictures[index].withered(wither)
            : kit.pictures[index]
        guard let image = Craft.image(picture),
              let made = try? TextureResource.generate(
                  from: image, options: .init(semantic: semantic))
        else { return nil }
        textures[key] = made
        return made
    }

    /// Прозрачность отдельной картинкой, серой: какой бы канал ни читал
    /// материал, в нём контур.
    private func mask(_ index: Int) -> TextureResource? {
        let key = "\(index)-mask"
        if let known = textures[key] { return known }
        guard index < kit.pictures.count else { return nil }
        var picture = kit.pictures[index]
        for at in stride(from: 0, to: picture.pixels.count, by: 4) {
            let alpha = picture.pixels[at + 3]
            picture.pixels[at] = alpha
            picture.pixels[at + 1] = alpha
            picture.pixels[at + 2] = alpha
        }
        guard let image = Craft.image(picture),
              let made = try? TextureResource.generate(
                  from: image, options: .init(semantic: .raw))
        else { return nil }
        textures[key] = made
        return made
    }
}
