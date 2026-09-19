import Foundation

/// Точка огибающей: доля времени и сила отклика в ней. Обе 0…1.
struct Moment: Sendable, Equatable {
    var at: Double
    var strength: Double

    init(_ at: Double, _ strength: Double) {
        self.at = at
        self.strength = strength
    }
}

/// Рисунок отклика Taptic Engine — форма без времени и без самого движка.
///
/// Времени здесь нет намеренно. Отклик полива длится ровно столько,
/// сколько идёт волна по узору, а отклик кутерьмы — сколько идёт она
/// сама; оба числа живут рядом со своими анимациями, и повторять их тут
/// значило бы завести вторую правду, которая рано или поздно разойдётся с
/// первой. Долю времени огибающая знает, а во что она превратится в
/// секундах — решает тот, кто отклик проигрывает.
///
/// Движка здесь тоже нет: `CoreHaptics` есть только на телефоне, а числа
/// можно прогнать где угодно. Прогон этот не роскошь — движок отвергает
/// любое значение вне 0…1 и любую огибающую, идущую вспять, и узнать об
/// этом без проверки можно было бы только по молчащему телефону.
struct Pulse: Sendable, Equatable {
    /// Короткий удар в самом начале: сила и резкость. Ноль силы — удара
    /// нет вовсе.
    var strike: Double = 0
    var strikeEdge: Double = 0.5

    /// И такой же в конце.
    var finish: Double = 0
    var finishEdge: Double = 0.5

    /// Резкость тянущегося гула. Ниже — глуше и мягче, выше — звонче.
    var edge: Double = 0.5

    /// Огибающая гула: с какой силой он идёт в каждую долю времени.
    var envelope: [Moment]

    /// Сила гула в эту долю времени — между точками по прямой.
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

    /// Примет ли такой рисунок движок.
    ///
    /// Он требует: все значения в 0…1, огибающая не пуста, начинается в
    /// нуле, кончается в единице и идёт только вперёд.
    var valid: Bool {
        let fits = { (value: Double) in value >= 0 && value <= 1 }
        guard fits(strike), fits(strikeEdge), fits(finish), fits(finishEdge),
              fits(edge)
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

    /// Полив.
    ///
    /// Всплеск и долгий уход: резкий удар в тот миг, когда палец отпустил
    /// кнопку, сразу за ним гул почти в полную силу — и дальше он тает
    /// всю оставшуюся волну, ни разу не усилившись. Так и выглядит то, что
    /// в это время происходит на экране: кольцо расходится от плашки и
    /// слабеет, уходя за край.
    ///
    /// Гул мягкий, резкость низкая: вода не щёлкает.
    static let water = Pulse(
        strike: 0.9, strikeEdge: 0.65, edge: 0.22,
        envelope: [
            Moment(0, 0.45), Moment(0.09, 0.78), Moment(0.3, 0.44),
            Moment(0.55, 0.22), Moment(0.8, 0.08), Moment(1, 0),
        ])

    /// Новое растение.
    ///
    /// Наоборот: из ничего вырастает и лопается хлопком в конце. Удара в
    /// начале нет — начинать нечему, растение как раз появляется.
    static let bloom = Pulse(
        finish: 1, finishEdge: 0.85, edge: 0.4,
        envelope: [
            Moment(0, 0.05), Moment(0.45, 0.3), Moment(0.8, 0.62),
            Moment(1, 0.85),
        ])

    /// Кутерьма от тряски: по бугру на каждый такт, и все они растут.
    ///
    /// Считается из самой кутерьмы, а не выписывается числами: тактов там
    /// шесть, и разойдись эти два места — бугры поехали бы мимо того, что
    /// видно на экране. Последний бугор приходится на последний
    /// беспорядочный такт, а хвост до единицы — это тот такт, которым узор
    /// садится обратно: под него отклик стихает до нуля.
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
        return Pulse(strike: 0.55, strikeEdge: 0.9, finish: 0.7,
                     finishEdge: 0.3, edge: 0.6, envelope: points)
    }

    /// Все рисунки разом — для прогона.
    static var all: [(name: String, pulse: Pulse)] {
        [("полив", water), ("всходы", bloom), ("кутерьма", frenzy)]
    }
}
