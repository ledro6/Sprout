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
    /// Тычков в секунду. У полива 13: волна поднимает около 13 рядов узора в
    /// секунду. Чаще — жужжание, реже — рука отстаёт от экрана.
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

    // MARK: - Рисунки

    /// Полив: удар, дробь почти в полную силу и уход до конца волны — как
    /// кольцо, слабеющее к краю экрана.
    static let water = Pulse(
        rate: 13, edge: 0.4, hum: 0.25, strike: 0.9, strikeEdge: 0.65,
        envelope: [
            Moment(0, 0.55), Moment(0.09, 0.9), Moment(0.3, 0.5),
            Moment(0.55, 0.26), Moment(0.8, 0.1), Moment(1, 0),
        ])

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
        [("полив", water), ("всходы", sprout), ("посадка", bloom),
         ("кутерьма", frenzy)]
    }
}
