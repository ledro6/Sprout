import Foundation

/// Цвет узора или волны: готовый (`Tint`) или свой — выбранный в палитре
/// iOS. Своему бледная ипостась подбирается той же светлоты, что у готовых:
/// узор не станет заметнее или бледнее от смены цвета. Слишком светлый свой
/// притемняется — иначе волна на бледном узоре не видна.
enum Hue: Hashable, Codable, Sendable {
    case preset(Tint)
    case own(Channels)

    static let pattern = Hue.preset(Tint.defaultPattern)
    static let wave = Hue.preset(Tint.defaultWave)

    /// Своих цветов — не больше, чем готовых: ряд и так в две строки.
    static let ownLimit = 11

    /// Светлота бледной ипостаси — как у зелёного из макета, по формуле для
    /// sRGB; готовые посчитаны так же.
    static let paleness = 0.925

    /// Насыщенная не светлее этого — самая светлая из готовых, лимонная, чуть
    /// темнее.
    static let vividCeiling = 0.62

    var vivid: Channels {
        switch self {
        case .preset(let tint): tint.vivid
        case .own(let colour): Self.deepened(colour)
        }
    }

    var pale: Channels {
        switch self {
        case .preset(let tint): tint.pale
        case .own(let colour): Self.paled(colour)
        }
    }

    var shade: Shade { Shade(pale: pale, vivid: vivid) }

    var title: String {
        switch self {
        case .preset(let tint): tint.title
        case .own: Lang.text("Свой цвет")
        }
    }

    static func brightness(_ c: Channels) -> Double {
        (0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue) / 255
    }

    /// Светлый — к чёрному, пока не встанет на потолок; тёмный — как есть.
    static func deepened(_ c: Channels) -> Channels {
        let light = brightness(c)
        guard light > vividCeiling else { return c }
        return Channels.mix(c, Channels(0, 0, 0), 1 - vividCeiling / light)
    }

    /// Насыщенная — к белому, пока светлота не сойдётся с готовыми.
    static func paled(_ c: Channels) -> Channels {
        let deep = deepened(c)
        let light = brightness(deep)
        let k = (paleness - light) / max(1 - light, 0.0001)
        return Channels.mix(deep, Channels(255, 255, 255), k)
    }

    /// Тот же цвет — с точностью до шага канала: палитра отдаёт дроби, и
    /// выбранный дважды цвет иначе встал бы в ряд двумя кружками.
    static func same(_ a: Channels, _ b: Channels) -> Bool {
        abs(a.red - b.red) < 1 && abs(a.green - b.green) < 1
            && abs(a.blue - b.blue) < 1
    }
}
