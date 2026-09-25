import ARKit
import Combine
import RealityKit
import SwiftUI
import UIKit

/// Сцена дополненной реальности: ставит на пол или стол одно растение или
/// весь сад комнаты, держит их живыми — листья никнут и поднимаются по
/// влажности, покачиваются, — и разыгрывает полив лейкой: вода — на Metal,
/// см. `Stream`. Формы и расписание — в модели (`Greenhouse`, `Pouring`,
/// `Rill`, `Plot`), сила телефона — в `Rig`; здесь только перевод в
/// RealityKit и жизнь по кадрам. Растение со сканом стоит сканом.
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

    /// Где на экране таблички — над верхушками растений. Нет растения —
    /// оно ещё не стоит или ушло за кадр.
    private(set) var tags: [Plant.ID: CGPoint] = [:]

    /// Кого польёт «Полить». В саду из одного растения — оно само.
    private(set) var chosen: Plant.ID?

    /// Сколько моделей готово из скольких: сад собирается не мгновенно.
    private(set) var loaded = 0
    private(set) var total = 0

    var ready: Bool { total > 0 && loaded == total }

    /// Сколько растений комнаты не влезло: телефону тяжело больше.
    private(set) var left = 0

    /// Кого ещё полить по очереди — «Полить сухих».
    private(set) var queue: [Plant.ID] = []

    var many: Bool { cast.count > 1 }

    /// Полив засчитывается, когда первая капля коснулась земли, а не по
    /// кнопке: иначе проценты прыгнули бы раньше, чем прилетела лейка.
    @ObservationIgnored var onWatered: (@MainActor (Plant.ID) -> Void)?

    /// Сила телефона. Нагрелся — эффекты гаснут на ходу.
    @ObservationIgnored private(set) var rig = Probe.rig

    @ObservationIgnored private var view: ARView?
    @ObservationIgnored private var updates: (any Cancellable)?
    @ObservationIgnored private var tapper: Tapper?
    @ObservationIgnored private var watcher: Watcher?
    @ObservationIgnored private var heat: (any NSObjectProtocol)?

    @ObservationIgnored private weak var garden: Garden?
    @ObservationIgnored private var cast: [Plant.ID] = []
    @ObservationIgnored private var kits: [Plant.ID: Kit] = [:]
    @ObservationIgnored private var beds: [Bed] = []
    @ObservationIgnored private var target: Bed?
    @ObservationIgnored private var tint = Tint.defaultWave.vivid

    @ObservationIgnored private var reticle: Entity?
    @ObservationIgnored private var aim: SIMD3<Float>?

    @ObservationIgnored private var can: ModelEntity?
    @ObservationIgnored private var stream: Stream?
    /// Сканы растений — вместо моделей из набора.
    @ObservationIgnored private var figures: [Plant.ID: Entity] = [:]

    @ObservationIgnored private var clock: Double = 0
    @ObservationIgnored private var poured: Double = 0
    /// Куда льёт лейка: вправо от взгляда — её видно сбоку, вместе со струёй.
    @ObservationIgnored private var toward = Vec3(1, 0, 0)
    @ObservationIgnored private var lift = Pouring.lowest
    @ObservationIgnored private var wet = false
    @ObservationIgnored private var streaming = false
    /// Пауза между растениями очереди — лейка успевает улететь.
    @ObservationIgnored private var resting: Double = -1

    private static let up = Vec3(0, 1, 0)

    /// Одно растение или сад. Больше, чем тянет телефон, не ставим — лишние
    /// считаются в `left`.
    func cast(_ plants: [Plant], in garden: Garden) {
        self.garden = garden
        let shown = Array(plants.prefix(rig.plants))
        cast = shown.map(\.id)
        left = plants.count - shown.count
        total = shown.count
        loaded = 0
        chosen = shown.count == 1 ? shown.first?.id : nil
        tint = Settings.shared.waveTint.vivid
        // Пока камера ищет пол, модели достаются из приложения, свои — с
        // диска, сканы — из своих файлов.
        Task { @MainActor [weak self] in
            for plant in shown {
                var figure: Entity?
                if let url = Scans.file(of: plant) {
                    figure = try? await Entity(contentsOf: url)
                }
                var kit: Kit?
                if figure == nil { kit = await Workshop.shared.kit(for: plant) }
                guard let self else { return }
                if let figure {
                    self.kits[plant.id] = Self.settle(figure)
                    self.figures[plant.id] = figure
                } else if let kit {
                    self.kits[plant.id] = kit
                }
                self.loaded += 1
            }
        }
    }

    /// Скан ставится донышком на пол и серединой на ось; для раскладки сада
    /// и лейки его мерки — в пустом наборе: высота и размах.
    private static func settle(_ figure: Entity) -> Kit {
        let bounds = figure.visualBounds(relativeTo: nil)
        figure.position = SIMD3(-bounds.center.x, -bounds.min.y,
                                -bounds.center.z)
        Craft.shadows(figure)
        var kit = Kit()
        kit.height = max(bounds.extents.y, 0.05)
        kit.spread = max(bounds.extents.x, bounds.extents.z, 0.05) / 2
        return kit
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

        let tapper = Tapper { [weak self] point in self?.tap(at: point) }
        made.addGestureRecognizer(UITapGestureRecognizer(
            target: tapper, action: #selector(Tapper.fire(_:))))
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
        // Нагрелся или включил энергосбережение — эффекты гаснут сразу, не
        // дожидаясь следующего раза.
        heat = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.cool() }
        }
        return made
    }

    func stop() {
        updates?.cancel()
        updates = nil
        if let heat { NotificationCenter.default.removeObserver(heat) }
        heat = nil
        view?.session.pause()
    }

    private func cool() {
        rig = Probe.rig
        applyRender()
    }

    /// Всё, что умеет телефон. LiDAR строит сетку комнаты: растения прячутся
    /// за мебелью, тени ложатся на стол, силуэт человека закрывает листья.
    /// Новые iPhone снимают камеру в 4K и HDR и дают отражения комнаты в
    /// HDR. Не завелась сессия с полным набором — вторая попытка попроще,
    /// только с полом.
    private func run(full: Bool) {
        guard let view else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        view.environment.sceneUnderstanding.options = []
        if full {
            if rig.hdr {
                config.wantsHDREnvironmentTextures = true
                if let format = ARWorldTrackingConfiguration
                    .recommendedVideoFormatFor4KResolution {
                    config.videoFormat = format
                }
                if config.videoFormat.isVideoHDRSupported {
                    config.videoHDRAllowed = true
                }
            }
            if rig.room, ARWorldTrackingConfiguration
                .supportsSceneReconstruction(.meshWithClassification) {
                config.sceneReconstruction = .meshWithClassification
                view.environment.sceneUnderstanding.options = [
                    .occlusion, .receivesLighting]
            } else if ARWorldTrackingConfiguration
                .supportsSceneReconstruction(.mesh) {
                config.sceneReconstruction = .mesh
                view.environment.sceneUnderstanding.options.insert(.occlusion)
            }
            if ARWorldTrackingConfiguration.supportsFrameSemantics(
                .personSegmentationWithDepth) {
                config.frameSemantics.insert(.personSegmentationWithDepth)
            }
            if rig.room, ARWorldTrackingConfiguration.supportsFrameSemantics(
                .smoothedSceneDepth) {
                config.frameSemantics.insert(.smoothedSceneDepth)
            }
        }
        applyRender()
        view.session.run(config, options: full ? [] : [.resetTracking])
    }

    /// Размытие движения, глубина резкости и зерно камеры — только у сильных
    /// и не перегретых: вживую это красиво, но стоит кадров.
    private func applyRender() {
        guard let view else { return }
        view.renderOptions = rig.effects
            ? []
            : [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
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
        // Сад шире одного горшка — и прицел шире.
        let wide: Float = many ? 1.8 : 1
        reticle.scale = SIMD3(repeating: wide * (1 + 0.06 * Float(sin(clock * 3))))
        if phase == .searching { phase = .aiming }
    }

    private func live(_ dt: Double) {
        guard let view else { return }
        let still = UIAccessibility.isReduceMotionEnabled
        var points: [Plant.ID: CGPoint] = [:]
        for bed in beds {
            let actual = garden?.plant(id: bed.id)?.moisture ?? bed.shown
            bed.live(dt, clock: clock, moisture: actual, still: still)
            let crown = bed.frame.convert(
                position: Vec3(0, bed.kit.height + 0.03, 0), to: nil)
            if let point = view.project(crown) { points[bed.id] = point }
        }
        // Сдвиг меньше точки — не будим SwiftUI.
        let moved = points.count != tags.count || points.contains { id, point in
            guard let old = tags[id] else { return true }
            return abs(point.x - old.x) >= 0.5 || abs(point.y - old.y) >= 0.5
        }
        if moved { tags = points }

        if phase == .watering { pour(dt) }
        flow(dt)
        if phase == .placed, resting >= 0, clock >= resting {
            resting = -1
            next()
        }
    }

    // MARK: - Поставить и выбрать

    private func tap(at point: CGPoint) {
        switch phase {
        case .aiming: place()
        case .placed:
            guard let view, many,
                  let hit = view.entity(at: point),
                  let bed = beds.first(where: { $0.owns(hit) })
            else { return }
            chosen = bed.id
            Feel.pick()
        default: break
        }
    }

    /// Одно растение — на прицел, лицом к камере. Сад — вокруг прицела
    /// рядами, высокие дальше (`Plot`); каждый горшок можно потом двигать
    /// отдельно.
    func place() {
        guard phase == .aiming, ready, let view, let aim else { return }
        let camera = view.cameraTransform.translation
        var ahead = aim - camera
        ahead.y = 0
        let forward = ahead.size > 0.01 ? ahead.unit : Vec3(0, 0, -1)
        let right = forward.crossed(Self.up).unit
        let facing = atan2(-forward.x, -forward.z)
        let order = cast.compactMap { id in kits[id].map { (id, $0) } }
        let spots = Plot.layout(spreads: order.map { $0.1.spread },
                                heights: order.map { $0.1.height })
        let depth = spots.map(\.y).max() ?? 0
        beds = []
        for (index, item) in order.enumerated() {
            let (id, kit) = item
            let spot = spots.indices.contains(index) ? spots[index] : .zero
            let offset: Vec3 = right * spot.x + forward * (spot.y - depth / 2)
            let moisture = garden?.plant(id: id)?.moisture ?? 1
            let bed = Bed(id: id, kit: kit, figure: figures[id],
                          at: aim + offset, facing: facing, moisture: moisture,
                          planted: clock + Double(index) * 0.18)
            view.scene.addAnchor(bed.anchor)
            _ = view.installGestures([.rotation, .scale, .translation],
                                     for: bed.root)
            beds.append(bed)
        }
        stream?.reset()
        can = nil
        target = nil
        reticle?.isEnabled = false
        phase = .placed
        Feel.planted()
        UIAccessibility.post(notification: .announcement,
                             argument: many
                                ? Lang.text("Сад стоит. Нажмите на растение, чтобы полить его.")
                                : Lang.text("Растение стоит. Его можно полить."))
    }

    func replace() {
        guard phase == .placed else { return }
        for bed in beds { view?.scene.removeAnchor(bed.anchor) }
        beds = []
        can = nil
        stream?.reset()
        target = nil
        tags = [:]
        queue = []
        if many { chosen = nil }
        phase = .searching
    }

    // MARK: - Полить

    func water() {
        guard phase == .placed, let id = chosen ?? (many ? nil : cast.first)
        else { return }
        queue = []
        start(id)
    }

    /// Все, кто просит воды, по очереди — от самого сухого.
    func waterThirsty() {
        guard phase == .placed else { return }
        let thirsty = beds.compactMap { bed -> (Plant.ID, Double)? in
            guard let moisture = garden?.plant(id: bed.id)?.moisture,
                  moisture < Thirst.warnBelow else { return nil }
            return (bed.id, moisture)
        }
        queue = thirsty.sorted { $0.1 < $1.1 }.map(\.0)
        next()
    }

    var thirsty: Int {
        beds.filter {
            (garden?.plant(id: $0.id)?.moisture ?? 1) < Thirst.warnBelow
        }.count
    }

    private func next() {
        guard !queue.isEmpty else { return }
        start(queue.removeFirst())
    }

    private func start(_ id: Plant.ID) {
        guard let view, let bed = beds.first(where: { $0.id == id }) else {
            return
        }
        chosen = id
        target = bed
        let camera = bed.anchor.convert(position: view.cameraTransform.translation,
                                        from: nil)
        var look = bed.root.position - camera
        look.y = 0
        let ahead = look.size > 0.01 ? look.unit : Vec3(0, 0, -1)
        toward = ahead.crossed(Self.up).unit
        lift = Pouring.clearance(over: bed.kit.height, soil: bed.soil)
        wet = false
        streaming = false
        // Лейка и вода переезжают к тому, кого поливают: их счёт — в
        // пространстве его якоря.
        if can == nil {
            let made = makeCan()
            can = made
        }
        can?.setParent(bed.anchor)
        let water = stream ?? Stream(jets: rig.jets)
        stream = water
        water.begin(on: bed.anchor, scale: bed.root.scale.x, clearance: lift)
        poured = clock
        phase = .watering
    }

    private func pour(_ dt: Double) {
        guard let bed = target, let can else { return }
        let root = bed.root
        let t = clock - poured
        let pose = Pouring.pose(at: t)
        let scale = root.scale.x
        let base = root.position
        let settled = Pouring.origin(scale: scale, clearance: lift,
                                     soil: bed.soil)
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
            let tip = Pouring.spout(from: origin, tilt: pose.tilt, scale: scale)
            let launch = Pouring.launch(scale: scale, tilt: pose.tilt)
            stream?.pour(from: at(tip, from: base), jet: at(launch, from: .zero),
                         side: toward.crossed(Self.up).unit, dt: dt)
        } else {
            stream?.stop()
        }
        if t >= Pouring.total {
            can.isEnabled = false
            streaming = false
            if !wet {
                wet = true
                onWatered?(bed.id)
            }
            phase = .placed
            if !queue.isEmpty { resting = clock + 0.35 }
        }
    }

    /// Точка плоскости полива — в пространство якоря.
    private func at(_ point: SIMD2<Float>, from base: Vec3) -> Vec3 {
        let ahead: Vec3 = toward * point.x
        let rise: Vec3 = Self.up * point.y
        return base + ahead + rise
    }

    /// Вода летит сама по себе: коснулась земли в горшке — полив засчитан,
    /// по земле пошли круги.
    private func flow(_ dt: Double) {
        guard let stream, let bed = target, !stream.idle else {
            target?.soak(nil, dt: dt)
            return
        }
        let root = bed.root
        let base = root.position
        let scale = root.scale.x
        let hit = stream.fly(Float(dt), ground: base.y + bed.soil * scale,
                             center: base, mouth: bed.mouth * scale,
                             floor: base.y - 0.02)
        bed.soak(hit, dt: dt)
        if hit != nil, !wet {
            wet = true
            onWatered?(bed.id)
        }
    }

    // MARK: - Реквизит

    private func makeReticle() -> Entity {
        let reticle = Entity()
        if let ring = Craft.model(Sculpt.arc(inner: 0.075, outer: 0.085, sweep: 1),
                                  Craft.glow(Channels(255, 255, 255), opacity: 0.9)) {
            reticle.addChild(ring)
        }
        if let mark = Craft.model(Sculpt.arc(inner: 0.0, outer: 0.012, sweep: 1),
                                  Craft.glow(Channels(255, 255, 255), opacity: 0.9)) {
            reticle.addChild(mark)
        }
        if let fill = Craft.model(Sculpt.arc(inner: 0.012, outer: 0.075, sweep: 1,
                                             lift: 0.001),
                                  Craft.glow(Channels(255, 255, 255), opacity: 0.15)) {
            reticle.addChild(fill)
        }
        return reticle
    }

    /// Лейка — цвета волны из настроек: своя, а не казённая.
    private func makeCan() -> ModelEntity {
        let made = Craft.model(WateringCan.mesh,
                               Craft.paint(tint, rough: 0.22, metal: 0.1))
            ?? ModelEntity()
        Craft.shadow(made)
        made.isEnabled = false
        return made
    }
}

