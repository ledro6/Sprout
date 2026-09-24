import Foundation

/// Оттенок узора или волны. У каждого две ипостаси — бледная для покоя и
/// насыщенная для волны; доли и тему решает `Palette`. Живёт в модели, чтобы
/// числа проверялись без `Color`.
enum Tint: Int, CaseIterable, Identifiable, Sendable {
    case green, blue, violet, amber, rose

    var id: Int { rawValue }

    static let defaultPattern = Tint.green
    static let defaultWave = Tint.blue

    static let defaultAvatar = Tint.green

    var title: String {
        switch self {
        case .green: Lang.text("Зелёный")
        case .blue: Lang.text("Синий")
        case .violet: Lang.text("Сиреневый")
        case .amber: Lang.text("Медовый")
        case .rose: Lang.text("Розовый")
        }
    }

    /// Зелёный — из макета, #CFF8C9. Остальные посчитаны так, чтобы светлота
    /// сошлась с ним (0.925 по sRGB): иначе смена цвета меняла бы и
    /// заметность узора. Проверяется прогоном модели.
    var pale: Channels {
        switch self {
        case .green: Channels(207, 248, 201)
        case .blue: Channels(222, 238, 255)
        case .violet: Channels(240, 233, 254)
        case .amber: Channels(255, 233, 208)
        case .rose: Channels(255, 230, 236)
        }
    }

    /// Насыщенность от девяти десятых: помягче — и гребень волны читался
    /// подцветкой, а не вспышкой.
    var vivid: Channels {
        switch self {
        case .green: Channels(10, 199, 51)
        case .blue: Channels(0, 122, 255)
        case .violet: Channels(97, 24, 242)
        case .amber: Channels(255, 136, 0)
        case .rose: Channels(255, 13, 73)
        }
    }
}

struct Channels: Hashable, Codable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    static func mix(_ from: Channels, _ to: Channels, _ k: Double) -> Channels {
        let part = min(max(k, 0), 1)
        return Channels(from.red + (to.red - from.red) * part,
                        from.green + (to.green - from.green) * part,
                        from.blue + (to.blue - from.blue) * part)
    }
}

/// Оттенок каналами, готовый к рисованию: во время смены цвета на экране
/// смесь двух оттенков, у которой нет номера. Ипостаси смешиваются каждая со
/// своей — иначе середина перехода уходила бы в серый.
struct Shade: Equatable, Sendable {
    var pale: Channels
    var vivid: Channels

    init(_ tint: Tint) {
        pale = tint.pale
        vivid = tint.vivid
    }

    init(pale: Channels, vivid: Channels) {
        self.pale = pale
        self.vivid = vivid
    }

    static func mix(_ from: Shade, _ to: Shade, _ k: Double) -> Shade {
        Shade(pale: .mix(from.pale, to.pale, k),
              vivid: .mix(from.vivid, to.vivid, k))
    }
}
