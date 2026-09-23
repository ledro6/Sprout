import Foundation
import Observation
import SwiftUI

/// Фигурки узора и логотипа. Росток, капля и логотип — кривые из макета
/// (Figma, `geometry=paths`); цветок и горшок построены по числам.
enum SproutShapes {
    /// Хранимое, а не вычисляемое: узор обращается к нему сотни раз за кадр.
    static let leaf: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 50.2067, y: 0))
        p.addCurve(to: CGPoint(x: 25.1033, y: 42.2327),
                   control1: CGPoint(x: 50.2067, y: 16.0251),
                   control2: CGPoint(x: 38.9675, y: 42.2327))
        p.addCurve(to: CGPoint(x: 0, y: 0),
                   control1: CGPoint(x: 11.2391, y: 42.2327),
                   control2: CGPoint(x: 0, y: 16.0251))
        p.addCurve(to: CGPoint(x: 25.1033, y: 31.4466),
                   control1: CGPoint(x: 25.1033, y: 0),
                   control2: CGPoint(x: 11.2391, y: 31.4466))
        p.addCurve(to: CGPoint(x: 50.2067, y: 0),
                   control1: CGPoint(x: 38.9675, y: 31.4466),
                   control2: CGPoint(x: 25.1033, y: 0))
        p.closeSubpath()
        return p
    }()

    /// Середины фигур: вокруг них фигурка раздаётся на волне и по ним встаёт
    /// в сетку.
    static let leafCentre = CGPoint(x: 25.1033, y: 21.1164)
    static let dropCentre = CGPoint(x: 15.2097, y: 21.1164)

    /// Середина дорисованных фигурок — общая с каплей. Ширина не больше капли
    /// — условие: на гребне фигурки раздаются в 1.15 раза, и половины соседей
    /// должны уложиться в 44.3 pt.
    static let addedCentre = CGPoint(x: 15.2097, y: 21.1164)

    /// Цветок: пять кругов радиусом 6.8 через 72° на 8.4 от середины —
    /// лепестки заходят друг за друга, силуэт сплошной. Сердцевина закрывает
    /// дырку звёздочкой в центре. Половина ширины 14.79 — уже капли.
    static let flower: Path = {
        var p = Path()
        let middle = addedCentre
        let reach = 8.4, petal = 6.8
        for step in 0 ..< 5 {
            // Первый лепесток вверх: повёрнутый на полшага цветок валится
            // вбок.
            let angle = -Double.pi / 2 + Double(step) * 2 * .pi / 5
            let spot = CGPoint(x: middle.x + reach * cos(angle),
                               y: middle.y + reach * sin(angle))
            p.addEllipse(in: CGRect(x: spot.x - petal, y: spot.y - petal,
                                    width: 2 * petal, height: 2 * petal))
        }
        p.addEllipse(in: CGRect(x: middle.x - 4.6, y: middle.y - 4.6,
                                width: 9.2, height: 9.2))
        return p
    }()

    /// Горшок: ободок во всю ширину и конус тулова. Свес ободка такой, чтобы
    /// горшок не читался трапецией; углы скруглены, как всё в узоре. Середина
    /// по высоте — та же 21.1, ряды остаются рядами.
    static let pot: Path = {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 0, y: 5.4, width: 30.4193, height: 7.4),
                         cornerSize: CGSize(width: 1.6, height: 1.6))
        p.move(to: CGPoint(x: 3.4, y: 12.8))
        p.addLine(to: CGPoint(x: 27.0, y: 12.8))
        p.addLine(to: CGPoint(x: 22.85, y: 35.0))
        p.addQuadCurve(to: CGPoint(x: 21.0, y: 36.8),
                       control: CGPoint(x: 22.5, y: 36.8))
        p.addLine(to: CGPoint(x: 9.4, y: 36.8))
        p.addQuadCurve(to: CGPoint(x: 7.55, y: 35.0),
                       control: CGPoint(x: 7.9, y: 36.8))
        p.closeSubpath()
        return p
    }()

    struct Piece {
        var path: Path
        var centre: CGPoint
    }

    static let pieces: [Piece] = [
        Piece(path: leaf, centre: leafCentre),
        Piece(path: drop, centre: dropCentre),
        Piece(path: flower, centre: addedCentre),
        Piece(path: pot, centre: addedCentre),
    ]

    /// Самая широкая и высокая из фигурок — по ней они показываются рядом в
    /// настройках в своём размере.
    static let pieceBox = CGSize(width: 50.2067, height: 42.2327)

    /// Коробка логотипа в макете; все точки ниже — в ней.
    static let logoBox = CGSize(width: 74.9208, height: 137.5099)

    static let logoStroke: CGFloat = 7.4455

    private static func line(_ points: [CGPoint], closed: Bool) -> Path {
        var p = Path()
        p.addLines(points)
        if closed { p.closeSubpath() }
        return p
    }

    /// Листья — ломаные: так их отдаёт Figma в vectorNetwork.
    static let logoLeaves: [Path] = [
        line([CGPoint(x: 24.8960, y: 70.2674),
              CGPoint(x: 0, y: 49.3268),
              CGPoint(x: 0, y: 85.8565),
              CGPoint(x: 24.8960, y: 108.8912)], closed: true),
        line([CGPoint(x: 24.8960, y: 123.5496),
              CGPoint(x: 24.8960, y: 108.8912)], closed: false),
        line([CGPoint(x: 37.6930, y: 63.5198),
              CGPoint(x: 37.6930, y: 115.4059),
              CGPoint(x: 74.9207, y: 85.6238),
              CGPoint(x: 74.9207, y: 32.1089)], closed: true),
        line([CGPoint(x: 37.6930, y: 115.4059),
              CGPoint(x: 37.6930, y: 137.5099)], closed: false),
        line([CGPoint(x: 39.7870, y: 13.9604),
              CGPoint(x: 23.4999, y: 27.2228),
              CGPoint(x: 23.4999, y: 50.0248),
              CGPoint(x: 26.9900, y: 54.2129),
              CGPoint(x: 39.7870, y: 43.2772)], closed: true),
    ]

    static let logoDrops: [Path] = [
        line([CGPoint(x: 2.0941, y: 39.9268),
              CGPoint(x: 8.6090, y: 26.5248),
              CGPoint(x: 15.5891, y: 39.9268),
              CGPoint(x: 8.6090, y: 46.0694)], closed: true),
        line([CGPoint(x: 47.6980, y: 23.2939),
              CGPoint(x: 59.1552, y: 0),
              CGPoint(x: 71.4307, y: 23.2939),
              CGPoint(x: 59.1552, y: 33.9703)], closed: true),
    ]

    static let drop: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 30.4193, y: 27.0336))
        p.addCurve(to: CGPoint(x: 15.2097, y: 42.2327),
                   control1: CGPoint(x: 30.4193, y: 35.4278),
                   control2: CGPoint(x: 23.6097, y: 42.2327))
        p.addCurve(to: CGPoint(x: 0, y: 27.0336),
                   control1: CGPoint(x: 6.8096, y: 42.2327),
                   control2: CGPoint(x: 0, y: 35.4278))
        p.addCurve(to: CGPoint(x: 15.2097, y: 0),
                   control1: CGPoint(x: 0, y: 18.6393),
                   control2: CGPoint(x: 14.513, y: 0))
        p.addCurve(to: CGPoint(x: 30.4193, y: 27.0336),
                   control1: CGPoint(x: 15.9063, y: 0),
                   control2: CGPoint(x: 30.4193, y: 18.6393))
        p.closeSubpath()
        return p
    }()
}

