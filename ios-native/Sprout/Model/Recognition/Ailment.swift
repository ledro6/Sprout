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

    /// Советы на языке приложения — строками на карточке находки.
    var tips: [String] { advice.map { Lang.text($0.key) } }

    /// Советы находки и то, как каждый ложится в план лечения: разовый —
    /// сразу, повторяющийся — раз в `every` дней сада. Срок повтора — из
    /// самого совета («раз в пару недель») или из сроков вида; придумывать
    /// свои нельзя.
    var advice: [Advice] {
        switch kind {
        case .unclear, .healthy: []
        case .overwatered: [
            Advice(key: Lang.key("Поливайте, только когда карточка засветится оранжевым."),
                   icon: "drop.fill"),
            Advice(key: Lang.key("Проверьте, есть ли в горшке дырка и не стоит ли вода в поддоне."),
                   icon: "cylinder.split.1x2"),
        ]
        case .underwatered: [
            Advice(key: Lang.key("Включите напоминания о поливе или сократите срок в настройках растения."),
                   icon: "bell.fill"),
            Advice(key: Lang.key("Пересохший ком земли поливайте погружением: горшок — в таз с водой на полчаса."),
                   icon: "drop.fill"),
        ]
        case .hungry: [
            Advice(key: Lang.key("Подкормите растение и отметьте это на его экране."),
                   icon: "sparkles"),
        ]
        case .yellowing: [
            Advice(key: Lang.key("Уберите пожелтевшие листья целиком."),
                   icon: "scissors"),
            Advice(key: Lang.key("Сравните с историей полива: земля не пересыхала и не стояла мокрой?"),
                   icon: "chart.bar.fill"),
        ]
        case .crispy: [
            Advice(key: Lang.key("Опрыскивайте листья или поставьте рядом воду — воздух станет влажнее."),
                   icon: Duty.mist.icon, every: .mist),
            Advice(key: Lang.key("Уберите горшок от батареи."),
                   icon: "heater.vertical.fill"),
        ]
        case .spots: [
            Advice(key: Lang.key("Уберите пятнистые листья и не лейте воду на листья."),
                   icon: "scissors"),
            Advice(key: Lang.key("Уберите растение от прямого полуденного солнца."),
                   icon: "sun.max.fill"),
        ]
        case .powder: [
            Advice(key: Lang.key("Посмотрите на изнанку листьев: нет ли там ватных комочков или паутинки."),
                   icon: "magnifyingglass"),
            Advice(key: Lang.key("Протрите листья мягкой губкой с тёплой водой."),
                   icon: Duty.wipe.icon),
        ]
        case .pale: [
            Advice(key: Lang.key("Переставьте ближе к окну, но не под прямое солнце."),
                   icon: "sun.min.fill"),
            Advice(key: Lang.key("Поворачивайте горшок раз в пару недель, чтобы свет доставался всем листьям."),
                   icon: Duty.turn.icon, every: .days(14)),
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

/// Совет находки: ключ каталога строк, знак и повтор.
struct Advice: Hashable, Sendable {
    /// Как часто повторять: срок, названный в самом совете, или срок
    /// опрыскивания — своего растения или его вида.
    enum Repeat: Hashable, Sendable {
        case days(Double)
        case mist
    }

    var key: String
    var icon: String
    /// Пусто — сделать один раз, сразу.
    var every: Repeat? = nil
}

extension Treatment {
    /// Сколько дней сада идёт лечение: через две недели — снова снимок.
    static let span = 14.0

    /// Совет повторяют не чаще, чем укладывается в лечение, и не больше
    /// пяти раз: напоминание каждый день — уже шум.
    static let most = 5

    /// Опрыскивание у вида, который обычно не опрыскивают, — раз в
    /// неделю: самый редкий срок среди тех, кого опрыскивают (`Duty.mist`).
    static let rareMist = 7.0

    /// План по находкам: шаги — советы находок по порядку, повторяющиеся —
    /// по сроку, последним — снова снимок в «Что с ним?». Нет советов
    /// (здоров или не разглядеть) — плана нет.
    static func plan(_ findings: [Finding], plant: Plant, now: Date = Date(),
                     speed: Double = Garden.speed) -> Treatment? {
        var steps: [Step] = []
        var kinds: [String] = []
        var seen = Set<String>()
        var last = 0.0
        for finding in findings {
            let advice = finding.advice.filter { seen.insert($0.key).inserted }
            guard !advice.isEmpty else { continue }
            kinds.append(finding.kind.rawValue)
            for (index, tip) in advice.enumerated() {
                let every = tip.every.map { period($0, plant: plant) }
                let rounds = every.map {
                    min(Int((span / $0).rounded(.down)) + 1, most)
                } ?? 1
                for round in 1 ... rounds {
                    let day = Double(round - 1) * (every ?? 0)
                    last = max(last, day)
                    steps.append(Step(
                        id: "\(finding.kind.rawValue)-\(index)-\(round)",
                        advice: tip.key, icon: tip.icon, round: round,
                        rounds: rounds,
                        due: now.addingTimeInterval(seconds(days: day,
                                                            speed: speed))))
                }
            }
        }
        guard !steps.isEmpty else { return nil }
        steps.append(Step(
            id: "check",
            advice: Lang.key("Снимите растение снова в «Что с ним?» и сравните с тем, что было."),
            icon: "camera.viewfinder",
            due: now.addingTimeInterval(seconds(days: max(span, last),
                                                speed: speed))))
        // По сроку; в один день — по порядку советов.
        let order = Dictionary(uniqueKeysWithValues:
            steps.enumerated().map { ($0.element.id, $0.offset) })
        steps.sort {
            $0.due != $1.due ? $0.due < $1.due
                : order[$0.id, default: 0] < order[$1.id, default: 0]
        }
        return Treatment(kinds: kinds, started: now, steps: steps)
    }

    /// Срок повтора в днях сада.
    static func period(_ every: Advice.Repeat, plant: Plant) -> Double {
        switch every {
        case .days(let days): days
        case .mist:
            plant.tending.every(.mist)
                ?? Duty.mist.usual(for: plant.blueprint.preset) ?? rareMist
        }
    }
}
