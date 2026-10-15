import Foundation

/// Цвет числами: каналы 0…255, прозрачность 0…1. Без SwiftUI — чтобы
/// контраст считался в проверке модели, на Linux, без Mac.
struct Paint: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// `0x0071E3` → цвет.
    init(hex: Int, alpha: Double = 1) {
        self.init(Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF),
                  Double(hex & 0xFF), alpha)
    }

    /// Положить на непрозрачную подложку — получается то, что видит глаз.
    func over(_ ground: Paint) -> Paint {
        let mix = { (top: Double, low: Double) in top * alpha + low * (1 - alpha) }
        return Paint(mix(red, ground.red), mix(green, ground.green),
                     mix(blue, ground.blue))
    }

    /// Относительная яркость по WCAG 2.1.
    var luminance: Double {
        func linear(_ channel: Double) -> Double {
            let c = channel / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green)
            + 0.0722 * linear(blue)
    }

    /// Контраст по WCAG 2.1: от 1 до 21. Полупрозрачный цвет сперва ложится
    /// на подложку.
    func contrast(on ground: Paint) -> Double {
        let a = over(ground).luminance
        let b = ground.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Цвета, которые несут смысл, — числами для обеих тем. `Palette` в
/// приложении, виджет и часы берут их отсюда, а проверка модели меряет
/// контраст каждого на его подложках: текст — от 4.5, значки и рамки
/// элементов — от 3 (WCAG 2.1, 1.4.3 и 1.4.11).
enum Legible {
    /// Пара: светлая тема и тёмная.
    struct Pair: Equatable, Sendable {
        let light: Paint
        let dark: Paint
    }

    /// Что цвет делает, — от этого его порог.
    enum Role: Sendable {
        /// Текст и ссылки: от 4.5 на фоне и карточке.
        case text
        /// Значки, точки легенды, полосы графиков, рамки полей: от 3.
        case glyph
        /// Заливка кнопки с белой надписью: белое на ней — от 4.5.
        case fill
        /// Украшение — ничего не сообщает, порога нет.
        case decor
    }

    // MARK: Подложки

    static let background = Pair(light: Paint(hex: 0xFFFFFF),
                                 dark: Paint(hex: 0x2B2E2C))

    /// Карточка с данными — непрозрачная: узор под ней не проступает, и
    /// контраст текста не зависит от того, какая фигурка легла под строку.
    static let card = Pair(light: Paint(hex: 0xFFFFFF),
                           dark: Paint(hex: 0x353937))

    // MARK: Текст

    static let primary = Pair(light: Paint(hex: 0x000000),
                              dark: Paint(hex: 0xEEF1ED))

    /// Вторичный текст с данными. Системный `.secondary` — 60% и на белом
    /// даёт 3.5: мало для подписи, которую читают.
    static let secondary = Pair(light: Paint(60, 60, 67, 0.75),
                                dark: Paint(235, 235, 245, 0.7))

    /// Только украшение — никогда не данные.
    static let decorative = Pair(light: Paint(60, 60, 67, 0.3),
                                 dark: Paint(235, 235, 245, 0.3))

    /// Синий текста и значков-ссылок.
    static let accentText = Pair(light: Paint(hex: 0x0062CC),
                                 dark: Paint(hex: 0x5EB1FF))

    /// Синяя заливка кнопок с белой надписью.
    static let accentFill = Pair(light: Paint(hex: 0x0071E3),
                                 dark: Paint(hex: 0x0A6FD8))

    /// Прежний системный синий макета — только украшение без текста:
    /// подсветка подсказки, свечение.
    static let accentGlow = Pair(light: Paint(hex: 0x0088FF),
                                 dark: Paint(hex: 0x4AA8FF))

    // MARK: Состояния

    static let ok = Pair(light: Paint(hex: 0x237A35),
                         dark: Paint(hex: 0x4CC864))

    /// Зелёная заливка кнопки — с белой надписью в обеих темах.
    static let okFill = Pair(light: Paint(hex: 0x237A35),
                             dark: Paint(hex: 0x237A35))

    static let soon = Pair(light: Paint(hex: 0xB35C00),
                           dark: Paint(hex: 0xFFA92E))

    static let urgent = Pair(light: Paint(hex: 0xD32F27),
                             dark: Paint(hex: 0xFF7A70))

    /// Земля досуха — темнее тревоги, рядом с ней всегда значок: цветом
    /// одним их не различить.
    static let parched = Pair(light: Paint(hex: 0x96201A),
                              dark: Paint(hex: 0xE05A50))

    static let wet = Pair(light: Paint(hex: 0x16789F),
                          dark: Paint(hex: 0x5BC2EC))

    // MARK: Линии

    static let hairline = Pair(light: Paint(hex: 0xC6C6C8),
                               dark: Paint(hex: 0x48484A))

    static let controlBorder = Pair(light: Paint(hex: 0x8E8E93),
                                    dark: Paint(hex: 0x8E8E93))

    // MARK: Украшения прежних цветов макета

    /// Тревожная тень, узор, заливки под графиком — яркие исходные цвета.
    /// Текста на них нет и смысла они одни не несут.
    static let leafGlow = Pair(light: Paint(hex: 0x37B551),
                               dark: Paint(hex: 0x37B551))
    static let warnGlow = Pair(light: Paint(hex: 0xFF9500),
                               dark: Paint(hex: 0xFFA92E))
    static let alarmGlow = Pair(light: Paint(hex: 0xFF3B30),
                                dark: Paint(hex: 0xFF5C52))
    static let waterGlow = Pair(light: Paint(hex: 0x47B5E4),
                                dark: Paint(hex: 0x47B5E4))

    // MARK: Живые действия

    /// Подложка живых действий — тёмная в обеих темах; на ней свой набор.
    static let night = Paint(hex: 0x0A211C)
    static let nightTrip = Paint(hex: 0x0F1433)
    static let nightDim = Paint(255, 255, 255, 0.7)
    static let nightSky = Paint(hex: 0x8CB8FF)
    static let nightSun = Paint(hex: 0xFFCC52)
    static let nightDone = Paint(hex: 0x6BDB80)
    /// Вода на тёмной подложке — та же, что в тёмной теме.
    static let nightWater = wet.dark

    // MARK: Проверка

    /// Всё, что меряет проверка: имя, пара и роль.
    static let all: [(name: String, pair: Pair, role: Role)] = [
        ("label.primary", primary, .text),
        ("label.secondary", secondary, .text),
        ("label.decorative", decorative, .decor),
        ("accent.text", accentText, .text),
        ("accent.fill", accentFill, .fill),
        ("accent.glow", accentGlow, .decor),
        ("status.ok", ok, .text),
        ("status.okFill", okFill, .fill),
        ("status.soon", soon, .text),
        ("status.urgent", urgent, .text),
        ("status.parched", parched, .glyph),
        ("status.wet", wet, .text),
        ("separator.hairline", hairline, .decor),
        ("border.control", controlBorder, .glyph),
        ("glow.leaf", leafGlow, .decor),
        ("glow.warn", warnGlow, .decor),
        ("glow.alarm", alarmGlow, .decor),
        ("glow.water", waterGlow, .decor),
    ]

    /// Живые действия: всё на тёмной подложке, текстом.
    static let nightInks: [(name: String, paint: Paint)] = [
        ("night.dim", nightDim), ("night.sky", nightSky),
        ("night.sun", nightSun), ("night.done", nightDone),
        ("night.water", nightWater),
    ]

    /// Порог роли; у украшения — нет.
    static func floor(_ role: Role) -> Double? {
        switch role {
        case .text, .fill: return 4.5
        case .glyph: return 3
        case .decor: return nil
        }
    }

    /// Худший контраст цвета на его подложках в одной теме. Заливку мерят
    /// с белой надписью на ней.
    static func worst(_ pair: Pair, _ role: Role, dark: Bool) -> Double {
        let paint = dark ? pair.dark : pair.light
        if role == .fill {
            return Paint(hex: 0xFFFFFF).contrast(on: paint.over(
                dark ? background.dark : background.light))
        }
        let grounds = dark ? [background.dark, card.dark]
            : [background.light, card.light]
        return grounds.map { paint.contrast(on: $0) }.min() ?? 1
    }
}