/// Узор фона — отдельной вью: при сдвиге параллакса её свойства не меняются,
/// и холст не перерисовывается, а только съезжает. Тему читает явно — иначе
/// смена темы не перерисовала бы холст.
private struct SproutPattern: View {
    /// Где волна всплесков, 0…1. Пока она идёт, узор пересобирается каждый
    /// кадр.
    var wave: Double?

    var origin: CGPoint

    /// Угол холста в координатах окна — чтобы перевести в холст замеры с
    /// экрана. Лист настроек висит ниже окна, и без пересчёта волна шла бы
    /// выше кружка.
    var canvas: CGPoint

    var bloomFront: Front

    /// Насколько узор взошёл, 0…1. Ростом фигурок, а не проявлением: своей
    /// прозрачности у фигурки в общем контуре нет.
    var bloom: Double

    var shapes: [Int]

    var weave: Weave

    var swap: Reshape?

    var repaint: Recolour?

    var frolic: Frolic?

    /// Цвета покоя и волны; во время перекраски — смесь, см. `Repaint`. С
    /// хвостом в имени: `wave` выше — доля, а не цвет.
    var baseShade: Shade
    var waveShade: Shade

    /// Расхождение слоёв фигурок, см. `Sway`. Общий сдвиг делает `offset`
    /// снаружи; пусто — узор едет куском.
    var lag: [CGSize] = []

    var era = 0

    /// Тление, пока удаление можно отменить, см. `Ember`.
    var ember: Smoulder?

    @Environment(\.colorScheme) private var scheme

    /// Шаг сетки из макета.
    private let pitchX: CGFloat = 89.4
    private let pitchY: CGFloat = 46.68

    /// Середины двух гнёзд ячейки. Фигурки ставятся серединой, а не углом:
    /// коробки у них разной ширины.
    private let anchors: [CGFloat] = [25.1033, 70.2097]

    /// Синева на волне — ступенями: холст заливает контур одной командой на
    /// цвет, и плавно значило бы по команде на фигурку.
    private static let tints = 6

    /// Перелив цвета — тоже ступенями; вместе с синевой это 36 слоёв, в покое
    /// занят один.
    private static let repaints = 6

    /// В кутерьме вторая часть номера слоя — сам оттенок; этот номер значит
    /// «как в настройках».
    private static let plain = Tint.allCases.count

    /// Тление — третий множитель слоя, заводится только пока узор тлеет.
    private static let embers = 6

    var body: some View {
        Canvas { context, size in
            let layers = pattern(covering: size)
            // Свечение — те же фигурки, размытые, отдельным слоем: размытие
            // берёт весь слой.
            context.drawLayer { halo in
                halo.addFilter(.blur(radius: Metrics.splashGlow))
                for (slot, layer) in layers.enumerated() where !layer.isEmpty {
                    let (step, tone, burn) = split(slot)
                    guard step > 0 || burn > 0 else { continue }
                    halo.fill(layer, with: .color(Palette.glow(
                        paint(tone).wave, level: level(step),
                        ember: heat(burn))))
                }
            }
            for (slot, layer) in layers.enumerated() where !layer.isEmpty {
                let (step, tone, burn) = split(slot)
                let colours = paint(tone)
                context.fill(layer, with: .color(Palette.pattern(
                    colours.base, wave: colours.wave,
                    splash: level(step), ember: heat(burn))))
            }
        }
        .id(scheme)
    }

