import Foundation

/// Планетарий сада. Растение — планета, срок полива — год её орбиты. Наверху
/// ворота полива: планета подходит к ним, когда земля высыхает, а политая —
/// перелетает и идёт на новый круг. Ближние орбиты у тех, кто сохнет
/// быстро, как у Меркурия; дальние — у терпеливых.
enum Orrery {
    /// Половина ворот. Без них только что политая и ждущая полива планеты
    /// стояли бы в одной точке.
    static let gate = 12.0 * .pi / 180

    /// Ближняя и дальняя орбиты — доли радиуса: в середине солнце.
    static let inner = 0.3
    static let outer = 0.97

    /// Сколько дней сада видно вперёд — ползунок и проигрывание.
    static let reach = 30.0

    struct Orbit: Identifiable, Hashable, Sendable {
        var id: Plant.ID
        var name: String
        /// Дней сада на круг — срок с поправкой на время года.
        var period: Double
        var moisture: Double
        /// Доля радиуса планетария.
        var radius: Double
        /// 0 — ближняя орбита.
        var rank: Int
    }

    /// Полив в будущем: чей и через сколько дней сада.
    struct Crossing: Hashable, Sendable {
        var id: Plant.ID
        var day: Double
        var rank: Int
    }

    /// Парад: в один день сада воды попросят сразу несколько растений.
    struct Parade: Identifiable, Hashable, Sendable {
        var day: Int
        var ids: [Plant.ID]
        var names: [String]

        var id: Int { day }
    }

    /// Планета в кадре: где она и сколько у неё воды.
    struct Planet: Identifiable, Hashable, Sendable {
        var id: Plant.ID
        var name: String
        var radius: Double
        var angle: Double
        var moisture: Double
    }

    /// Вспышка у ворот: только что политая планета. Сила гаснет от единицы.
    struct Flash: Hashable, Sendable {
        var radius: Double
        var strength: Double
    }

    /// Кадр. Сейчас — живой сад: сухие ждут у ворот, пока их не польют, а
    /// между тактами часов планеты досчитываются, чтобы плыть, а не
    /// прыгать. Впереди — если поливать вовремя.
    static func sky(_ orbits: [Orbit], ahead days: Double,
                    drift: Double = 0) -> [Planet] {
        orbits.map { orbit in
            let level = days > 0 ? moisture(orbit, after: days)
                : max(0, orbit.moisture - max(drift, 0) / orbit.period)
            return Planet(id: orbit.id, name: orbit.name, radius: orbit.radius,
                          angle: angle(moisture: level), moisture: level)
        }
    }

    /// Кого полили за последний день перед `days`: у ворот расходится круг.
    static func flashes(_ crossings: [Crossing], orbits: [Orbit],
                        at days: Double, span: Double = 1) -> [Flash] {
        let radius = Dictionary(orbits.map { ($0.id, $0.radius) },
                                uniquingKeysWith: { first, _ in first })
        return crossings.compactMap { crossing in
            let since = days - crossing.day
            guard since >= 0, since < span, let place = radius[crossing.id]
            else { return nil }
            return Flash(radius: place, strength: 1 - since / span)
        }
    }

    /// По сроку от ближней к дальней; равные сроки — по кличке, чтобы
    /// порядок не прыгал.
    static func orbits(_ plants: [Plant]) -> [Orbit] {
        let sorted = plants.filter { $0.period > 0 }.sorted {
            ($0.period, $0.name, $0.id) < ($1.period, $1.name, $1.id)
        }
        let last = max(sorted.count - 1, 1)
        return sorted.enumerated().map { rank, plant in
            let step = sorted.count > 1 ? Double(rank) / Double(last) : 0.5
            return Orbit(id: plant.id, name: plant.name, period: plant.period,
                         moisture: plant.moisture,
                         radius: inner + (outer - inner) * step, rank: rank)
        }
    }

    /// Угол по часовой стрелке от верха: только что политая — сразу за
    /// воротами, сухая — перед ними.
    static func angle(moisture: Double) -> Double {
        let dried = 1 - min(max(moisture, 0), 1)
        return gate + dried * (2 * .pi - 2 * gate)
    }

    /// Влажность через `days` дней сада, если поливать ровно тогда, когда
    /// земля высохла.
    static func moisture(_ orbit: Orbit, after days: Double) -> Double {
        guard days > 0, orbit.period > 0 else { return orbit.moisture }
        let dry = orbit.moisture * orbit.period
        guard days >= dry else { return orbit.moisture - days / orbit.period }
        let into = (days - dry).truncatingRemainder(dividingBy: orbit.period)
        return 1 - into / orbit.period
    }

    /// Все поливы от сейчас до `days` дней вперёд. Сухие сейчас — в нулевой
    /// миг: их ждут уже сегодня.
    static func crossings(_ orbits: [Orbit], within days: Double)
        -> [Crossing] {
        var out: [Crossing] = []
        for orbit in orbits where orbit.period > 0 {
            var day = orbit.moisture * orbit.period
            var turns = 0
            while day <= days, turns < 1_000 {
                out.append(Crossing(id: orbit.id, day: day, rank: orbit.rank))
                day += orbit.period
                turns += 1
            }
        }
        return out.sorted { ($0.day, $0.rank) < ($1.day, $1.rank) }
    }

