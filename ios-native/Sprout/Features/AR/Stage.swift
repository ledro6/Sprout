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
    @ObservationIgnored private var tint = Hue.wave.vivid

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
        tint = Settings.shared.waveHue.vivid
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
