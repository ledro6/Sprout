import Foundation

/// Свой порог «влажно — не поливать» у вида. Пока у всех общий, 60 %:
/// таблица — место для суккулентов и болотных, когда понадобится.
extension Preset {
    static let wetFrom: [Preset: Double] = [:]
}

extension Plant {
    /// Порог «влажно» этого растения — вида, иначе общий.
    /// Пустая таблица — вид не узнаём вовсе: статус спрашивают каждую
    /// секунду у каждой карточки.
    var wetFrom: Double {
        guard !Preset.wetFrom.isEmpty else { return MoistureStatus.wetFrom }
        return Preset.wetFrom[blueprint.preset] ?? MoistureStatus.wetFrom
    }

    var status: MoistureStatus {
        MoistureStatus(moisture: moisture, wetFrom: wetFrom)
    }

    /// Влажность посчитана по сроку, а не измерена датчиком: датчик
    /// привязан и последнее значение — его.
    var estimated: Bool { !(source == .sensor && sensor?.last != nil) }

    /// «Датчик» или «Расчёт» — значок у процента.
    var sourceLabel: String { MoistureStatus.source(estimated: estimated) }

    /// Одна строка влажности на экране растения: процент, откуда он и, у
    /// датчика, заряд. Сырое показание датчика в процентах его шкалы сюда
    /// не идёт: два разных процента подряд читались бы противоречием.
    var moistureLine: String {
        let head = Lang.format("Влажность %@", moistureLabel)
        guard !estimated, let battery = sensor?.last?.battery else {
            return Lang.format("%1$@ · %2$@", head, sourceLabel)
        }
        return Lang.format("%1$@ · %2$@ · батарейка %3$@", head, sourceLabel,
                           Lang.format("%lld%%", battery))
    }

    /// Полить сегодня — см. `MoistureStatus.due`.
    var needsWaterToday: Bool {
        MoistureStatus.due(moisture: moisture, period: period)
    }

    var nextWateringText: String {
        MoistureStatus.nextWatering(moisture: moisture, period: period,
                                    estimated: estimated)
    }

    var wateringGuard: MoistureStatus.Guard {
        MoistureStatus.wateringGuard(moisture: moisture, wetFrom: wetFrom)
    }
}

extension MoistureStatus {
    /// «Что полить сегодня» — сухие (`urgent`) и те, чей срок вышел: ноль
    /// дней до полива. От самого сухого. Один набор на карточку дня и «Полить
    /// по очереди», обход на экране блокировки, Siri, напоминание, виджет,
    /// часы, «Спросить сад», «Ждут воды» в статистике и приветствие.
    static func needsWater(in rooms: [Room]) -> [Plant] {
        rooms.flatMap(\.plants)
            .filter(\.needsWaterToday)
            .sorted { $0.moisture < $1.moisture }
    }
}

extension MoistureStatus {
    /// Ближайший полив среди тех, кому пить пока не пора: растение и дней до
    /// него (не меньше одного). Отложенному на день — «завтра». Пусто — в
    /// саду нет растений.
    static func soonest(in rooms: [Room], now: Date = Date())
        -> (plant: Plant, days: Int)? {
        let found = rooms.flatMap(\.plants).map { plant -> (Plant, Int) in
            let days = max(plant.daysUntilWatering, 0)
            return (plant, max(days, 1))
        }
        guard let best = found.min(by: { a, b in
            a.1 != b.1 ? a.1 < b.1 : a.0.moisture < b.0.moisture
        }) else { return nil }
        return (best.0, best.1)
    }

    /// «завтра» или «через N дн».
    static func inDays(_ days: Int) -> String {
        days <= 1 ? Lang.text("завтра") : Lang.format("через %lld дн", days)
    }

    /// Строка блока «Сегодня», когда поливать некого.
    static func calmLine(in rooms: [Room], now: Date = Date()) -> String {
        guard let next = soonest(in: rooms, now: now) else {
            return Lang.text("Всё в порядке")
        }
        return Lang.format("Всё в порядке · ближайший полив — %1$@, %2$@",
                           next.plant.name, inDays(next.days))
    }
}

extension MoistureStatus {
    /// Кого поливать разом: «скоро пить» и «сухо». Влажные и в норме в
    /// массовых действиях не участвуют — защита от перелива.
    static func bulk(_ plants: [Plant]) -> [Plant] {
        plants.filter { $0.status == .soon || $0.status == .urgent }
    }

    /// Вторая строка приветствия на карточке дня комнаты `room`: кого здесь
    /// полить сегодня. Здесь пить некому, а в других комнатах ждут — так и
    /// сказано: «все довольны» при сухом растении в саду было бы неправдой.
    static func dayLine(room: Room, in rooms: [Room]) -> String {
        let here = needsWater(in: [room])
        guard here.isEmpty else { return Seed.dueLine(here) }
        let elsewhere = needsWater(in: rooms).count
        guard elsewhere == 0 else {
            return Lang.format("В других комнатах ждут воды: %lld",
                               elsewhere)
        }
        return Lang.text("Здесь все довольны — можно выдохнуть.")
    }
}

/// Влажность нового растения — по ответу «Последний полив» при посадке, а
/// не 100 % у всех: растение из магазина бывает и сухим.
enum Start {
    enum Last: String, CaseIterable, Sendable {
        case today, yesterday, longAgo, unknown

        var title: String {
            switch self {
            case .today: Lang.text("Сегодня")
            case .yesterday: Lang.text("Вчера")
            case .longAgo: Lang.text("3+ дня назад")
            case .unknown: Lang.text("Не помню")
            }
        }
    }

    /// «Не помню» — «Земля сухая?»: потрогать пальцем.
    enum Soil: String, CaseIterable, Sendable {
        case dry, damp, wet

        var title: String {
            switch self {
            case .dry: Lang.text("Сухая")
            case .damp: Lang.text("Чуть влажная")
            case .wet: Lang.text("Мокрая")
            }
        }

        /// Сухая — «полить сегодня», чуть влажная — «скоро пить», мокрая —
        /// «влажно».
        var moisture: Double {
            switch self {
            case .dry: 0.1
            case .damp: 0.35
            case .wet: 0.85
            }
        }
    }

    /// Не помнят и землю не трогали — пусто: статус «Проверьте землю».
    static func moisture(last: Last, soil: Soil?, period: Double) -> Double? {
        let days: Double
        switch last {
        case .today: return 1
        case .yesterday: days = 1
        case .longAgo: days = 3
        case .unknown: return soil?.moisture
        }
        guard period > 0 else { return 1 }
        return min(max(1 - days / period, 0), 1)
    }

    /// Посадили, не ответив про землю: как «чуть влажная» — пусть растение
    /// попадёт в «скоро пить» и хозяин потрогает землю, а не забудет о нём.
    static let unsure = Soil.damp.moisture
}
