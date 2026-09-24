import Foundation

/// Что умеет телефон — чтобы новые iPhone показывали сад в полную силу, а
/// старые не грелись. Факты снимает приложение (Metal, ARKit, память,
/// нагрев), решения — здесь, чтобы их можно было проверить без телефона.
struct Rig: Equatable, Sendable {
    struct Hardware: Equatable, Sendable {
        /// Семейство графики Apple: 7 — A14, 8 — A15 и A16, 9 — A17 Pro и
        /// новее (A18, A19). Старше — меньше.
        var gpu: Int
        /// Память, ГБ.
        var memory: Double
        var lidar: Bool
        /// Перегрев или энергосбережение — нагрузку на время снижаем.
        var strained = false
    }

    enum Tier: Int, Comparable, Sendable {
        case lite
        case standard
        case pro

        static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }

        var lower: Tier { Tier(rawValue: max(rawValue - 1, 0)) ?? .lite }
    }

    /// Детализация модели — от неё зависит файл модели, поэтому она часть
    /// ключа кэша и не меняется от нагрева.
    struct Detail: Equatable, Hashable, Sendable {
        /// Во сколько раз чётче рисунки листьев и лепестков.
        var texture: Float
        /// Во сколько раз гуще сетки листьев и лепестков.
        var mesh: Float

        static let standard = Detail(texture: 1, mesh: 1)

        var key: String { "t\(Int(texture * 100))m\(Int(mesh * 100))" }
    }

    var tier: Tier
    var detail: Detail
    /// Сколько растений сад в AR ставит разом.
    var plants: Int
    /// Сколько капель лейки в полёте.
    var drops: Int
    /// Сетка комнаты от LiDAR: растения прячутся за мебелью, тени ложатся на
    /// неё, капли разбиваются о стол.
    var room: Bool
    /// Камера в 4K и HDR и отражения комнаты в HDR — там, где телефон их
    /// даёт.
    var hdr: Bool
    /// Размытие движения, глубина резкости и зерно камеры — красиво, но
    /// дорого.
    var effects: Bool

    /// A17 Pro и новее с восемью гигабайтами — полная сила: iPhone 15 Pro,
    /// 16, 17 и Air. A15 и A16 — обычная. Старше — бережная. Память —
    /// с запасом вниз: восемь гигабайт телефон называет семью с половиной.
    static func tier(of hardware: Hardware) -> Tier {
        if hardware.gpu >= 9 && hardware.memory >= 7 { return .pro }
        if hardware.gpu >= 8 || hardware.memory >= 5 { return .standard }
        return .lite
    }

    /// Детализация — по телефону, без поправки на нагрев: иначе горячий
    /// телефон пересобирал бы модели.
    static func detail(of hardware: Hardware) -> Detail {
        switch tier(of: hardware) {
        case .lite: Detail(texture: 0.5, mesh: 0.75)
        case .standard: .standard
        case .pro: Detail(texture: 1.5, mesh: 1.4)
        }
    }

    static func of(_ hardware: Hardware) -> Rig {
        let full = tier(of: hardware)
        let tier = hardware.strained ? full.lower : full
        let detail = detail(of: hardware)
        switch tier {
        case .lite:
            return Rig(tier: tier, detail: detail, plants: 4, drops: 120,
                       room: hardware.lidar && !hardware.strained, hdr: false,
                       effects: false)
        case .standard:
            return Rig(tier: tier, detail: detail, plants: 8, drops: 220,
                       room: hardware.lidar, hdr: true, effects: false)
        case .pro:
            return Rig(tier: tier, detail: detail, plants: 12, drops: 400,
                       room: hardware.lidar, hdr: true, effects: true)
        }
    }
}

/// Раскладка сада в AR: ряды поперёк взгляда, высокие — дальше, чтобы не
/// заслоняли низких; в ряду — от середины к краям. Координаты — на полу в
/// метрах: x — вправо от взгляда, z — вглубь.
enum Plot {
    /// Зазор между горшками.
    static let gap: Float = 0.06

    static func layout(spreads: [Float], heights: [Float],
                       perRow: Int = 4) -> [SIMD2<Float>] {
        let count = min(spreads.count, heights.count)
        guard count > 0 else { return [] }
        // Низкие — ближе: порядок по высоте, при равной — как в саду.
        let order = (0 ..< count).sorted {
            heights[$0] != heights[$1] ? heights[$0] < heights[$1] : $0 < $1
        }
        var spots = [SIMD2<Float>](repeating: .zero, count: count)
        var depth: Float = 0
        var start = 0
        while start < count {
            let row = Array(order[start ..< min(start + perRow, count)])
            let widths = row.map { max(spreads[$0], 0.08) * 2 + gap }
            let deep = widths.max() ?? 0
            // От середины к краям: первый в середину, дальше по очереди
            // справа и слева.
            var arranged = [Int]()
            for (index, plant) in row.enumerated() {
                if index % 2 == 0 { arranged.append(plant) }
                else { arranged.insert(plant, at: 0) }
            }
            let total = arranged.reduce(Float(0)) {
                $0 + max(spreads[$1], 0.08) * 2 + gap
            }
            var x = -total / 2
            for plant in arranged {
                let width = max(spreads[plant], 0.08) * 2 + gap
                spots[plant] = SIMD2(x + width / 2, depth + deep / 2)
                x += width
            }
            depth += deep
            start += perRow
        }
        return spots
    }
}