/// Растение на полу: якорь, модель и то, как она живёт — распускается,
/// никнет по влажности, покачивается, перекрашивает увядание. Скан стоит
/// как есть: он не никнет, зато он — само растение.
@MainActor
private final class Bed {
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

/// Сетки, материалы и картинки для RealityKit — общие у сцены и растений.
@MainActor
private enum Craft {
    static func model(_ mesh: Mesh3D, _ material: any RealityKit.Material)
        -> ModelEntity? {
        guard let resource = resource(mesh) else { return nil }
        return ModelEntity(mesh: resource, materials: [material])
    }

    static func resource(_ mesh: Mesh3D) -> MeshResource? {
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

    static func shadow(_ entity: ModelEntity) {
        entity.components.set(GroundingShadowComponent(castsShadow: true))
    }

    /// Тени у всех сеток скана — он приходит деревом сущностей.
    static func shadows(_ entity: Entity) {
        if entity.components.has(ModelComponent.self) {
            entity.components.set(GroundingShadowComponent(castsShadow: true))
        }
        for child in entity.children { shadows(child) }
    }

    static func paint(_ color: Channels, rough: Float,
                      metal: Float = 0) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Self.color(color))
        material.roughness = .init(floatLiteral: rough)
        material.metallic = .init(floatLiteral: metal)
        return material
    }

    /// Светится само, без света сцены: кольцо и прицел видны и в темноте.
    static func glow(_ color: Channels, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: Self.color(color))
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    static func color(_ channels: Channels) -> UIColor {
        UIColor(red: channels.red / 255, green: channels.green / 255,
                blue: channels.blue / 255, alpha: 1)
    }

    static func image(_ picture: Picture) -> CGImage? {
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
}

/// Нажатие по экрану — через `@objc`: жест UIKit зовёт селектор.
private final class Tapper: NSObject {
    private let action: @MainActor (CGPoint) -> Void

    init(_ action: @escaping @MainActor (CGPoint) -> Void) {
        self.action = action
    }

    @MainActor @objc func fire(_ gesture: UITapGestureRecognizer) {
        action(gesture.location(in: gesture.view))
    }
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