    private func level(_ step: Int) -> Double {
        Double(step) / Double(Self.tints - 1)
    }

    private var embers: Int { ember == nil ? 1 : Self.embers }

    private func split(_ slot: Int) -> (step: Int, tone: Int, burn: Int) {
        let rest = slot / embers
        return (rest / Self.repaints, rest % Self.repaints, slot % embers)
    }

    private func heat(_ burn: Int) -> Double {
        embers > 1 ? Double(burn) / Double(embers - 1) : 0
    }

    private func paint(_ step: Int) -> (base: Shade, wave: Shade) {
        if frolic != nil {
            // У кутерьмы перелива нет: цвет меняется, когда фигурка проходит
            // через ноль.
            guard step < Self.plain else { return (baseShade, waveShade) }
            let tint = Tint.allCases[step]
            return (Shade(tint), Shade(tint))
        }
        guard let repaint else { return (baseShade, waveShade) }
        let part = Double(step) / Double(Self.repaints - 1)
        return (Shade.mix(repaint.from, repaint.to, part),
                Shade.mix(repaint.fromWave, repaint.toWave, part))
    }

    /// Холст начинается выше и левее на размах параллакса. Сам сдвиг
    /// параллакса в пересчёт не берётся — на ходе перехода он не читается.
    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - canvas.x + Metrics.parallax,
                y: point.y - canvas.y + Metrics.parallax)
    }

    private func placed(_ front: Front) -> Front {
        switch front {
        case let .point(spot): .point(local(spot))
        case let .collapse(spot): .collapse(local(spot))
        case .sweep: front
        }
    }

    private var source: CGPoint { local(origin) }

    /// Весь узор — одним контуром на цвет: сотни отдельных заливок на кадр
    /// стоили бы в двести раз больше команд.
    private func pattern(covering size: CGSize) -> [Path] {
        var layers = [Path](repeating: Path(),
                            count: Self.tints * Self.repaints * embers)
        // Настройке не доверяем: промах по границам — падение. Цель берём у
        // идущего перехода: настройка может быть уже на нажатие впереди.
        let picked = (swap?.to ?? shapes)
            .filter(SproutShapes.pieces.indices.contains)
        let list = picked.isEmpty ? [0] : picked
        let arrivingWeave = swap?.toWeave ?? weave
        let leaving = swap?.from.filter(SproutShapes.pieces.indices.contains)
        let centreY = SproutShapes.leafCentre.y
        var row = 0
        var y = -pitchY
        while y < size.height + pitchY {
            var column = 0
            var x = -pitchX
            while x < size.width + pitchX {
                for (slot, anchor) in anchors.enumerated() {
                    let middle = CGPoint(x: x + anchor, y: y + centreY)
                    let grow = pop(at: middle)
                    var scale = grow
                    var here = list
                    var mesh = arrivingWeave
                    var wild: Int?
                    var hue: Int?
                    if let frolic {
                        let turn = Front.point(heart(of: size))
                            .turn(at: middle, over: size)
                        let (state, shrink) = frolic.look(turn: turn)
                        scale *= CGFloat(shrink)
                        if Frolic.chaotic(state) {
                            wild = Self.scramble(column, row, slot, state)
                                % SproutShapes.pieces.count
                            hue = state % Tint.allCases.count
                        } else {
                            hue = Self.plain
                        }
                    } else if let swap, let leaving, !leaving.isEmpty {
                        let (share, old) = change(swap, at: middle, over: size)
                        scale *= share
                        if old { here = leaving; mesh = swap.fromWeave }
                    } else {
                        scale *= sprouted(at: middle, over: size)
                    }
                    guard scale > 0 else { continue }
                    let piece = wild ?? here[mesh.index(column: column,
                                                        slot: slot, row: row,
                                                        of: here.count)]
                    let layer = (tint(of: grow) * Self.repaints
                        + (hue ?? repainted(at: middle, over: size)))
                        * embers + burned(at: middle, over: size)
                    // Черёд переходов считается по месту в сетке, а не по
                    // уплывшей фигурке; разъезд достаётся только месту, куда
                    // её кладут.
                    let seat: CGPoint
                    if lag.isEmpty {
                        seat = middle
                    } else {
                        let apart = lag[Sway.layer(column: column, row: row,
                                                   slot: slot, era: era)]
                        seat = CGPoint(x: middle.x + apart.width,
                                       y: middle.y + apart.height)
                    }
                    add(SproutShapes.pieces[piece], at: seat,
                        scale: scale, slot: layer, to: &layers)
                }
                x += pitchX
                column += 1
            }
            y += pitchY
            row += 1
        }
        return layers
    }

    /// Такты кутерьмы — из середины: при тряске нажимать некуда.
    private func heart(of size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// Перемешанный номер клетки, а не случайное число: случайное мигало бы
    /// каждый кадр и разошлось бы с подложкой под вырезом.
    private static func scramble(_ column: Int, _ row: Int, _ slot: Int,
                                 _ state: Int) -> Int {
        var mix = column &* 73_856_093
        mix ^= row &* 19_349_663
        mix ^= slot &* 83_492_791
        mix ^= state &* 2_654_435_761
        mix ^= mix >> 13
        return abs(mix)
    }

    private func add(_ piece: SproutShapes.Piece, at middle: CGPoint,
                     scale: CGFloat, slot: Int, to layers: inout [Path]) {
        guard scale != 1 else {
            layers[slot].addPath(piece.path, transform: CGAffineTransform(
                translationX: middle.x - piece.centre.x,
                y: middle.y - piece.centre.y))
            return
        }
        // Вокруг своей середины: от угла фигурку уводило бы вбок.
        layers[slot].addPath(piece.path, transform:
            CGAffineTransform(translationX: middle.x, y: middle.y)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -piece.centre.x, y: -piece.centre.y))
    }

    /// Перекраска идёт фронтом: у ближних цвет уже новый, у дальних ещё
    /// прежний.
    private func repainted(at middle: CGPoint, over size: CGSize) -> Int {
        guard let repaint else { return Self.repaints - 1 }
        let turn = placed(repaint.front).turn(at: middle, over: size)
        let step = (repaint.step - turn * (1 - Metrics.repaintSpan))
            / Metrics.repaintSpan
        let part = min(max(step, 0), 1)
        let eased = part * part * (3 - 2 * part)
        return Int((eased * Double(Self.repaints - 1)).rounded())
    }

    /// Смена набора: фигурка сжимается до нуля прежней и вырастает новой,
    /// волной от нажатой клетки или с краёв. Сквозь ноль проскакивает быстро.
    private func change(_ swap: Reshape, at middle: CGPoint,
                        over size: CGSize) -> (CGFloat, Bool) {
        let turn = placed(swap.front).turn(at: middle, over: size)
        let step = (swap.step - turn * (1 - Metrics.swapSpan)) / Metrics.swapSpan
        guard step > 0 else { return (1, true) }
        guard step < 1 else { return (1, false) }
        guard step >= 0.5 else {
            let x = step * 2
            return (CGFloat(1 - x * x * x), true)
        }
        let x = (step - 0.5) * 2
        return (CGFloat(1 - pow(1 - x, 3)), false)
    }

    /// Ступень тления. Разгорается от убранной карточки наружу, волной вдвое
    /// шире полива и на весь отсчёт; гаснет обратной волной, стекая туда,
    /// откуда разгорелось.
    private func burned(at middle: CGPoint, over size: CGSize) -> Int {
        guard let ember else { return 0 }
        let from = local(ember.origin)
        let span = Metrics.emberSpan
        let out = Front.point(from).turn(at: middle, over: size)
        var lit = eased((ember.rise - out * (1 - span)) / span)
        if ember.fall > 0 {
            let back = Front.collapse(from).turn(at: middle, over: size)
            lit *= 1 - eased((ember.fall - back * (1 - span)) / span)
        }
        return Int((lit * Double(Self.embers - 1)).rounded())
    }

    private func eased(_ value: Double) -> Double {
        let part = min(max(value, 0), 1)
        return part * part * (3 - 2 * part)
    }

    /// Синеет только поднявшаяся фигурка — считаем от подъёма, а не от общего
    /// размера: иначе синели бы всходящие. Волна читается синим гребнем между
    /// зелёных ямок.
    private func tint(of grow: CGFloat) -> Int {
        guard grow > 1 else { return 0 }
        let share = min(Double(grow - 1) / Metrics.popAmp, 1)
        return Int((share * Double(Self.tints - 1)).rounded())
    }

    /// Направление всходов своё на каждый запуск: всегда снизу вверх — и на
    /// третий раз это уже заставка.
    private func sprouted(at middle: CGPoint, over size: CGSize) -> CGFloat {
        guard bloom < 1 else { return 1 }
        guard bloom > 0 else { return 0 }
        let turn = bloomFront.turn(at: middle, over: size)
        let step = (bloom - turn * (1 - Metrics.bloomSpan)) / Metrics.bloomSpan
        guard step > 0 else { return 0 }
        guard step < 1 else { return 1 }
        return CGFloat(1 - pow(1 - step, 3))
    }

    /// Всплеск фигурки — по расстоянию до места полива: одинаковые размах и
    /// длительность, разное время прихода, поэтому видно кольцо. Ямка —
    /// гребень — ямка; окно широкое, и волна идёт полосами, а не перебором
    /// рядов.
    private func pop(at middle: CGPoint) -> CGFloat {
        guard let wave else { return 1 }
        let far = hypot(middle.x - source.x, middle.y - source.y)
        let start = Double(min(far / Metrics.waveReach, 1))
            * (1 - Metrics.popSpan)
        let step = (wave - start) / Metrics.popSpan
        guard step > 0, step < 1 else { return 1 }
        // Полтора периода синуса, умноженные на оболочку: она прижимает концы
        // окна к нулю и по скорости — иначе фигурка трогалась рывком.
        let swing = -sin(3 * .pi * step) * sin(.pi * step)
        // Размах переходит в поджим плавно: по знаку прыгал наклон, и фигурка
        // спотыкалась.
        let mean = (Metrics.popAmp + Metrics.popDip) / 2
        let half = (Metrics.popAmp - Metrics.popDip) / 2
        return CGFloat(1 + swing * (mean + half * tanh(swing / Metrics.popBlend)))
    }
}

