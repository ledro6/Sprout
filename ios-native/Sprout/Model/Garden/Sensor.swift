import Foundation

/// Датчик влажности почвы у растения: Bluetooth-датчик Flower Care (он же
/// Mi Flora, VegTrug, Grow Care) или датчик влажности из приложения «Дом» —
/// туда же попадают датчики Matter. Показывает проценты своей шкалы;
/// какие из них для этого растения «сухо» и «только что полили», хозяин
/// отмечает сам — кнопками в настройках растения. Проценты растения — между
/// этими метками.
struct Sensor: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// Flower Care и его родня по Bluetooth.
        case flora
        /// Датчик из «Дома» — HomeKit или Matter.
        case home
    }

    var kind: Kind
    /// Bluetooth — номер устройства, «Дом» — номер характеристики.
    var id: String
    var name: String
    /// Показания датчика, которые значат «сухо» и «только что полили».
    var dry: Double = Sensor.dryMark
    var wet: Double = Sensor.wetMark
    var last: Reading?

    /// Обычные метки Flower Care: суккуленты сухи к десяти процентам,
    /// тропики — к двадцати; свежеполитая земля — к пятидесяти.
    static let dryMark = 15.0
    static let wetMark = 45.0

    /// Влажность растения 0…1 по показанию. Метки перепутаны или слиплись —
    /// считаем по обычным.
    func level(_ moisture: Double) -> Double {
        var low = dry, high = wet
        if high - low < 5 { (low, high) = (Self.dryMark, Self.wetMark) }
        return min(max((moisture - low) / (high - low), 0), 1)
    }

    /// Полили, пока не смотрели: показание подскочило больше чем на треть
    /// шкалы растения.
    func poured(from old: Double, to new: Double) -> Bool {
        level(new) - level(old) > 0.33
    }
}

/// Одно показание датчика.
struct Reading: Codable, Hashable, Sendable {
    /// Влажность почвы, проценты датчика.
    var moisture: Double
    /// Градусы Цельсия.
    var temperature: Double?
    /// Освещённость, люксы.
    var light: Double?
    /// Удобрения в земле — электропроводность, мкСм/см.
    var fertility: Double?
    /// Заряд батарейки, проценты.
    var battery: Int?
    var when: Date
}

/// Протокол Flower Care: чтобы датчик отдал свежие показания, в служебную
/// характеристику пишут два байта, потом читают шестнадцать.
enum Flora {
    static let service = "00001204-0000-1000-8000-00805F9B34FB"
    static let mode = "00001A00-0000-1000-8000-00805F9B34FB"
    static let data = "00001A01-0000-1000-8000-00805F9B34FB"
    static let firmware = "00001A02-0000-1000-8000-00805F9B34FB"

    /// «Покажи сейчас».
    static let realtime: [UInt8] = [0xA0, 0x1F]

    /// Реклама датчиков Xiaomi — по ней их ищут рядом.
    static let beacon = "FE95"

    /// Имена, под которыми датчик виден по Bluetooth.
    static func named(_ name: String?) -> Bool {
        guard let name = name?.lowercased() else { return false }
        return ["flower care", "flower mate", "grow care", "vegtrug",
                "flower power"].contains { name.contains($0) }
    }

    /// Шестнадцать байт: температура — десятые градуса со знаком, байт
    /// пропуска, свет — четыре байта люксов, влажность — байт процентов,
    /// удобрения — два байта. Всё — младшим байтом вперёд. Пустые и
    /// заведомо битые показания не принимаются.
    static func reading(_ bytes: [UInt8], battery: Int? = nil,
                        at moment: Date = Date()) -> Reading? {
        guard bytes.count >= 10 else { return nil }
        // Датчик не в режиме «сейчас» — отдаёт мусор с этим началом.
        guard !(bytes[0] == 0xAA && bytes[1] == 0xBB) else { return nil }
        let raw = Int16(bitPattern: UInt16(bytes[0]) | UInt16(bytes[1]) << 8)
        let light = UInt32(bytes[3]) | UInt32(bytes[4]) << 8
            | UInt32(bytes[5]) << 16 | UInt32(bytes[6]) << 24
        let moisture = Double(bytes[7])
        let fertility = Double(UInt16(bytes[8]) | UInt16(bytes[9]) << 8)
        guard moisture <= 100 else { return nil }
        return Reading(moisture: moisture, temperature: Double(raw) / 10,
                       light: Double(light), fertility: fertility,
                       battery: battery, when: moment)
    }

    /// Заряд — первый байт характеристики прошивки.
    static func battery(_ bytes: [UInt8]) -> Int? {
        guard let first = bytes.first, first <= 100 else { return nil }
        return Int(first)
    }
}

extension Sensor {
    /// «Датчик: 38% · батарейка 82%».
    var status: String? {
        guard let last else { return nil }
        let percent = Lang.format("%lld%%", Int(last.moisture.rounded()))
        guard let battery = last.battery else {
            return Lang.format("Датчик: %@", percent)
        }
        return Lang.format("Датчик: %1$@ · батарейка %2$@", percent,
                           Lang.format("%lld%%", battery))
    }
}
