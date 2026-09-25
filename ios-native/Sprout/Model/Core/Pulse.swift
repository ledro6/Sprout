import Foundation

/// Точка огибающей: доля времени (не секунды) и сила, обе 0…1.
struct Moment: Sendable, Equatable {
    var at: Double
    var strength: Double

    init(_ at: Double, _ strength: Double) {
        self.at = at
        self.strength = strength
    }
}

struct Tap: Sendable, Equatable {
    var at: Double
    var strength: Double
    var edge: Double
}

/// Рисунок отклика Taptic Engine — форма без времени и без движка.
///
/// Из тычков, а не из ровного гула: волна идёт рядами фигурок, и тычок на ряд
/// это передаёт; гул — подложкой. Длительность задаёт тот, кто играет, — она
/// живёт рядом с анимацией. Числа проверяются прогоном: движок молча
/// отвергает значения вне 0…1 и огибающую, идущую вспять.
struct Pulse: Sendable, Equatable {
    /// Тычков в секунду: 12–18 — ряды узора, чаще — жужжание, реже — рука
    /// отстаёт от экрана.
    var rate: Double

    var edge: Double = 0.6

    /// Гул под тычками, доля от их силы.
    var hum: Double = 0

    /// Удар в начале: сила и резкость; ноль — удара нет.
    var strike: Double = 0
    var strikeEdge: Double = 0.5

    var finish: Double = 0
    var finishEdge: Double = 0.5

    var envelope: [Moment]

    /// Тише движок всё равно не покажет.
    static let faintest = 0.06

    func taps(over seconds: Double) -> [Tap] {
        guard rate > 0, seconds > 0 else { return [] }
        let step = 1 / rate
        var out: [Tap] = []
        var time = 0.0
        while time <= seconds + 1e-9 {
            let force = strength(at: time / seconds)
            if force >= Self.faintest {
                out.append(Tap(at: time, strength: min(force, 1), edge: edge))
            }
            time += step
        }
        return out
    }

    func strength(at moment: Double) -> Double {
        let time = min(max(moment, 0), 1)
        guard let last = envelope.last else { return 0 }
        guard let next = envelope.firstIndex(where: { $0.at >= time })
        else { return last.strength }
        guard next > 0 else { return envelope[0].strength }
        let before = envelope[next - 1], after = envelope[next]
        let span = after.at - before.at
        guard span > 0 else { return after.strength }
        let part = (time - before.at) / span
        return before.strength + (after.strength - before.strength) * part
    }

    /// Движок требует: значения в 0…1, огибающая начинается в нуле, кончается
    /// в единице и идёт только вперёд.
    var valid: Bool {
        let fits = { (value: Double) in value >= 0 && value <= 1 }
        guard fits(strike), fits(strikeEdge), fits(finish), fits(finishEdge),
              fits(edge), fits(hum), rate > 0, rate <= 40
        else { return false }
        guard envelope.count >= 2,
              envelope.first?.at == 0, envelope.last?.at == 1
        else { return false }
        for (index, point) in envelope.enumerated() {
            guard fits(point.at), fits(point.strength) else { return false }
            guard index == 0 || point.at > envelope[index - 1].at
            else { return false }
        }
        return true
    }

    /// Сила с ползунка настроек, 0…1. Слабые тычки подтягиваются сильнее
    /// сильных: на полной силе рука слышит всю дробь, а не одни удары, и
    /// каждый тычок не слабее, чем задуман.
    static func scaled(_ force: Double, by strength: Double) -> Double {
        let level = min(max(strength, 0), 1)
        let base = min(max(force, 0), 1)
        guard level > 0, base > 0 else { return 0 }
        return min(pow(base, lift) * boost * level, 1)
    }

    static let lift = 0.65
    static let boost = 1.25

    // MARK: - Рисунки

    /// Всходы: редкие слабые тычки набирают частоту и садятся хлопком, когда
    /// встала последняя фигурка. Без удара — всходы ничем не вызваны.
    static let sprout = Pulse(
        rate: 15, edge: 0.3,
        finish: 0.45, finishEdge: 0.25,
        envelope: [
            Moment(0, 0.08), Moment(0.25, 0.3), Moment(0.55, 0.58),
            Moment(0.85, 0.42), Moment(1, 0.16),
        ])

    /// Новое растение: нарастает из ничего и лопается хлопком.
    static let bloom = Pulse(
        rate: 18, edge: 0.55, finish: 1, finishEdge: 0.85,
        envelope: [
            Moment(0, 0.08), Moment(0.45, 0.35), Moment(0.8, 0.7),
            Moment(1, 0.9),
        ])