/// Волна полива. Одна на приложение: фон рисуется в двух местах, и свои волны
/// разошлись бы швом. Хранится начало, а долю на каждый кадр спрашивает
/// `TimelineView` — свой цикл со сном дёргался.
@Observable
final class Cheer {
    static let shared = Cheer()

    private(set) var start: Date?

    private(set) var origin: CGPoint = .zero

    /// Новая волна отменяет старую.
    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    @ObservationIgnored private var waiting: [CGRect] = []
    @ObservationIgnored private var queueRun: Task<Void, Never>?

    /// Встать в очередь за идущей волной — для показа цвета волны. Полив так
    /// не делает: он откликается сразу.
    @MainActor
    func queue(from plate: CGRect) {
        guard start != nil else { return now(from: plate) }
        // Очередь — отклик на нажатия, а не архив: переполненная теряет самую
        // позднюю.
        if waiting.count >= Motion.queued { waiting.removeLast() }
        waiting.append(plate)
        guard queueRun == nil else { return }
        queueRun = Task { @MainActor in
            while !waiting.isEmpty {
                if let step = wave(at: Date()) {
                    try? await Task.sleep(for: .seconds(
                        (1 - step) * Motion.cheerSeconds + Motion.changeGap))
                }
                if Task.isCancelled { break }
                now(from: waiting.removeFirst())
            }
            queueRun = nil
        }
    }

