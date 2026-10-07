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

    /// Влажность посчитана по сроку, а не измерена датчиком.
    var estimated: Bool { sensor?.last == nil }

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