    /// Кутерьма: бугор на каждый такт. Считается из самой кутерьмы, чтобы
    /// бугры не разошлись с экраном.
    static var frenzy: Pulse {
        let slots = Double(Frolic.beats + 1)
        var points: [Moment] = []
        for beat in 0 ..< Frolic.beats {
            let from = Double(beat) / slots
            let peak = 0.34 + 0.52 * Double(beat) / Double(Frolic.beats - 1)
            points.append(Moment(from, peak * 0.35))
            points.append(Moment(from + 0.4 / slots, peak))
        }
        points.append(Moment(1, 0))
        return Pulse(rate: 12, edge: 0.75, hum: 0.2, strike: 0.55,
                     strikeEdge: 0.9, finish: 0.7, finishEdge: 0.3,
                     envelope: points)
    }

    static var all: [(name: String, pulse: Pulse)] {
        [("всходы", sprout), ("посадка", bloom), ("кутерьма", frenzy)]
    }
}

/// Полив в руке — капли, как всходы при запуске, только живее: удар и россыпь
/// тычков, каждый раз новая. Промежутки, сила и резкость у каждой капли свои,
/// изредка капля двоится или пропадает; общая сила угасает вместе с волной.
/// Одинаковый рисунок на каждый полив рука выучила бы на третий раз. Без
/// гула: он размазывал капли в жужжание.
enum Rain {
    /// Ближе тычки сливаются в один.
    static let closest = 0.028

    static func drops(over seconds: Double, seed: UInt64) -> [Tap] {
        guard seconds > 0 else { return [] }
        var dice = Seeded(number: seed)
        func roll(_ range: ClosedRange<Double>) -> Double {
            Double.random(in: range, using: &dice)
        }
        var out = [Tap(at: 0, strength: roll(0.85 ... 1),
                       edge: roll(0.55 ... 0.8))]
        var time = roll(0.05 ... 0.09)
        while time <= seconds {
            let part = time / seconds
            // Вначале почти в полную силу, к концу волны — шёпот.
            let fade = pow(1 - part, 1.3)
            let force = fade * roll(0.55 ... 1.15)
            if force >= Pulse.faintest, roll(0 ... 1) > 0.08 {
                out.append(Tap(at: time, strength: min(force, 1),
                               edge: roll(0.2 ... 0.95)))
                // Изредка «кап-кап»: вторая капля следом, слабее.
                let echo = force * roll(0.45 ... 0.75)
                let later = time + roll(0.03 ... 0.045)
                if roll(0 ... 1) < 0.18, echo >= Pulse.faintest,
                   later <= seconds {
                    out.append(Tap(at: later, strength: min(echo, 1),
                                   edge: roll(0.3 ... 0.9)))
                }
            }
            // Капли редеют: волна расходится, рядов в секунду всё меньше.
            let gap = (0.055 + 0.13 * part) * roll(0.6 ... 1.5)
            time = max(time + gap, (out.last?.at ?? time) + closest)
        }
        return out
    }
}

/// Короткие отклики — несколько тычков, как системные «успех» и «ошибка», но
/// послушные ползунку силы: системные его не слушают.
enum Knock {
    /// Выбор из нескольких — щелчок барабана.
    static let pick = [Tap(at: 0, strength: 0.55, edge: 0.8)]

    /// Сохранено: слабый и сильный.
    static let done = [Tap(at: 0, strength: 0.6, edge: 0.45),
                       Tap(at: 0.1, strength: 1, edge: 0.7)]

    /// Удалено: сильный и тающий следом.
    static let toss = [Tap(at: 0, strength: 1, edge: 0.6),
                       Tap(at: 0.12, strength: 0.5, edge: 0.3)]

    /// Отменено: мягкое «тук-тук» назад.
    static let back = [Tap(at: 0, strength: 0.75, edge: 0.35),
                       Tap(at: 0.09, strength: 0.5, edge: 0.55)]

    /// Не вышло: три резких, последний сильнее.
    static let wrong = [Tap(at: 0, strength: 0.8, edge: 0.85),
                        Tap(at: 0.08, strength: 0.75, edge: 0.85),
                        Tap(at: 0.17, strength: 1, edge: 0.95)]

    static var all: [(name: String, taps: [Tap])] {
        [("выбор", pick), ("готово", done), ("удаление", toss),
         ("отмена", back), ("ошибка", wrong)]
    }
}