    /// Полили вот здесь (плашка в координатах окна). Волна стартует с форой
    /// на путь от середины плашки до края — под плашкой узора не видно, а без
    /// форы фон трогался позже тени.
    func now(from plate: CGRect) {
        run?.cancel()
        origin = CGPoint(x: plate.midX, y: plate.midY)
        let lead = Self.lead(across: plate)
        start = Date().addingTimeInterval(-lead)
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.cheerSeconds - lead))
            guard !Task.isCancelled else { return }
            start = nil
        }
    }

    /// По вписанной окружности: фронт к началу не выпрыгивает из плашки.
    private static func lead(across plate: CGRect) -> Double {
        let radius = Double(min(plate.width, plate.height)) / 2
        return radius / Double(Metrics.waveReach)
            * (1 - Metrics.popSpan) * Motion.cheerSeconds
    }

    func wave(at moment: Date) -> Double? {
        guard let start else { return nil }
        let step = moment.timeIntervalSince(start) / Motion.cheerSeconds
        return step < 1 ? step : nil
    }
}

/// Узор тлеет красным, пока удаление можно отменить: разливается весь отсчёт
/// и к концу заливает экран, потом гаснет обратно. Один на приложение, как
/// `Cheer`; держит начало и конец, долю спрашивает экран.
@Observable
final class Ember {
    static let shared = Ember()

    private(set) var start: Date?

    private(set) var origin: CGPoint = .zero

    /// Не наблюдается: чтобы расписание кадров шло, хватает `start`.
    @ObservationIgnored private var fade: Date?

    /// Гаснет оттуда, докуда успело разгореться.
    @ObservationIgnored private var reached = 0.0

    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    /// Новое удаление — новый отсчёт: красное идёт от новой карточки.
    @MainActor
    func light(from plate: CGRect) {
        run?.cancel()
        origin = CGPoint(x: plate.midX, y: plate.midY)
        fade = nil
        reached = 0
        start = Date()
    }

    @MainActor
    func douse() {
        guard let start, fade == nil else { return }
        reached = min(Date().timeIntervalSince(start) / Motion.undoSeconds, 1)
        fade = Date()
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.emberOutSeconds))
            guard !Task.isCancelled else { return }
            self.start = nil
            self.fade = nil
        }
    }

    func smoulder(at moment: Date) -> Smoulder? {
        guard let start else { return nil }
        guard let fade else {
            let rise = moment.timeIntervalSince(start) / Motion.undoSeconds
            return Smoulder(origin: origin, rise: min(max(rise, 0), 1),
                            fall: 0)
        }
        let fall = moment.timeIntervalSince(fade) / Motion.emberOutSeconds
        guard fall < 1 else { return nil }
        return Smoulder(origin: origin, rise: reached, fall: max(fall, 0))
    }
}

struct Smoulder {
    var origin: CGPoint
    var rise: Double
    var fall: Double
}

/// Через окружение: число берётся у окна, а окно видно только из корня.
private struct NotchKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var notch: CGFloat {
        get { self[NotchKey.self] }
        set { self[NotchKey.self] = newValue }
    }
}

struct Recolour {
    /// Пара целиком: сменить могли и цвет узора, и цвет волны.
    var from: Shade
    var fromWave: Shade

    /// Цель — у перехода, а не из настройки: переход может быть не последним
    /// в очереди.
    var to: Shade
    var toWave: Shade

    var front: Front

    /// Без сглаживания: сглаживает сам узор.
    var step: Double
}

/// Смена цвета узора — перекраска фронтом от нажатого кружка, без роста и
/// ухода: фигурка та же, ей довольно перелиться. Хранится начало, по той же
/// причине, что у `Cheer`.
@Observable
final class Repaint {
    static let shared = Repaint()

    private(set) var start: Date?

    @ObservationIgnored private var painting: Recolour?
    @ObservationIgnored private var waiting: [Recolour] = []
    @ObservationIgnored private var run: Task<Void, Never>?

    private init() {}

