import Foundation

/// Планетарий сада. Растение — планета, срок полива — год её орбиты. Наверху
/// луч полива: планета доходит до него, когда земля высыхает, и политая
/// проходит сквозь него на новый круг — ровно, без скачка. Ближние орбиты у
/// тех, кто сохнет быстро, как у Меркурия; дальние — у терпеливых.
enum Orrery {
    /// Половина светлого сектора вокруг луча — только рисунок: сама планета
    /// идёт по кругу ровно и проходит луч в миг полива.
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

    /// Угол по часовой стрелке от луча: только что политая — на нём, сухая
    /// — снова на нём, круг спустя. Скорость по кругу постоянная: земля
    /// сохнет ровно.
    static func angle(moisture: Double) -> Double {
        (1 - min(max(moisture, 0), 1)) * 2 * .pi
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

/// Музыка сфер: каждый полив месяца — нота, ровно в миг, когда планета
/// проходит луч. Высота — по орбите: ближние поют выше, как у Кеплера; лад —
/// пентатоника, и как ни сойдутся ноты, фальши нет. Под нотами — тихий
/// аккорд, чтобы они звучали мелодией, а не каплями. Звук собирается здесь,
/// без звуковых библиотек: музыкальная шкатулка — основной тон с мягкими
/// обертонами, стерео по орбитам и зал.
enum Spheres {
    static let rate = 44_100

    /// Стерео: ближние орбиты чуть левее, дальние — правее.
    static let channels = 2

    /// Месяц сада пролетает за столько секунд.
    static let seconds = 20.0

    /// Хвост после последней ноты — на затухание зала.
    static let tail = 3.0

    /// Сколько звучит нота.
    static let ring = 2.4

    struct Note: Hashable, Sendable {
        var at: Double
        var pitch: Double
        /// −1 — слева, 1 — справа.
        var pan: Double = 0
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
            let side = count > 1
                ? Double($0.rank) / Double(count - 1) * 2 - 1 : 0
            return Note(at: $0.day / days * seconds,
                        pitch: pitch(rank: $0.rank, of: count),
                        pan: side * 0.45)
        }
    }

    /// Обертоны шкатулки: основной, октава, дуодецима и чуть расстроенный
    /// четвёртый — он и даёт металлический язычок. Спад — секунды.
    private static let partials: [(ratio: Double, level: Double,
                                   decay: Double)] = [
        (1, 1, 1.3), (2, 0.36, 0.62), (3, 0.13, 0.38), (4.07, 0.06, 0.24),
    ]

    /// Стерео чередованием: левый, правый, левый… Синус — поворотом на
    /// каждом отсчёте, а не `sin`: сотня нот иначе считалась бы заметно
    /// дольше.
    static func render(_ notes: [Note], seconds: Double = seconds) -> [Float] {
        let frames = Int((seconds + tail) * Double(rate))
        var left = [Double](repeating: 0, count: frames)
        var right = [Double](repeating: 0, count: frames)
        let attack = 0.008 * Double(rate)
        let release = 0.4 * Double(rate)
        for note in notes {
            let first = Int(note.at * Double(rate))
            guard first >= 0, first < frames else { continue }
            let span = min(Int(ring * Double(rate)), frames - first)
            // Высокие гаснут быстрее — как у настоящей шкатулки.
            let shorter = pow(440 / max(note.pitch, 1), 0.3)
            let pan = min(max(note.pan, -1), 1)
            let toLeft = cos((pan + 1) * .pi / 4)
            let toRight = sin((pan + 1) * .pi / 4)
            for partial in partials {
                let step = 2 * .pi * note.pitch * partial.ratio / Double(rate)
                let (c, s) = (cos(step), sin(step))
                var (x, y) = (1.0, 0.0)
                let fade = exp(-1 / (partial.decay * shorter * Double(rate)))
                var level = partial.level * voice
                for n in 0 ..< span {
                    guard level > 0.000_2 else { break }
                    // Мягкие начало и конец: без щелчков.
                    let into = Double(n)
                    let rest = Double(span - n)
                    let edge = (into < attack
                                ? 0.5 - 0.5 * cos(.pi * into / attack) : 1)
                        * (rest < release
                           ? 0.5 - 0.5 * cos(.pi * rest / release) : 1)
                    let value = y * level * edge
                    left[first + n] += value * toLeft
                    right[first + n] += value * toRight
                    (x, y) = (x * c - y * s, x * s + y * c)
                    level *= fade
                }
            }
        }
        pad(notes, &left, &right)
        hall(&left, seed: 0)
        hall(&right, seed: 23)
        limit(&left, &right)
        var out = [Float](repeating: 0, count: frames * channels)
        let close = 0.05 * Double(rate)
        for n in 0 ..< frames {
            let rest = Double(frames - n)
            let edge = rest < close ? rest / close : 1
            out[2 * n] = Float(left[n] * edge)
            out[2 * n + 1] = Float(right[n] * edge)
        }
        return out
    }

    /// Громкость одной ноты: одинокая звучит ясно, а плотный парад
    /// придерживает ограничитель.
    private static let voice = 0.45

    /// Ограничитель: звук подходит к потолку — усиление падает сразу и
    /// возвращается за треть секунды. Не пережатие: плотный парад звучит
    /// тише, но без хрипа.
    private static func limit(_ left: inout [Double],
                              _ right: inout [Double]) {
        let ceiling = 0.9
        let back = exp(-1 / (0.3 * Double(rate)))
        var held = 0.0
        for n in 0 ..< left.count {
            held = max(max(abs(left[n]), abs(right[n])), held * back)
            guard held > ceiling else { continue }
            left[n] *= ceiling / held
            right[n] *= ceiling / held
        }
    }

    /// Тихий аккорд под нотами — ля, ми и ля октавой выше, с медленным
    /// дыханием. Вступает с первой нотой и тает к концу.
    private static func pad(_ notes: [Note], _ left: inout [Double],
                            _ right: inout [Double]) {
        guard let first = notes.map(\.at).min(), first >= 0 else { return }
        let frames = left.count
        let start = Int(first * Double(rate))
        guard start < frames else { return }
        let chord: [(pitch: Double, level: Double)] = [
            (110, 0.07), (164.81, 0.05), (220, 0.04),
        ]
        let rise = 1.6 * Double(rate)
        let fall = 2.6 * Double(rate)
        for (index, tone) in chord.enumerated() {
            let step = 2 * .pi * tone.pitch / Double(rate)
            let (c, s) = (cos(step), sin(step))
            var (x, y) = (1.0, 0.0)
            // Дыхание — тоже поворотом: медленная волна громкости.
            let slow = 2 * .pi * (0.11 + 0.03 * Double(index)) / Double(rate)
            let (sc, ss) = (cos(slow), sin(slow))
            var (bx, by) = (1.0, 0.0)
            for n in start ..< frames {
                let swell = min(Double(n - start) / rise, 1)
                    * min(Double(frames - n) / fall, 1)
                let value = y * tone.level * voice * swell * (0.8 + 0.2 * by)
                left[n] += value
                right[n] += value
                (x, y) = (x * c - y * s, x * s + y * c)
                (bx, by) = (bx * sc - by * ss, bx * ss + by * sc)
            }
        }
    }

    /// Зал: четыре гребня с затуханием и мягкими верхами и два всепропускающих
    /// — как у Шрёдера. У правого канала задержки чуть длиннее: зал шире.
    private static func hall(_ signal: inout [Double], seed: Int) {
        let dry = signal
        let combs = [1116, 1188, 1277, 1356].map { $0 + seed }
        var wet = [Double](repeating: 0, count: dry.count)
        for delay in combs {
            var line = [Double](repeating: 0, count: delay)
            var index = 0
            var soft = 0.0
            for n in 0 ..< dry.count {
                let out = line[index]
                soft = out * 0.75 + soft * 0.25
                line[index] = dry[n] + soft * 0.8
                index = (index + 1) % delay
                wet[n] += out
            }
        }
        for delay in [556, 441].map({ $0 + seed / 2 }) {
            var line = [Double](repeating: 0, count: delay)
            var index = 0
            for n in 0 ..< wet.count {
                let held = line[index]
                let out = held - wet[n]
                line[index] = wet[n] + held * 0.5
                index = (index + 1) % delay
                wet[n] = out
            }
        }
        for n in 0 ..< signal.count {
            signal[n] = dry[n] * 0.85 + wet[n] * 0.07
        }
    }

    /// WAV: 16 бит, стерео чередованием. Такой файл проигрыватель системы
    /// берёт прямо из памяти.
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
        put16(UInt16(channels))
        put32(UInt32(rate))
        put32(UInt32(rate * 2 * channels))
        put16(UInt16(2 * channels))
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
