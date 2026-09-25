import Foundation
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

    /// Снежинка: шесть лучей с круглыми концами и по паре веточек на каждом.
    /// Лучи потолще, чем у настоящей: тонкая снежинка рядом с каплей
    /// терялась. Шире капли на пункт — на гребне соседям хватает места.
    static let snowflake: Path = {
        var p = Path()
        let middle = addedCentre
        let reach: CGFloat = 15.6, beam: CGFloat = 3.8
        let fork: CGFloat = 7.2, twig: CGFloat = 6.8, sprig: CGFloat = 3
        for step in 0 ..< 6 {
            let arm = CGAffineTransform(translationX: middle.x, y: middle.y)
                .rotated(by: CGFloat(step) * .pi / 3)
            // Скругление в полширины — круглые концы; луч идёт вверх от
            // середины и поворачивается.
            p.addRoundedRect(in: CGRect(x: -beam / 2, y: -reach,
                                        width: beam, height: reach),
                             cornerSize: CGSize(width: beam / 2,
                                                height: beam / 2),
                             transform: arm)
            // Веточки расходятся наружу галочкой.
            for side: CGFloat in [-1, 1] {
                p.addRoundedRect(in: CGRect(x: -sprig / 2, y: -twig,
                                            width: sprig, height: twig),
                                 cornerSize: CGSize(width: sprig / 2,
                                                    height: sprig / 2),
                                 transform: arm.translatedBy(x: 0, y: -fork)
                                     .rotated(by: side * 0.9))
            }
        }
        p.addEllipse(in: CGRect(x: middle.x - 4, y: middle.y - 4,
                                width: 8, height: 8))
        return p
    }()

    /// Кленовый лист: три больших лопасти, две малых и черешок. Правая
    /// половина от верхушки по часовой, левая — её зеркало. Углы чуть
    /// скруглены, как всё в узоре.
    static let maple: Path = {
        let half: [CGPoint] = [
            CGPoint(x: 0, y: -18), CGPoint(x: 3.4, y: -12.2),
            CGPoint(x: 6.6, y: -13.8), CGPoint(x: 5.8, y: -6.8),
            CGPoint(x: 10.8, y: -10.2), CGPoint(x: 11.6, y: -7.6),
            CGPoint(x: 15.2, y: -8.6), CGPoint(x: 13.2, y: -2.6),
            CGPoint(x: 14.8, y: -1), CGPoint(x: 8.8, y: 3.4),
            CGPoint(x: 10.2, y: 7), CGPoint(x: 2.8, y: 5.8),
            CGPoint(x: 1.5, y: 6.6), CGPoint(x: 1.5, y: 15),
        ]
        let outline = half + half.dropFirst().reversed().map {
            CGPoint(x: -$0.x, y: $0.y)
        }
        // Коробка −18…15 по высоте: середину коробки ставим в общую.
        return rounded(outline.map {
            CGPoint(x: $0.x + addedCentre.x, y: $0.y + addedCentre.y + 1.5)
        }, radius: 0.7)
    }()

    /// Многоугольник со скруглёнными углами: в каждый угол вписана дуга.
    private static func rounded(_ points: [CGPoint], radius: CGFloat) -> Path {
        var p = Path()
        guard let first = points.first, let last = points.last else { return p }
        p.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for (index, corner) in points.enumerated() {
            p.addArc(tangent1End: corner,
                     tangent2End: points[(index + 1) % points.count],
                     radius: radius)
        }
        p.closeSubpath()
        return p
    }

    struct Piece {
        var path: Path
        var centre: CGPoint
    }

    /// Фигурки из настроек — их выбирают и между ними мечется кутерьма.
    static let pieces: [Piece] = [
        Piece(path: leaf, centre: leafCentre),
        Piece(path: drop, centre: dropCentre),
        Piece(path: flower, centre: addedCentre),
        Piece(path: pot, centre: addedCentre),
    ]

    /// Все фигурки узора: за выбираемыми — те, что приносит время года, см.
    /// `Motif.extra`.
    static let every: [Piece] = pieces + [
        Piece(path: snowflake, centre: addedCentre),
        Piece(path: maple, centre: addedCentre),
    ]

    /// Капля — она же огонёк гирлянды.
    static let dropIndex = 1

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