    /// Зовётся до смены настройки — прежний цвет надо запомнить. Второе
    /// нажатие встаёт в очередь, а не обрывает первое. Пары «откуда — куда»
    /// сцепляются сами.
    @MainActor
    func begin(base: Tint, wave: Tint, to shape: Tint, toWave: Tint,
               from spot: CGPoint) {
        // Переполнилась очередь — последний ждущий перенимает цель нового:
        // хвост не растёт, конец верный.
        if waiting.count >= Motion.queued, var last = waiting.popLast() {
            last.to = Shade(shape)
            last.toWave = Shade(toWave)
            last.front = .point(spot)
            waiting.append(last)
        } else {
            waiting.append(Recolour(from: Shade(base), fromWave: Shade(wave),
                                    to: Shade(shape), toWave: Shade(toWave),
                                    front: .point(spot), step: 0))
        }
        guard run == nil else { return }
        // Первый переход трогается прямо здесь, а не в задаче: иначе на кадр
        // весь узор вспыхивал новым цветом и откатывался.
        step()
        run = Task { @MainActor in
            while painting != nil {
                // Пока идёт промежуток, доля стоит на единице — узор держит
                // цель отыгравшего.
                try? await Task.sleep(
                    for: .seconds(Motion.repaintSeconds + Motion.changeGap))
                if Task.isCancelled { break }
                step()
            }
            painting = nil
            start = nil
            run = nil
        }
    }

    @MainActor
    private func step() {
        painting = waiting.isEmpty ? nil : waiting.removeFirst()
        start = painting == nil ? nil : Date()
    }

    func recolour(at moment: Date) -> Recolour? {
        guard var now = painting, let start else { return nil }
        let done = moment.timeIntervalSince(start) / Motion.repaintSeconds
        now.step = min(max(done, 0), 1)
        return now
    }
}

/// Смена набора фигурок. Прежний набор держится вместе с новым — пока волна
/// идёт, на экране оба; раскладка у прежнего своя, иначе он перетасовался бы
/// перед уходом.
struct Reshape {
    var from: [Int]
    var fromWeave: Weave

    /// Цель — у перехода: настройка уже может показывать цель последнего
    /// нажатия.
    var to: [Int]
    var toWeave: Weave
    /// Добавили фигурку — из её клетки; убрали — с краёв экрана.
    var front: Front
    var step: Double
}

/// Запуск: заставка и ступени входа — узор, заголовок, комната, сетка, панель
/// вкладок. Один за жизнь приложения: из фона оно собирается сразу.
@Observable
final class Launch {
    static let shared = Launch()

    private(set) var step = 0

    private(set) var greeting = true

    /// Всходы — полосой в случайную сторону, своей на каждый запуск.
    @ObservationIgnored private(set) var bloomFront =
        Front.sweep(Double.random(in: 0 ..< 2 * Double.pi))

    /// Три числа раскладки — свои на каждый холодный запуск.
    @ObservationIgnored private let twistX = Int.random(in: 0 ..< 64)
    @ObservationIgnored private let twistY = Int.random(in: 0 ..< 64)
    @ObservationIgnored private let twistStart = Int.random(in: 0 ..< 64)

    private(set) var swapStart: Date?

    @ObservationIgnored private var swapping: Reshape?
    @ObservationIgnored private var swaps: [Reshape] = []
    @ObservationIgnored private var swapRun: Task<Void, Never>?

    /// Из тех же трёх чисел: пока фигурок столько же, раскладка та же.
    func weave(for count: Int) -> Weave {
        Weave(count: count, twistX: twistX, twistY: twistY, start: twistStart)
    }

    /// Часами, а не долей в состоянии вью — по той же причине, что у `Cheer`.
    private(set) var bloomStart: Date?

    static let last = 5

    @ObservationIgnored private var ran = false

    /// Новые всходы отменяют прежние.
    @ObservationIgnored private var blooming: Task<Void, Never>?

    private init() {}

    /// Второй раз ничего не делает: запуск у приложения один.
    @MainActor
    func run() async {
        guard !ran else { return }
        ran = true
        try? await Task.sleep(for: .seconds(Motion.welcomeHold))
        withAnimation(Motion.welcomeLeave) { greeting = false }
        // Ступени ждут, пока заставка сойдёт: иначе узор и заголовок вставали
        // на места под ней.
        try? await Task.sleep(for: .seconds(Motion.welcomeLeaveSeconds))
        for _ in 1...Self.last {
            withAnimation(Motion.enter) { step += 1 }
            if step == 1 { sprout() }
            try? await Task.sleep(for: .seconds(Motion.enterStep))
        }
    }

    /// Сменить набор фигурок: прежний уходит волной, новый приходит следом —
    /// из нажатой клетки или с краёв. Второе нажатие встаёт в очередь; пары
    /// «откуда — куда» сцепляются сами.
    @MainActor
    func reshape(from before: [Int], to after: [Int], front: Front) {
        // Очередь — как у `Repaint.begin`.
        if swaps.count >= Motion.queued, var last = swaps.popLast() {
            last.to = after
            last.toWeave = weave(for: after.count)
            last.front = front
            swaps.append(last)
        } else {
            swaps.append(Reshape(from: before,
                                 fromWeave: weave(for: before.count),
                                 to: after, toWeave: weave(for: after.count),
                                 front: front, step: 0))
        }
        guard swapRun == nil else { return }
        // Первая смена трогается здесь — см. `Repaint.begin`.
        swapStep()
        swapRun = Task { @MainActor in
            while swapping != nil {
                // Пока идёт промежуток, узор держит набор отыгравшего, а не
                // настройку.
                try? await Task.sleep(
                    for: .seconds(Motion.swapSeconds + Motion.changeGap))
                if Task.isCancelled { break }
                swapStep()
            }
            swapping = nil
            swapStart = nil
            swapRun = nil
        }
    }

