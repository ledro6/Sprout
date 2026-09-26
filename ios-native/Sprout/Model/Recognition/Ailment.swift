import Foundation

/// Что видно на листьях: доли пикселей растения по цвету. Считается по
/// верхним двум третям растения — внизу горшок и земля, а терракотовый
/// горшок иначе сошёл бы за сухие листья. Маску растения даёт Vision, см.
/// `Eye.examine`; здесь только арифметика — её проверяет прогон модели.
struct Symptoms: Equatable, Sendable {
    var green = 0.0
    var yellow = 0.0
    var brown = 0.0
    var dark = 0.0
    var white = 0.0
    var pale = 0.0
    /// Сколько пикселей растения посчитано: мало — судить не по чему.
    var covered = 0

    /// Меньше — растения на снимке почти нет.
    static let enough = 400

    static func read(rgba: [UInt8], mask: [UInt8]?, width: Int,
                     height: Int) -> Symptoms {
        guard width > 0, height > 0, rgba.count >= width * height * 4 else {
            return Symptoms()
        }
        func inside(_ x: Int, _ y: Int) -> Bool {
            if let mask { return mask[y * width + x] > 127 }
            // Без маски — середина кадра: там растение чаще всего.
            let dx = Double(x) / Double(width) - 0.5
            let dy = Double(y) / Double(height) - 0.5
            return dx * dx + dy * dy < 0.09
        }
        // Рамка растения — чтобы отрезать горшок снизу.
        var top = height, bottom = -1
        for y in 0 ..< height {
            for x in 0 ..< width where inside(x, y) {
                top = min(top, y)
                bottom = max(bottom, y)
                break
            }
        }
        guard bottom >= top else { return Symptoms() }
        let cut = top + Int(Double(bottom - top + 1) * 0.66)
        var counts = [Double](repeating: 0, count: 6)
        var total = 0
        for y in top ... min(cut, height - 1) {
            for x in 0 ..< width where inside(x, y) {
                let at = (y * width + x) * 4
                let (h, s, v) = hsv(rgba[at], rgba[at + 1], rgba[at + 2])
                total += 1
                if v < 0.16 {
                    counts[3] += 1
                } else if s < 0.12 && v > 0.85 {
                    counts[4] += 1
                } else if h >= 70 && h < 170 && s >= 0.25 {
                    counts[0] += 1
                } else if h >= 60 && h < 170 && v > 0.55 {
                    counts[5] += 1
                } else if h >= 40 && h < 70 && s > 0.3 && v > 0.35 {
                    counts[1] += 1
                } else if (h < 40 || h >= 345) && s > 0.25 && v < 0.65 {
                    counts[2] += 1
                }
            }
        }
        guard total > 0 else { return Symptoms() }
        let share = counts.map { $0 / Double(total) }
        return Symptoms(green: share[0], yellow: share[1], brown: share[2],
                        dark: share[3], white: share[4], pale: share[5],
                        covered: total)
    }

    /// Тон в градусах, насыщенность и яркость — 0…1.
    static func hsv(_ r: UInt8, _ g: UInt8, _ b: UInt8)
        -> (Double, Double, Double) {
        let red = Double(r) / 255, green = Double(g) / 255,
            blue = Double(b) / 255
        let high = max(red, green, blue), low = min(red, green, blue)
        let span = high - low
        var hue = 0.0
        if span > 0 {
            switch high {
            case red: hue = 60 * ((green - blue) / span)
            case green: hue = 60 * ((blue - red) / span + 2)
            default: hue = 60 * ((red - green) / span + 4)
            }
        }
        if hue < 0 { hue += 360 }
        return (hue, high > 0 ? span / high : 0, high)
    }
}

