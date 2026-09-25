import Foundation
import SwiftUI

/// Узор фона — отдельной вью: при сдвиге параллакса её свойства не меняются,
/// и холст не перерисовывается, а только съезжает. Тему читает явно — иначе
/// смена темы не перерисовала бы холст.
struct SproutPattern: View {
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

    /// Часы гирлянды, секунды; пусто — гирлянды нет. Огоньки — капли узора.
    var garland: Double?

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

    /// Перелив цвета — тоже ступенями; в покое занят один слой.
    private static let repaints = 6

    /// Вторая часть номера слоя: сперва ступени перелива, за ними — оттенки
    /// по номеру, для кутерьмы и огоньков гирлянды. Одним рядом: оттенков
    /// больше, чем ступеней, и общий номер залезал бы в соседнюю синеву.
    private static let tones = repaints + Tint.allCases.count

    /// Цвета огоньков — как у гирлянды на ёлке.
    private static let bulbs: [Tint] = [.rose, .lemon, .blue, .amber, .green]

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
        return (rest / Self.tones, rest % Self.tones, slot % embers)
    }

    private func heat(_ burn: Int) -> Double {
        embers > 1 ? Double(burn) / Double(embers - 1) : 0
    }

    private func paint(_ tone: Int) -> (base: Shade, wave: Shade) {
        // Оттенок по номеру — и в покое, и на гребне свой: у кутерьмы
        // перелива нет, цвет меняется, когда фигурка проходит через ноль, а
        // огонёк горит своим цветом и на волне.
        if tone >= Self.repaints {
            let tint = Tint.allCases[tone - Self.repaints]
            return (Shade(tint), Shade(tint))
        }
        guard let repaint else { return (baseShade, waveShade) }
        let part = Double(tone) / Double(Self.repaints - 1)
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
                            count: Self.tints * Self.tones * embers)
        // Настройке не доверяем: промах по границам — падение. Цель берём у
        // идущего перехода: настройка может быть уже на нажатие впереди.
        let every = SproutShapes.every
        let picked = (swap?.to ?? shapes).filter(every.indices.contains)
        let list = picked.isEmpty ? [0] : picked
        let arrivingWeave = swap?.toWeave ?? weave
        let leaving = swap?.from.filter(every.indices.contains)
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
                    let (burn, flare) = burned(at: middle, over: size)
                    var scale = grow * flare
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
                            hue = Self.repaints
                                + state % Tint.allCases.count
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
                    var step = tint(of: grow)
                    var tone = hue ?? repainted(at: middle, over: size)
                    if let garland, wild == nil,
                       piece == SproutShapes.dropIndex {
                        let bulb = Self.bulb(column, row, slot, at: garland)
                        tone = bulb.tone
                        step = max(step, bulb.step)
                    }
                    let layer = (step * Self.tones + tone) * embers + burn
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
                    add(every[piece], at: seat,
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

    /// Огонёк гирлянды: цвет — по месту, перемешанным номером, чтобы цвета
    /// не шли полосами; яркость — бегущим огнём по диагонали, как у
    /// настоящей гирлянды. Совсем не гаснет: погасший огонёк читался бы
    /// обычной каплей.
    private static func bulb(_ column: Int, _ row: Int, _ slot: Int,
                             at time: Double) -> (tone: Int, step: Int) {
        let colour = bulbs[scramble(column, row, slot, 7) % bulbs.count]
        let place = Double(2 * column + slot + row)
        let phase = time / Motion.garlandPeriod - place / Metrics.garlandSpan
        let run = pow(max(0, cos(2 * .pi * phase)), 3)
        let level = Metrics.garlandFloor + (1 - Metrics.garlandFloor) * run
        return (repaints + colour.rawValue,
                Int((level * Double(tints - 1)).rounded()))
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

    /// Тление в клетке: ступень красного и всплеск. Та же волна, что у
    /// полива, только медленная: идёт от убранной карточки весь отсчёт, и
    /// фигурка краснеет к гребню, а после всплеска встаёт в свой размер
    /// красной. Черёд — до дальнего угла холста, а не общей меркой: к концу
    /// отсчёта красным залит весь экран. Гаснет быстрой волной оттуда же:
    /// она возвращает цвет и гасит недоигравшие всплески.
    private func burned(at middle: CGPoint,
                        over size: CGSize) -> (burn: Int, scale: CGFloat) {
        guard let ember else { return (0, 1) }
        let from = local(ember.origin)
        let out = 1 - Front.collapse(from).turn(at: middle, over: size)
        let span = Metrics.emberSpan
        let lead = out * (1 - span)
        let reached = (ember.reached - lead) / span
        let lit = eased(reached * 2)
        var flare = reached > 0 ? Self.bounce((ember.rise - lead) / span) : 1
        guard ember.fall > 0 else { return (embered(lit), flare) }
        let back = (ember.fall - out * (1 - Metrics.emberBackSpan))
            / Metrics.emberBackSpan
        let calm = 1 - eased(back * 2)
        flare = 1 + (flare - 1) * CGFloat(calm)
        flare *= 1 + (Self.bounce(back) - 1) * CGFloat(lit)
        return (embered(lit * calm), flare)
    }

    private func embered(_ lit: Double) -> Int {
        Int((lit * Double(Self.embers - 1)).rounded())
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
        return Self.bounce((wave - start) / Metrics.popSpan)
    }

    /// Всплеск за своё окно 0…1; вне окна фигурка в своём размере. Общий у
    /// полива и тления.
    private static func bounce(_ step: Double) -> CGFloat {
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