    @MainActor
    private func swapStep() {
        swapping = swaps.isEmpty ? nil : swaps.removeFirst()
        swapStart = swapping == nil ? nil : Date()
    }

    func reshape(at moment: Date) -> Reshape? {
        guard var now = swapping, let swapStart else { return nil }
        let done = moment.timeIntervalSince(swapStart) / Motion.swapSeconds
        now.step = min(max(done, 0), 1)
        return now
    }

    @MainActor
    func sprout() {
        bloomFront = .sweep(Double.random(in: 0 ..< 2 * Double.pi))
        bloomStart = Date()
        Feel.sprout()
        blooming?.cancel()
        // Погасим часы, чтобы расписание холста встало на паузу.
        blooming = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.bloomSeconds))
            guard !Task.isCancelled else { return }
            bloomStart = nil
        }
    }

    func bloom(at moment: Date) -> Double {
        guard let bloomStart else { return step >= 1 ? 1 : 0 }
        let done = moment.timeIntervalSince(bloomStart) / Motion.bloomSeconds
        return done < 1 ? done : 1
    }
}

/// Ступень входа: элемент поднимается на место и наводится на резкость.
/// Начальное значение — из счётчика, иначе созданный позже элемент всплывал
/// бы заново.
struct Enter: ViewModifier {
    let step: Int

    let rise: CGFloat

    @State private var shown: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(step: Int, rise: CGFloat = Motion.enterRise) {
        self.step = step
        self.rise = rise
        _shown = State(initialValue: Launch.shared.step >= step)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown || reduceMotion ? 0 : Metrics.textBlur)
            .offset(y: shown ? 0 : rise)
            .onChange(of: Launch.shared.step >= step) { _, open in
                withAnimation(Motion.enter) { shown = open }
            }
    }
}

/// Замер, спрятанный от SwiftUI: меняется каждый кадр прокрутки, а читается
/// только в обработчике нажатия. Прятать то, что рисуется, нельзя — на этом
/// уже обжигались, см. `revealed` на главной.
final class Spot {
    var rect: CGRect = .zero

}

/// Фон: ровный цвет и узор. Рисуется в двух местах — экраном и подложкой под
/// вырезом — от одного угла окна, поэтому узор в них совпадает.
private struct SproutField: View {
    /// Угол холста в окне: лист настроек висит ниже окна.
    @State private var corner: CGPoint = .zero

    var body: some View {
        // Настройку читаем телом поля, а не внутри `TimelineView`: на паузе
        // расписания смена фигурок осталась бы незамеченной.
        let shapes = Settings.shared.chosen
        let weave = Launch.shared.weave(for: shapes.count)
        let baseTint = Settings.shared.patternTint
        let waveTint = Settings.shared.waveTint
        let repainting = Repaint.shared.start != nil
        let frenzied = Frenzy.shared.start != nil
        return ZStack {
            Palette.background

            // Холст шире экрана на размах параллакса, но живёт в наложении на
            // пустой слой и обрезан по нему — иначе ZStack вырос бы.
            Color.clear
                .overlay {
                    // Долю берём у `TimelineView`: он будит ровно к кадру.
                    // Нет ни волны, ни всходов, ни переходов — расписание на
                    // паузе.
                    TimelineView(.animation(
                        paused: Cheer.shared.start == nil
                            && Launch.shared.bloomStart == nil
                            && Launch.shared.swapStart == nil
                            && Ember.shared.start == nil
                            && !repainting && !frenzied)) { frame in
                        SproutPattern(wave: Cheer.shared.wave(at: frame.date),
                                      origin: Cheer.shared.origin,
                                      canvas: corner,
                                      bloomFront: Launch.shared.bloomFront,
                                      bloom: Launch.shared.bloom(at: frame.date),
                                      shapes: shapes,
                                      weave: weave,
                                      swap: Launch.shared.reshape(at: frame.date),
                                      repaint: Repaint.shared
                                          .recolour(at: frame.date),
                                      frolic: Frenzy.shared
                                          .frolic(at: frame.date),
                                      baseShade: Shade(baseTint),
                                      waveShade: Shade(waveTint),
                                      lag: Settings.shared.sway
                                          ? Tilt.shared.lag : [],
                                      era: Tilt.shared.era,
                                      ember: Ember.shared
                                          .smoulder(at: frame.date))
                    }
                    .padding(-Metrics.parallax)
                    .offset(x: Tilt.shared.shift.width,
                            y: Tilt.shared.shift.height)
                }
                .clipped()
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin }
            action: { corner = $0 }
    }
}

/// Фон экрана: узор и растяжка внизу под панелью вкладок. Равенство не
/// объявлено нарочно: тема приходит окружением, и по равенству свойств холст
/// остался бы в старой теме.
struct SproutBackground: View {
    var body: some View {
        ZStack {
            SproutField()

            VStack {
                // Сверху не гасим: там подложка рисует тот же узор.
                Spacer(minLength: 0)
                wash
            }
        }
        .ignoresSafeArea()
        .onAppear { Tilt.shared.watch() }
        .onDisappear { Tilt.shared.unwatch() }
        // `initial` — чтобы выключенный параллакс не ждал первой смены.
        .onChange(of: Settings.shared.parallax, initial: true) { _, on in
            Tilt.shared.parallax = on
        }
    }