/// Что может быть не так — по снимку, истории поливов и уходу. Не диагноз
/// ботаника, а подсказка: что проверить и что сделать.
struct Finding: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case unclear, healthy, overwatered, underwatered, hungry, yellowing,
             crispy, spots, powder, pale
    }

    var kind: Kind
    /// 0…1 — насколько уверенно.
    var confidence: Double

    var id: String { kind.rawValue }

    var title: String {
        switch kind {
        case .unclear: Lang.text("Растение плохо видно")
        case .healthy: Lang.text("Выглядит здоровым")
        case .overwatered: Lang.text("Похоже на перелив")
        case .underwatered: Lang.text("Похоже на недолив")
        case .hungry: Lang.text("Похоже, голодает")
        case .yellowing: Lang.text("Листья желтеют")
        case .crispy: Lang.text("Сухие бурые края")
        case .spots: Lang.text("Тёмные пятна")
        case .powder: Lang.text("Белый налёт")
        case .pale: Lang.text("Бледные листья")
        }
    }

    var icon: String {
        switch kind {
        case .unclear: "camera.viewfinder"
        case .healthy: "checkmark.seal.fill"
        case .overwatered: "drop.triangle.fill"
        case .underwatered: "sun.dust.fill"
        case .hungry: "sparkles"
        case .yellowing: "leaf.fill"
        case .crispy: "flame.fill"
        case .spots: "circle.dotted"
        case .powder: "aqi.medium"
        case .pale: "sun.min.fill"
        }
    }

    var detail: String {
        switch kind {
        case .unclear:
            Lang.text("Снимите растение целиком, при дневном свете, чтобы оно заняло большую часть кадра.")
        case .healthy:
            Lang.text("Листья зелёные, тревожных пятен не видно. Так держать.")
        case .overwatered:
            Lang.text("Листья желтеют, а поливаете вы, когда в земле ещё много воды. Корням не хватает воздуха.")
        case .underwatered:
            Lang.text("Листья желтеют, а земля не раз пересыхала до дна.")
        case .hungry:
            Lang.text("Листья желтеют, а подкормка давно просрочена.")
        case .yellowing:
            Lang.text("Желтеет заметная часть листьев. Нижние старые листья желтеют сами — это не страшно; если молодые — что-то не так.")
        case .crispy:
            Lang.text("Края и кончики листьев бурые и сухие — обычно от сухого воздуха или пересыхания земли.")
        case .spots:
            Lang.text("На листьях тёмные пятна: грибок от сырости, ожог солнцем — или просто тень на снимке.")
        case .powder:
            Lang.text("На листьях светлые пятна: мучнистая роса или вредители — или блик и белые цветки.")
        case .pale:
            Lang.text("Листья выцветшие, зелени мало — растению, похоже, не хватает света.")
        }
    }

    var tips: [String] {
        switch kind {
        case .unclear, .healthy: []
        case .overwatered: [
            Lang.text("Поливайте, только когда карточка засветится оранжевым."),
            Lang.text("Проверьте, есть ли в горшке дырка и не стоит ли вода в поддоне."),
        ]
        case .underwatered: [
            Lang.text("Включите напоминания о поливе или сократите срок в настройках растения."),
            Lang.text("Пересохший ком земли поливайте погружением: горшок — в таз с водой на полчаса."),
        ]
        case .hungry: [
            Lang.text("Подкормите растение и отметьте это на его экране."),
        ]
        case .yellowing: [
            Lang.text("Уберите пожелтевшие листья целиком."),
            Lang.text("Сравните с историей полива: земля не пересыхала и не стояла мокрой?"),
        ]
        case .crispy: [
            Lang.text("Опрыскивайте листья или поставьте рядом воду — воздух станет влажнее."),
            Lang.text("Уберите горшок от батареи."),
        ]
        case .spots: [
            Lang.text("Уберите пятнистые листья и не лейте воду на листья."),
            Lang.text("Уберите растение от прямого полуденного солнца."),
        ]
        case .powder: [
            Lang.text("Посмотрите на изнанку листьев: нет ли там ватных комочков или паутинки."),
            Lang.text("Протрите листья мягкой губкой с тёплой водой."),
        ]
        case .pale: [
            Lang.text("Переставьте ближе к окну, но не под прямое солнце."),
            Lang.text("Поворачивайте горшок раз в пару недель, чтобы свет доставался всем листьям."),
        ]
        }
    }

    /// Снимок, история и уход — в находки, от самой уверенной.
    static func diagnose(_ seen: Symptoms, plant: Plant, log: [Watering],
                         climate: Climate? = nil) -> [Finding] {
        guard seen.covered >= Symptoms.enough else {
            return [Finding(kind: .unclear, confidence: 1)]
        }
        let pours = log.filter { $0.plant == plant.id }
            .sorted { $0.when > $1.when }
            .prefix(8)
            .compactMap(\.left)
        let early = pours.isEmpty ? 0
            : Double(pours.count { $0 >= Thirst.warnBelow }) / Double(pours.count)
        let dried = pours.isEmpty ? 0
            : Double(pours.count { $0 < 0.05 }) / Double(pours.count)
        let tending = plant.tending
        let starving = tending.feedEvery.map { tending.sinceFed > $0 * 1.5 }
            ?? false
        let preset = plant.blueprint.preset
        // У цветущих белое — чаще цветки, чем налёт.
        let blooms: Set<Preset> = [.spathiphyllum, .orchid, .lily,
                                   .chrysanthemum, .rose, .tulip, .begonia,
                                   .violet, .pelargonium, .anthurium, .hoya]
        var out: [Finding] = []
        func add(_ kind: Kind, _ confidence: Double) {
            out.append(Finding(kind: kind,
                               confidence: min(max(confidence, 0.2), 0.95)))
        }
        if seen.yellow >= 0.12 {
            let base = 0.35 + seen.yellow
            if early >= 0.5 || (plant.moisture > 0.8 && early >= 0.3) {
                add(.overwatered, base + early * 0.3)
            } else if dried >= 0.3 {
                add(.underwatered, base + dried * 0.3)
            } else if starving {
                add(.hungry, base + 0.1)
            } else {
                add(.yellowing, base)
            }
        }
        if seen.brown >= 0.1 {
            let dryAir = (climate?.humidity).map { $0 < 0.35 } ?? false
            let wantsMist = Duty.mist.usual(for: preset) != nil
            add(.crispy, 0.35 + seen.brown + (dryAir ? 0.15 : 0)
                + (wantsMist ? 0.1 : 0) + dried * 0.2)
        }
        if seen.dark >= 0.15 {
            add(.spots, 0.25 + seen.dark)
        }
        if seen.white >= (blooms.contains(preset) ? 0.2 : 0.08) {
            add(.powder, 0.3 + seen.white)
        }
        if seen.pale >= 0.25 && seen.green < 0.35 {
            add(.pale, 0.35 + seen.pale - seen.green * 0.5)
        }
        if out.isEmpty {
            add(.healthy, 0.4 + seen.green)
        }
        return out.sorted { $0.confidence > $1.confidence }
    }
}
