import ARKit
import Combine
import RealityKit
import SwiftUI
import UIKit

/// Сцена дополненной реальности: ставит растение на пол или стол, держит его
/// живым — листья никнут и поднимаются по влажности, покачиваются, — и
/// разыгрывает полив лейкой. Формы и расписание — в модели (`Greenhouse`,
/// `Pouring`), здесь только перевод в RealityKit и жизнь по кадрам.
@MainActor
@Observable
final class Stage {
    enum Phase: Equatable {
        /// Ищем пол или стол — прицела ещё нет.
        case searching
        /// Прицел на поверхности — можно ставить.
        case aiming
        case placed
        case watering
    }

    private(set) var phase: Phase = .searching

    /// Где на экране табличка — над верхушкой растения. Нет — растение ещё
    /// не стоит или ушло за кадр.
    private(set) var tag: CGPoint?

    /// Полив засчитывается, когда первая капля коснулась земли, а не по
    /// кнопке: иначе проценты прыгнули бы раньше, чем прилетела лейка.
    @ObservationIgnored var onWatered: (@MainActor () -> Void)?

    @ObservationIgnored private var view: ARView?
    @ObservationIgnored private var updates: (any Cancellable)?
    @ObservationIgnored private var tapper: Tapper?
    @ObservationIgnored private var watcher: Watcher?

    /// Модель готова — её можно ставить. Собрана заранее, при посадке или
    /// при запуске; здесь она только достаётся из кэша.
    private(set) var ready = false

    @ObservationIgnored private weak var garden: Garden?
    @ObservationIgnored private var plantID: Plant.ID = ""
    @ObservationIgnored private var kit: Kit?
    @ObservationIgnored private var tint = Tint.defaultWave.vivid

    @ObservationIgnored private var reticle: Entity?
    @ObservationIgnored private var aim: SIMD3<Float>?

    @ObservationIgnored private var anchor: AnchorEntity?
    @ObservationIgnored private var root: ModelEntity?
    @ObservationIgnored private var frame: Entity?
    @ObservationIgnored private var ring: ModelEntity?
    @ObservationIgnored private var parts: [Part] = []
    /// Детали по материалам: увядание перекрашивает их разом.
    @ObservationIgnored private var dressed: [Int: [ModelEntity]] = [:]
    @ObservationIgnored private var textures: [String: TextureResource] = [:]
    @ObservationIgnored private var can: ModelEntity?
    @ObservationIgnored private var drops: [Drop] = []

    @ObservationIgnored private var clock: Double = 0
    @ObservationIgnored private var planted: Double = 0
    @ObservationIgnored private var poured: Double = 0
    /// Влажность на сцене: догоняет настоящую плавно — после полива листья
    /// поднимаются, а не прыгают.
    @ObservationIgnored private var shown: Double = 1
    @ObservationIgnored private var withered: Float = -1
    @ObservationIgnored private var wetted: Double = -1
    @ObservationIgnored private var ringed: Double = -1
    /// Куда льёт лейка: вправо от взгляда — её видно сбоку, вместе со струёй.
    @ObservationIgnored private var toward = Vec3(1, 0, 0)
    @ObservationIgnored private var lift = Pouring.lowest
    @ObservationIgnored private var owed: Double = 0
    @ObservationIgnored private var wet = false
    @ObservationIgnored private var streaming = false

    private static let up = Vec3(0, 1, 0)
    private static let pool = 220
    private static let drop: Float = 0.0032

    /// Деталь в сцене: шарнир на месте крепления и то, как она живёт.
    private struct Part {
        let pivot: Entity
        let piece: Piece
    }

    private struct Drop {
        let entity: ModelEntity
        var droplet: Droplet?
    }