    private var wash: some View {
        let solid = Palette.background
        return LinearGradient(
            stops: [
                .init(color: solid.opacity(0), location: 0),
                .init(color: solid, location: 1 - Metrics.washStop),
                .init(color: solid, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Metrics.washHeight)
    }
}

extension View {
    /// Подложка под вырезом — экранам, у которых верх ничем не занят. Главной
    /// не нужна: верх там держит растяжка, и две подложки дали бы черту на
    /// границе.
    func sproutNotchCover() -> some View {
        modifier(SproutNotchCover())
    }
}

/// Подложка под вырезом — тот же фон от того же угла окна, обрезанный по
/// вырезу: узор проходит насквозь без шва, а содержимое под строку состояния
/// не заезжает.
private struct SproutNotchCover: ViewModifier {
    @Environment(\.notch) private var notch

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            // Без `clipped`: узор уже обрезан по своему слою, а лишний проход
            // растеризации стоил бы на каждом кадре волны.
            SproutField()
                .frame(height: notch)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

/// Одна фигурка — для выбора в настройках. Масштаб общий на все: росток
/// крупнее капли и в выборе, как в узоре.
struct SproutPiece: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let pieces = SproutShapes.pieces
        let piece = pieces[min(max(index, 0), pieces.count - 1)]
        let box = SproutShapes.pieceBox
        let scale = min(rect.width / box.width, rect.height / box.height)
        return piece.path.applying(
            CGAffineTransform(translationX: rect.midX, y: rect.midY)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -piece.centre.x, y: -piece.centre.y))
    }
}

/// Логотип: три листа контуром и две капли. В плашке макета логотип сжат по
/// ширине, поэтому шкал две.
struct SproutLogo: View, Animatable {
    /// Высота — ровно коробка контуров: обводка выходит за неё только вбок.
    var height: CGFloat = 21.1

    /// По умолчанию — сжатые пропорции плашки; `plain` — без искажения.
    var aspect: CGFloat = Self.badge

    static let badge: CGFloat = 14.6986 / 21.1
    static let plain: CGFloat =
        (SproutShapes.logoBox.width + SproutShapes.logoStroke)
            / SproutShapes.logoBox.height

    /// Насколько логотип собрался. Числом: части рисует один холст, и
    /// разъезжаются они задержкой внутри хода.
    var reveal: Double = 1

    /// Иначе SwiftUI менял бы долю скачком: холст сам промежуточных значений
    /// не считает.
    var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    /// Снизу вверх, как растёт росток. Лист со стеблем — одна часть.
    private static let parts: [(leaves: [Int], drops: [Int])] = [
        (leaves: [2, 3], drops: []),
        (leaves: [0, 1], drops: []),
        (leaves: [4], drops: []),
        (leaves: [], drops: [0]),
        (leaves: [], drops: [1]),
    ]

    private func grown(_ index: Int) -> Double {
        guard reveal < 1 else { return 1 }
        let span = 1 - Double(Self.parts.count - 1) * Motion.logoLag
        let step = (reveal - Double(index) * Motion.logoLag) / span
        guard step > 0 else { return 0 }
        guard step < 1 else { return 1 }
        // Без пружины: пять частей с отскоком вразнобой читались бы дрожью.
        return 1 - pow(1 - step, 3)
    }

    var body: some View {
        Canvas { context, size in
            let box = SproutShapes.logoBox
            let pad = SproutShapes.logoStroke / 2
            let sx = size.width / (box.width + 2 * pad)
            let sy = size.height / box.height
            let scale = CGAffineTransform(scaleX: sx, y: sy)
            // Острые стыки и срезанные концы — как в макете.
            let style = StrokeStyle(
                lineWidth: SproutShapes.logoStroke * (sx * sy).squareRoot(),
                lineCap: .butt,
                lineJoin: .miter,
                miterLimit: 4)

            func place(_ path: Path) -> Path {
                path.applying(scale).offsetBy(dx: pad * sx, dy: 0)
            }

            for (index, part) in Self.parts.enumerated() {
                let t = grown(index)
                guard t > 0 else { continue }
                let leaves = part.leaves.map {
                    place(SproutShapes.logoLeaves[$0])
                }
                let drops = part.drops.map { place(SproutShapes.logoDrops[$0]) }

                // Вокруг собственной середины части — иначе она съезжалась бы
                // к центру логотипа.
                var layer = context
                if t < 1, let box = (leaves + drops)
                    .map(\.boundingRect)
                    .reduce(nil, { (all: CGRect?, one) in
                        all.map { $0.union(one) } ?? one
                    }) {
                    let scale = Motion.logoScale
                        + (1 - Motion.logoScale) * CGFloat(t)
                    layer.opacity = t
                    layer.translateBy(x: box.midX, y: box.midY)
                    layer.scaleBy(x: scale, y: scale)
                    layer.translateBy(x: -box.midX, y: -box.midY)
                }

                for leaf in leaves {
                    layer.stroke(leaf, with: .color(Palette.green),
                                 style: style)
                }
                for drop in drops {
                    layer.fill(drop, with: .color(Palette.water))
                }
            }
        }
        .frame(width: height * aspect, height: height)
        .accessibilityHidden(true)
    }
}
