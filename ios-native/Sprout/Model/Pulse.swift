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

/// Один тычок: когда, какой силы и какой резкости.
struct Tap: Sendable, Equatable {
    var at: Double
    var strength: Double
    var edge: Double
}

/// Рисунок отклика Taptic Engine — форма без времени и без самого движка.
///
/// Отклик собран из тычков, а не из тянущегося гула, и это главное здесь
/// решение. Гул движок умеет, и первая версия была им: одно долгое
/// событие, которому кривая задаёт силу. Выходила ровная вибрация — она
/// честно повторяла огибающую, но ничего не рассказывала. Волна по экрану
/// не течёт ровно: она идёт рядами фигурок, и каждый ряд — отдельное
/// событие. Ряд тычков это и передаёт, а гул оставлен подложкой в
/// четверть силы, чтобы между тычками рука не оставалась пустой.
///
/// Времени здесь нет намеренно. Отклик полива длится ровно столько,
/// сколько идёт волна по узору, а отклик всходов — сколько всходит узор;
/// оба числа живут рядом со своими анимациями, и повторять их тут значило
/// бы завести вторую правду. Долю времени огибающая знает, а во что она
/// превратится в секундах — решает тот, кто отклик проигрывает.
///
/// Движка здесь тоже нет: `CoreHaptics` есть только на телефоне, а числа
/// можно прогнать где угодно. Прогон этот не роскошь — движок отвергает
/// любое значение вне 0…1 и любую огибающую, идущую вспять, и узнать об
/// этом без проверки можно было бы только по молчащему телефону.
struct Pulse: Sendable, Equatable {
    /// Сколько тычков в секунду.
    ///
    /// У полива тринадцать, и число не с потолка: волна проходит девятьсот
    /// пунктов за полторы секунды, то есть около шестисот в секунду, а
    /// ряды узора стоят через сорок семь. Двенадцать-тринадцать рядов в
    /// секунду волна и поднимает — столько же тычков и уходит в руку.
    /// Чаще — и они сливаются в жужжание, реже — и рука отстаёт от
    /// экрана.
    var rate: Double

    /// Резкость тычков.
    var edge: Double = 0.6

    /// Тянущийся гул под тычками, доля от их силы. Ноль — только тычки.
    var hum: Double = 0

    /// Короткий удар в самом начале: сила и резкость. Ноль силы — удара
    /// нет вовсе.
    var strike: Double = 0
    var strikeEdge: Double = 0.5

    /// И такой же в конце.
    var finish: Double = 0
    var finishEdge: Double = 0.5

    /// Огибающая: с какой силой идут тычки в каждую долю времени.
    var envelope: [Moment]

    /// Тише этого тычок не ставим: движок его всё равно не покажет, а
    /// событие на него потратит.
    static let faintest = 0.06

    /// Ряд тычков на такую длительность.
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

    /// Сила в эту долю времени — между точками по прямой.
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

    /// Полив.
    ///
    /// Всплеск и долгий уход: резкий удар в тот миг, когда палец отпустил
    /// кнопку, за ним частая дробь почти в полную силу — и дальше она
    /// редеет и слабеет всю оставшуюся волну, ни разу не усилившись. Так и
    /// выглядит то, что в это время происходит на экране: кольцо
    /// расходится от плашки и слабеет, уходя за край.
    static let water = Pulse(
        rate: 13, edge: 0.4, hum: 0.25, strike: 0.9, strikeEdge: 0.65,
        envelope: [
            Moment(0, 0.55), Moment(0.09, 0.9), Moment(0.3, 0.5),
            Moment(0.55, 0.26), Moment(0.8, 0.1), Moment(1, 0),
        ])

    /// Всходы узора при запуске.
    ///
    /// Узор поднимается фигурка за фигуркой, и отклик идёт тем же ходом:
    /// начинается редкими слабыми тычками, набирает частоту и силу к
    /// середине и садится мягким хлопком, когда последняя фигурка встала
    /// на место. Ни удара в начале, ни гула: всходы ничем не вызваны, они
    /// просто случаются, и вздрагивать руке не с чего.
    static let sprout = Pulse(
        rate: 15, edge: 0.3,
        finish: 0.45, finishEdge: 0.25,
        envelope: [
            Moment(0, 0.08), Moment(0.25, 0.3), Moment(0.55, 0.58),
            Moment(0.85, 0.42), Moment(1, 0.16),
        ])

    /// Новое растение.
    ///
    /// Наоборот: из ничего вырастает и лопается хлопком в конце. Удара в
    /// начале нет — начинать нечему, растение как раз появляется.
    static let bloom = Pulse(
        rate: 18, edge: 0.55, finish: 1, finishEdge: 0.85,
        envelope: [
            Moment(0, 0.08), Moment(0.45, 0.35), Moment(0.8, 0.7),
            Moment(1, 0.9),
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
        return Pulse(rate: 12, edge: 0.75, hum: 0.2, strike: 0.55,
                     strikeEdge: 0.9, finish: 0.7, finishEdge: 0.3,
                     envelope: points)
    }

    /// Все рисунки разом — для прогона.
    static var all: [(name: String, pulse: Pulse)] {
        [("полив", water), ("всходы", sprout), ("посадка", bloom),
         ("кутерьма", frenzy)]
    }
}