    /// Самые большие парады — сначала многолюдные, из равных — ближние.
    /// День — тем же округлением, что «Следующий полив» на карточке.
    static func parades(_ orbits: [Orbit], within days: Double = reach,
                        least: Int = 3) -> [Parade] {
        let names = Dictionary(orbits.map { ($0.id, $0.name) },
                               uniquingKeysWith: { first, _ in first })
        var byDay: [Int: [Plant.ID]] = [:]
        for crossing in crossings(orbits, within: days) {
            let day = Int(crossing.day.rounded())
            guard Double(day) <= days else { continue }
            byDay[day, default: []].append(crossing.id)
        }
        return byDay.filter { $0.value.count >= least }
            .map { day, ids in
                Parade(day: day, ids: ids, names: ids.compactMap { names[$0] })
            }
            .sorted { ($0.ids.count, -$0.day) > ($1.ids.count, -$1.day) }
    }
}

/// Музыка сфер: каждый полив месяца — нота. Высота — по орбите: ближние
/// поют выше, как у Кеплера; лад — пентатоника, и как ни сойдутся ноты,
/// фальши нет. Звук собирается здесь, без звуковых библиотек: колокольчик —
/// основной тон с обертонами и спадом, потом немного эха.
enum Spheres {
    static let rate = 44_100

    /// Месяц сада пролетает за столько секунд.
    static let seconds = 20.0

    /// Хвост после последней ноты — на затухание.
    static let tail = 2.2

    /// Нота колокольчика и её спад.
    static let ring = 1.7

    struct Note: Hashable, Sendable {
        var at: Double
        var pitch: Double
    }

    /// Мажорная пентатоника от ля малой октавы вверх на две с лишним
    /// октавы. Ближняя орбита — самая высокая нота.
    static func pitch(rank: Int, of count: Int) -> Double {
        let scale = [0, 2, 4, 7, 9]
        let degrees = 12
        let from = count > 1
            ? Double(count - 1 - rank) / Double(count - 1) : 0.5
        let degree = Int((from * Double(degrees - 1)).rounded())
        let semitone = scale[degree % scale.count] + 12 * (degree / scale.count)
        return 220 * pow(2, Double(semitone) / 12)
    }

    static func notes(_ crossings: [Orrery.Crossing], count: Int,
                      days: Double = Orrery.reach,
                      seconds: Double = seconds) -> [Note] {
        crossings.map {
            Note(at: $0.day / days * seconds,
                 pitch: pitch(rank: $0.rank, of: count))
        }
    }

    /// Синус — поворотом на каждом отсчёте, а не `sin`: сотня нот по
    /// полторы секунды иначе считалась бы заметно дольше.
    static func render(_ notes: [Note], seconds: Double = seconds) -> [Float] {
        let length = Int((seconds + tail) * Double(rate))
        var mix = [Double](repeating: 0, count: length)
        // Основной тон, октава и «колокольный» обертон; у высоких спад
        // быстрее.
        let partials: [(ratio: Double, level: Double, decay: Double)] = [
            (1, 1, 0.55), (2, 0.32, 0.32), (2.76, 0.14, 0.18),
        ]
        let attack = 0.006 * Double(rate)
        for note in notes {
            let first = Int(note.at * Double(rate))
            guard first >= 0, first < length else { continue }
            let span = min(Int(ring * Double(rate)), length - first)
            for partial in partials {
                let step = 2 * .pi * note.pitch * partial.ratio / Double(rate)
                let (c, s) = (cos(step), sin(step))
                var (x, y) = (1.0, 0.0)
                let fade = exp(-1 / (partial.decay * Double(rate)))
                var level = partial.level
                for n in 0 ..< span {
                    let rise = Double(n) < attack ? Double(n) / attack : 1
                    mix[first + n] += y * level * rise
                    (x, y) = (x * c - y * s, x * s + y * c)
                    level *= fade
                }
            }
        }
        echo(&mix)
        // Плотный парад не должен хрипеть: сжатие по гиперболическому
        // тангенсу, потом громкость до запаса в десятую часть.
        let peak = mix.reduce(0) { max($0, abs($1)) }
        guard peak > 0 else { return mix.map { Float($0) } }
        let drive = 1.6 / peak
        let squashed = mix.map { tanh($0 * drive) }
        let top = squashed.reduce(0) { max($0, abs($1)) }
        let gain = top > 0 ? 0.9 / top : 1
        return squashed.map { Float($0 * gain) }
    }

    /// Три затухающих отражения — зал, а не комната.
    private static func echo(_ mix: inout [Double]) {
        let taps: [(delay: Double, level: Double)] = [
            (0.083, 0.28), (0.131, 0.2), (0.197, 0.14),
        ]
        let dry = mix
        for tap in taps {
            let offset = Int(tap.delay * Double(rate))
            guard offset > 0, offset < mix.count else { continue }
            var wet = [Double](repeating: 0, count: mix.count)
            for n in offset ..< mix.count {
                wet[n] = dry[n - offset] * tap.level + wet[n - offset] * 0.35
            }
            for n in 0 ..< mix.count { mix[n] += wet[n] }
        }
    }

    /// WAV: 16 бит, моно. Такой файл проигрыватель системы берёт прямо из
    /// памяти.
    static func wav(_ samples: [Float]) -> Data {
        var data = Data()
        func put(_ text: String) { data.append(contentsOf: Array(text.utf8)) }
        func put32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func put16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let bytes = UInt32(samples.count * 2)
        put("RIFF")
        put32(36 + bytes)
        put("WAVE")
        put("fmt ")
        put32(16)
        put16(1)
        put16(1)
        put32(UInt32(rate))
        put32(UInt32(rate * 2))
        put16(2)
        put16(16)
        put("data")
        put32(bytes)
        data.reserveCapacity(data.count + samples.count * 2)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            put16(UInt16(bitPattern: Int16(clamped * Float(Int16.max))))
        }
        return data
    }
}
