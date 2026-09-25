import Foundation

/// Горшок и то, как объёмное растение живёт влажностью. Сами растения
/// растит `Botany`.
enum Greenhouse {
    /// Горшок: внешний край по верху, внутренний, уровень земли и кромка.
    static let potRadius: Float = 0.082
    static let potInner: Float = 0.068
    static let soil: Float = 0.112
    static let rim: Float = 0.133

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

    /// Ступени увядания: рисунок листа меняется ступенями, а не каждый
    /// кадр, — перерисовывать текстуру каждый кадр дорого.
    static let witherSteps = 4

    /// Ступень увядания 0…1 для рисунка.
    static func wither(_ moisture: Double) -> Float {
        let share = wilt(moisture) / 0.7
        let steps = Double(witherSteps)
        return Float((share * steps).rounded() / steps)
    }

    /// Земля нарисована сухой; вода её темнит.
    static let drySoil = Channels(139, 104, 74)
    static let wetShade = Channels(112, 104, 98)

    static func wetTint(_ moisture: Double) -> Channels {
        .mix(Channels(255, 255, 255), wetShade, moisture)
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
    /// `soil` — где земля: у скана растения горшок не размечен.
    static func clearance(over height: Float,
                          soil: Float = Greenhouse.soil) -> Float {
        max(lowest, height - soil + 0.02)
    }
    static let gravity: Float = 9.8
    /// Порций воды в секунду на струйку: из них сцена строит струю.
    static let rate = 120.0
    /// Откуда лейка прилетает — назад и вверх от своего места.
    static let approach = SIMD2<Float>(-0.14, 0.12)

    struct Stance: Equatable {
        /// 0 — в стороне, 1 — на месте.
        var travel: Float
        var tilt: Float
        var emit: Bool
        var size: Float
    }

    static func pose(at t: Double) -> Stance {
        let tilted = arrive + tiltIn
        let poured = tilted + pour
        let righted = poured + tiltOut
        switch t {
        case ..<0:
            return Stance(travel: 0, tilt: 0, emit: false, size: 0)
        case ..<arrive:
            let k = Float(back(t / arrive))
            return Stance(travel: k, tilt: 0, emit: false,
                        size: min(max(k, 0), 1))
        case ..<tilted:
            return Stance(travel: 1, tilt: angle * smooth((t - arrive) / tiltIn),
                        emit: false, size: 1)
        case ..<poured:
            return Stance(travel: 1, tilt: angle, emit: true, size: 1)
        case ..<righted:
            return Stance(travel: 1,
                        tilt: angle * (1 - smooth((t - poured) / tiltOut)),
                        emit: false, size: 1)
        case ..<total:
            let k = smooth((t - righted) / leave)
            return Stance(travel: 1 - k, tilt: 0, emit: false, size: 1 - k)
        default:
            return Stance(travel: 0, tilt: 0, emit: false, size: 0)
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
    static func tip(scale: Float, clearance: Float,
                    soil: Float = Greenhouse.soil) -> SIMD2<Float> {
        let velocity = launch(scale: scale)
        let height = clearance * scale
        let time = (velocity.y + (velocity.y * velocity.y
            + 2 * gravity * height).squareRoot()) / gravity
        return SIMD2(-velocity.x * time, (soil + clearance) * scale)
    }

    /// Середина лейки, когда она на месте.
    static func origin(scale: Float, clearance: Float,
                       soil: Float = Greenhouse.soil) -> SIMD2<Float> {
        tip(scale: scale, clearance: clearance, soil: soil)
            - turn(WateringCan.tip * scale, by: angle)
    }

    /// Струйка из сеточки лейки: где её дырочка на сеточке — в долях радиуса
    /// сеточки, поперёк носика — и насколько она отклоняется от общей струи,
    /// в долях скорости. Средняя — толще и рвётся на капли позже.
    struct Jet: Equatable, Sendable {
        var hole: SIMD2<Float>
        var lean: SIMD2<Float>
        var width: Float
        /// На какой доле полёта струйка рвётся на капли.
        var breaks: Float
    }

    /// Радиус сеточки у лейки размера один.
    static let rose: Float = 0.0165

    /// Сеточка: одна струйка в середине и остальные кругом.
    static func jets(_ count: Int) -> [Jet] {
        guard count > 0 else { return [] }
        let around = count - 1
        return [Jet(hole: .zero, lean: .zero, width: 1, breaks: 0.8)]
            + (0 ..< around).map { index in
                let angle = 2 * Float.pi * Float(index) / Float(around)
                let way = SIMD2(cos(angle), sin(angle))
                return Jet(hole: way * 0.6, lean: way * 0.11, width: 0.62,
                           breaks: 0.55 + 0.1 * Float(index % 3))
            }
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