    func cast(_ plant: Plant, in garden: Garden) {
        self.garden = garden
        plantID = plant.id
        shown = plant.moisture
        tint = Settings.shared.waveTint.vivid
        // Пока камера ищет пол, модель достаётся из кэша — или собирается,
        // если её там нет.
        Task { @MainActor [weak self] in
            let kit = await Workshop.shared.kit(for: plant)
            guard let self else { return }
            self.kit = kit
            // Текстуры — тоже заранее: иначе нажатие «Поставить» споткнулось
            // бы на их создании.
            withered = Greenhouse.wither(shown)
            for look in kit.looks { _ = material(look) }
            ready = true
        }
    }

    // MARK: - Сессия

    /// Камера включается здесь, а не в `init`: `@State` создаёт сцену при
    /// каждой сборке экрана, а живёт только первая.
    func mount() -> ARView {
        if let view { return view }
        let made = ARView(frame: .zero, cameraMode: .ar,
                          automaticallyConfigureSession: false)
        view = made
        run(full: true)

        let coaching = ARCoachingOverlayView()
        coaching.session = made.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        made.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.topAnchor.constraint(equalTo: made.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: made.bottomAnchor),
            coaching.leadingAnchor.constraint(equalTo: made.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: made.trailingAnchor),
        ])

        let tapper = Tapper { [weak self] in self?.place() }
        made.addGestureRecognizer(UITapGestureRecognizer(
            target: tapper, action: #selector(Tapper.fire)))
        self.tapper = tapper

        let watcher = Watcher { [weak self] in self?.run(full: false) }
        made.session.delegate = watcher
        self.watcher = watcher

        let world = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
        let reticle = makeReticle()
        reticle.isEnabled = false
        world.addChild(reticle)
        made.scene.addAnchor(world)
        self.reticle = reticle

        updates = made.scene.subscribe(to: SceneEvents.Update.self) {
            [weak self] event in
            self?.tick(event.deltaTime)
        }
        return made
    }

    func stop() {
        updates?.cancel()
        updates = nil
        view?.session.pause()
    }

    /// Всё, что умеет телефон: сетка комнаты от LiDAR прячет растение за
    /// мебелью, силуэт человека — за рукой. Не завелось — вторая попытка
    /// попроще, только с полом.
    private func run(full: Bool) {
        guard let view else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        view.environment.sceneUnderstanding.options = []
        if full {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                config.sceneReconstruction = .mesh
                view.environment.sceneUnderstanding.options.insert(.occlusion)
            }
            if ARWorldTrackingConfiguration.supportsFrameSemantics(
                .personSegmentationWithDepth) {
                config.frameSemantics.insert(.personSegmentationWithDepth)
            }
        }
        view.session.run(config, options: full ? [] : [.resetTracking])
    }

    // MARK: - Кадр

    private func tick(_ step: Double) {
        // После паузы шаг бывает в секунды — лейка перескочила бы полполива.
        let dt = min(step, 1.0 / 20)
        clock += dt
        switch phase {
        case .searching, .aiming: seek()
        case .placed, .watering: live(dt)
        }
    }

    private func seek() {
        guard let view, let reticle else { return }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let hit = view.raycast(from: center, allowing: .estimatedPlane,
                                     alignment: .horizontal).first
        else {
            aim = nil
            reticle.isEnabled = false
            if phase == .aiming { phase = .searching }
            return
        }
        let spot = hit.worldTransform.columns.3
        let found = SIMD3<Float>(spot.x, spot.y, spot.z)
        aim = found
        reticle.isEnabled = true
        reticle.position = found
        reticle.orientation = simd_quatf(angle: Float(clock * 0.6),
                                         axis: Self.up)
        reticle.scale = SIMD3(repeating: 1 + 0.06 * Float(sin(clock * 3)))
        if phase == .searching { phase = .aiming }
    }

    private func live(_ dt: Double) {
        guard let view, let root, let frame, let kit else { return }
        // Щипок границ не знает — держим размер разумным.
        let scale = min(max(root.scale.x, 0.35), 3)
        if root.scale.x != scale { root.scale = SIMD3(repeating: scale) }
        let grown = Greenhouse.unfurl((clock - planted) / 0.9)
        frame.scale = SIMD3(repeating: Float(max(grown, 0.001)))

        let actual = garden?.plant(id: plantID)?.moisture ?? shown
        shown += (actual - shown) * (1 - exp(-dt * 2.2))
        let sag = Greenhouse.sag(shown)
        let still = UIAccessibility.isReduceMotionEnabled
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
            part.pivot.orientation = orientation(piece.pose,
                                                 lean: piece.sag * sag - sway)
        }
        repaint()
        if abs(shown - ringed) > 0.004 { reshape() }

        let crown = frame.convert(position: Vec3(0, kit.height + 0.03, 0),
                                  to: nil)
        let point = view.project(crown)
        if let point, let old = tag, abs(point.x - old.x) < 0.5,
           abs(point.y - old.y) < 0.5 {
            // Сдвиг меньше точки — не будим SwiftUI.
        } else {
            tag = point
        }

        if phase == .watering { pour(dt) }
        fly(dt)
    }

    // MARK: - Поставить

    func place() {
        guard phase == .aiming, ready, let view, let aim, let kit else { return }
        let anchor = AnchorEntity(world: aim)
        let root = ModelEntity()
        let box = ShapeResource.generateBox(size: SIMD3(
            kit.spread * 2, kit.height, kit.spread * 2))
            .offsetBy(translation: SIMD3(0, kit.height / 2, 0))
        root.collision = CollisionComponent(shapes: [box])
        // Лицом к камере: у растения нет переда, но так первым виден тот же
        // бок, что и на фото в приложении.
        let camera = view.cameraTransform.translation - aim
        root.orientation = simd_quatf(angle: atan2(camera.x, camera.z),
                                      axis: Self.up)
        let frame = Entity()
        frame.scale = SIMD3(repeating: 0.001)
        root.addChild(frame)
        build(kit, into: frame)
        anchor.addChild(root)
        view.scene.addAnchor(anchor)
        _ = view.installGestures([.rotation, .scale, .translation], for: root)

        self.anchor = anchor
        self.root = root
        self.frame = frame
        ringed = -1
        drops = []
        can = nil
        reticle?.isEnabled = false
        planted = clock
        phase = .placed
        Feel.planted()
        UIAccessibility.post(notification: .announcement,
                             argument: "Растение стоит. Его можно полить.")
    }

    func replace() {
        guard phase == .placed else { return }
        if let anchor { view?.scene.removeAnchor(anchor) }
        anchor = nil
        root = nil
        frame = nil
        ring = nil
        parts = []
        dressed = [:]
        can = nil
        drops = []
        tag = nil
        phase = .searching
    }

    // MARK: - Полить

    func water() {
        guard phase == .placed, let view, let anchor, let root, let kit
        else { return }
        let camera = anchor.convert(position: view.cameraTransform.translation,
                                    from: nil)
        var look = root.position - camera
        look.y = 0
        let ahead = look.size > 0.01 ? look.unit : Vec3(0, 0, -1)
        toward = ahead.crossed(Self.up).unit
        lift = Pouring.clearance(over: kit.height)
        wet = false
        streaming = false
        owed = 0
        if can == nil {
            let made = makeCan()
            anchor.addChild(made)
            can = made
        }
        if drops.isEmpty { drops = makeDrops(in: anchor) }
        poured = clock
        phase = .watering
    }

    private func pour(_ dt: Double) {
        guard let root, let can else { return }
        let t = clock - poured
        let pose = Pouring.pose(at: t)
        let scale = root.scale.x
        let base = root.position
        let settled = Pouring.origin(scale: scale, clearance: lift)
        let away: SIMD2<Float> = Pouring.approach * (scale * (1 - pose.travel))
        let origin = settled + away
        can.position = at(origin, from: base)
        can.orientation = simd_quatf(angle: atan2(-toward.z, toward.x),
                                     axis: Self.up)
            * simd_quatf(angle: -pose.tilt, axis: Vec3(0, 0, 1))
        can.scale = SIMD3(repeating: max(scale * pose.size, 0.001))
        can.isEnabled = pose.size > 0.001

        if pose.emit {
            if !streaming {
                streaming = true
                Chime.stream.play()
            }
            owed += Pouring.rate * dt
            let tip = Pouring.spout(from: origin, tilt: pose.tilt, scale: scale)
            let launch = Pouring.launch(scale: scale, tilt: pose.tilt)
            let side = toward.crossed(Self.up).unit
            let mouth = at(tip, from: base)
            let jet = at(launch, from: .zero)
            while owed >= 1 {
                owed -= 1
                let spread = Float.random(in: 0.94 ... 1.06)
                let aside: Float = Float.random(in: -0.03 ... 0.03)
                    * Pouring.speed * scale.squareRoot()
                let jitter: Float = Float.random(in: -0.004 ... 0.004) * scale
                let start: Vec3 = mouth + side * jitter
                let velocity: Vec3 = jet * spread + side * aside
                spawn(Droplet(position: start, velocity: velocity))
            }
        }
        if t >= Pouring.total {
            can.isEnabled = false
            streaming = false
            if !wet {
                wet = true
                onWatered?()
            }
            phase = .placed
        }
    }

    /// Точка плоскости полива — в пространство якоря.
    private func at(_ point: SIMD2<Float>, from base: Vec3) -> Vec3 {
        let ahead: Vec3 = toward * point.x
        let rise: Vec3 = Self.up * point.y
        return base + ahead + rise
    }

    private func spawn(_ droplet: Droplet) {
        guard let free = drops.firstIndex(where: { $0.droplet == nil })
        else { return }
        drops[free].droplet = droplet
        drops[free].entity.isEnabled = true
        drops[free].entity.position = droplet.position
    }

    /// Капли летят сами по себе: впиталась в землю — брызги и полив; мимо
    /// горшка — пропала на полу.
    private func fly(_ dt: Double) {
        guard let root, !drops.isEmpty else { return }
        let base = root.position
        let scale = root.scale.x
        let ground = base.y + Greenhouse.soil * scale
        for index in drops.indices {
            guard var droplet = drops[index].droplet else { continue }
            droplet.fall(Float(dt))
            let entity = drops[index].entity
            var off = droplet.position - base
            off.y = 0
            if !droplet.splash, droplet.position.y <= ground,
               off.size <= Greenhouse.potInner * scale {
                drops[index].droplet = nil
                entity.isEnabled = false
                splash(at: Vec3(droplet.position.x, ground, droplet.position.z),
                       scale: scale)
                if !wet {
                    wet = true
                    onWatered?()
                }
                continue
            }
            if droplet.position.y < base.y - 0.02 || droplet.age > 2.5
                || (droplet.splash && droplet.age > 0.35) {
                drops[index].droplet = nil
                entity.isEnabled = false
                continue
            }
            entity.position = droplet.position
            // Капля вытягивается вдоль полёта — так она читается струёй.
            let speed = droplet.velocity.size
            let stretch = 1 + min(speed * 3, 2.2)
            entity.scale = SIMD3(scale, scale * stretch, scale)
            if speed > 0.01 {
                entity.orientation = simd_quatf(from: Self.up,
                                                to: droplet.velocity / speed)
            }
            drops[index].droplet = droplet
        }
    }

    private func splash(at point: Vec3, scale: Float) {
        for _ in 0 ..< 2 {
            let angle = Float.random(in: 0 ..< 2 * Float.pi)
            let out = Float.random(in: 0.08 ... 0.2) * scale.squareRoot()
            var droplet = Droplet(
                position: point,
                velocity: Vec3(cos(angle) * out,
                               Float.random(in: 0.35 ... 0.6)
                                   * scale.squareRoot(),
                               sin(angle) * out))
            droplet.splash = true
            spawn(droplet)
        }
    }

    // MARK: - Краски

    /// Увядание — ступенями рисунка, земля темнеет оттенком. Перекраска —
    /// только когда ступень или влажность правда сменились.
    private func repaint() {
        guard let kit else { return }
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
        guard let mesh = resource(arc) else {
            ring.isEnabled = false
            return
        }
        ring.isEnabled = true
        ring.model?.mesh = mesh
        ring.model?.materials = [glow(Greenhouse.ringColor(shown),
                                      opacity: 0.95)]
    }

    // MARK: - Сборка

    private func build(_ kit: Kit, into frame: Entity) {
        withered = Greenhouse.wither(shown)
        wetted = shown
        let meshes = kit.meshes.map { resource($0) }
        let materials = kit.looks.map { material($0) }
        let sag = Greenhouse.sag(shown)
        dressed = [:]
        parts = kit.pieces.compactMap { piece -> Part? in
            guard let mesh = meshes[piece.mesh] else { return nil }
            let model = ModelEntity(mesh: mesh,
                                    materials: [materials[piece.look]])
            shadow(model)
            dressed[piece.look, default: []].append(model)
            let pivot = Entity()
            pivot.position = piece.pose.base
            pivot.orientation = orientation(piece.pose, lean: piece.sag * sag)
            pivot.scale = SIMD3(repeating: 0.001)
            pivot.addChild(model)
            frame.addChild(pivot)
            return Part(pivot: pivot, piece: piece)
        }
        if let track = model(Sculpt.arc(inner: 0.098, outer: 0.11, sweep: 1,
                                        lift: 0.002),
                             glow(Channels(255, 255, 255), opacity: 0.18)) {
            frame.addChild(track)
        }
        let ring = ModelEntity()
        ring.model = ModelComponent(mesh: .generateSphere(radius: 0.0001),
                                    materials: [glow(Greenhouse.calmRing,
                                                     opacity: 0.95)])
        frame.addChild(ring)
        self.ring = ring
    }

    /// Тот же порядок, что `Pose.turn`: свой поворот, подъём, поворот вокруг
    /// вертикали.
    private func orientation(_ pose: Pose, lean: Float) -> simd_quatf {
        let yaw = simd_quatf(angle: pose.yaw, axis: Pose.y)
        let rise = simd_quatf(angle: pose.rise - lean, axis: Pose.z)
        let roll = simd_quatf(angle: pose.roll, axis: Pose.x)
        return yaw * rise * roll
    }

    // MARK: - Материалы

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
        material.baseColor = .init(tint: Self.color(tint),
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
        guard let kit, index < kit.pictures.count else { return nil }
        let picture = wither > 0 ? kit.pictures[index].withered(wither)
            : kit.pictures[index]
        guard let image = Self.image(picture),
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
        guard let kit, index < kit.pictures.count else { return nil }
        var picture = kit.pictures[index]
        for at in stride(from: 0, to: picture.pixels.count, by: 4) {
            let alpha = picture.pixels[at + 3]
            picture.pixels[at] = alpha
            picture.pixels[at + 1] = alpha
            picture.pixels[at + 2] = alpha
        }
        guard let image = Self.image(picture),
              let made = try? TextureResource.generate(
                  from: image, options: .init(semantic: .raw))
        else { return nil }
        textures[key] = made
        return made
    }

    private static func image(_ picture: Picture) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(picture.pixels) as CFData)
        else { return nil }
        return CGImage(width: picture.width, height: picture.height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: picture.width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(
                           rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }

    private func makeReticle() -> Entity {
        let reticle = Entity()
        if let ring = model(Sculpt.arc(inner: 0.075, outer: 0.085, sweep: 1),
                            glow(Channels(255, 255, 255), opacity: 0.9)) {
            reticle.addChild(ring)
        }
        if let mark = model(Sculpt.arc(inner: 0.0, outer: 0.012, sweep: 1),
                            glow(Channels(255, 255, 255), opacity: 0.9)) {
            reticle.addChild(mark)
        }
        if let fill = model(Sculpt.arc(inner: 0.012, outer: 0.075, sweep: 1,
                                       lift: 0.001),
                            glow(Channels(255, 255, 255), opacity: 0.15)) {
            reticle.addChild(fill)
        }
        return reticle
    }

    /// Лейка — цвета волны из настроек: своя, а не казённая.
    private func makeCan() -> ModelEntity {
        let made = model(WateringCan.mesh, paint(tint, rough: 0.22, metal: 0.1))
            ?? ModelEntity()
        shadow(made)
        made.isEnabled = false
        return made
    }

    private func makeDrops(in anchor: AnchorEntity) -> [Drop] {
        var water = PhysicallyBasedMaterial()
        water.baseColor = .init(tint: Self.color(Channels(170, 215, 255)))
        water.roughness = .init(floatLiteral: 0.05)
        water.metallic = .init(floatLiteral: 0)
        water.blending = .transparent(opacity: .init(floatLiteral: 0.75))
        let sphere = MeshResource.generateSphere(radius: Self.drop)
        return (0 ..< Self.pool).map { _ in
            let entity = ModelEntity(mesh: sphere, materials: [water])
            entity.isEnabled = false
            anchor.addChild(entity)
            return Drop(entity: entity, droplet: nil)
        }
    }

    private func model(_ mesh: Mesh3D, _ material: any RealityKit.Material)
        -> ModelEntity? {
        guard let resource = resource(mesh) else { return nil }
        return ModelEntity(mesh: resource, materials: [material])
    }

    private func resource(_ mesh: Mesh3D) -> MeshResource? {
        guard !mesh.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "sprout")
        descriptor.positions = MeshBuffers.Positions(mesh.positions)
        descriptor.normals = MeshBuffers.Normals(mesh.normals)
        if mesh.uvs.count == mesh.positions.count {
            descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
                mesh.uvs)
            descriptor.tangents = MeshBuffers.Tangents(mesh.tangents())
        }
        descriptor.primitives = .triangles(mesh.indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    private func shadow(_ entity: ModelEntity) {
        entity.components.set(GroundingShadowComponent(castsShadow: true))
    }

    private func paint(_ color: Channels, rough: Float,
                       metal: Float = 0) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Self.color(color))
        material.roughness = .init(floatLiteral: rough)
        material.metallic = .init(floatLiteral: metal)
        return material
    }

    /// Светится само, без света сцены: кольцо и прицел видны и в темноте.
    private func glow(_ color: Channels, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: Self.color(color))
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    private static func color(_ channels: Channels) -> UIColor {
        UIColor(red: channels.red / 255, green: channels.green / 255,
                blue: channels.blue / 255, alpha: 1)
    }
}

/// Нажатие по экрану — через `@objc`: жест UIKit зовёт селектор.
private final class Tapper: NSObject {
    private let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    @MainActor @objc func fire() { action() }
}

/// Сессия не завелась с полным набором — сцена пробует попроще.
private final class Watcher: NSObject, ARSessionDelegate {
    private let failed: @MainActor () -> Void
    private var retried = false

    init(_ failed: @escaping @MainActor () -> Void) {
        self.failed = failed
    }

    func session(_ session: ARSession, didFailWithError error: any Error) {
        guard !retried else { return }
        retried = true
        let failed = self.failed
        Task { @MainActor in failed() }
    }
}

/// Вид UIKit в SwiftUI: сама сцена живёт в `Stage`.
struct StageView: UIViewRepresentable {
    let stage: Stage

    func makeUIView(context: Context) -> ARView { stage.mount() }

    func updateUIView(_ view: ARView, context: Context) {}
}
