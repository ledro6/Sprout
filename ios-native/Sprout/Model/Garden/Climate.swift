import Foundation

/// Погода за окном: жара и сухой воздух торопят землю, прохлада и сырость —
/// придерживают. В квартире погода чувствуется вполовину — стены и батареи
/// сглаживают, на балконе и в саду — целиком. Сама погода приходит из
/// WeatherKit, см. `Weatherman`; здесь только арифметика — её проверяет
/// прогон модели.
struct Climate: Codable, Equatable, Sendable {
    /// Градусы Цельсия.
    var temperature: Double
    /// Влажность воздуха, 0…1.
    var humidity: Double
    /// Значок погоды из SF Symbols — как его отдаёт WeatherKit.
    var symbol: String
    var taken: Date

    /// Погода, при которой срок полива — ровно записанный.
    static let comfort = 22.0

    /// Сколько живёт снятая погода: дольше — она уже не про сегодня.
    static let shelf: TimeInterval = 6 * 3_600

    /// Во сколько раз быстрее обычного сохнет земля: каждые пять градусов
    /// жары — на десятую часть, сухой воздух — ещё до пятнадцати процентов.
    /// Холод и сырость — наоборот. Не больше чем в полтора раза в обе
    /// стороны: погода поправляет срок, а не переписывает его.
    static func pace(temperature: Double, humidity: Double,
                     outdoor: Bool) -> Double {
        let heat = min(max((temperature - comfort) / 5 * 0.1, -0.25), 0.4)
        let dry = min(max((0.5 - humidity) * 0.4, -0.15), 0.15)
        let share = outdoor ? 1.0 : 0.5
        return min(max(1 + share * (heat + dry), 0.65), 1.5)
    }

    func pace(outdoor: Bool = false) -> Double {
        Self.pace(temperature: temperature, humidity: humidity,
                  outdoor: outdoor)
    }

    /// Не старше шести часов.
    func fresh(at now: Date = Date()) -> Bool {
        now.timeIntervalSince(taken) < Self.shelf
            && now.timeIntervalSince(taken) > -Self.shelf
    }

    /// «+28°».
    var degrees: String {
        let rounded = Int(temperature.rounded())
        return rounded > 0 ? Lang.format("+%lld°", rounded)
            : Lang.format("%lld°", rounded)
    }

    /// Строка для экрана растения и карточки дня; погода почти не влияет —
    /// молчит.
    func line(outdoor: Bool = false) -> String? {
        let pace = pace(outdoor: outdoor)
        if pace >= 1.08 {
            return temperature >= Self.comfort + 4
                ? Lang.text("Жарко: земля сохнет быстрее")
                : Lang.text("Сухой воздух: земля сохнет быстрее")
        }
        if pace <= 0.92 {
            return temperature <= Self.comfort - 4
                ? Lang.text("Прохладно за окном: земля сохнет медленнее")
                : Lang.text("Сыро: земля сохнет медленнее")
        }
        return nil
    }

    /// Комната под открытым небом — по названию: балкон, лоджия, терраса,
    /// веранда, сад, двор, дача, улица, крыльцо.
    static func outdoor(_ room: String) -> Bool {
        let name = room.lowercased()
        return ["балкон", "лоджи", "террас", "веранд", "сад", "двор", "дач",
                "улиц", "крыльц", "balcony", "terrace", "patio", "porch",
                "garden", "yard", "veranda", "outdoor"]
            .contains { name.contains($0) }
    }

    // MARK: - Сегодня

    /// Поправка срока в квартире — её читает `Plant.period`. Единица —
    /// погода не учитывается или устарела. Ставит корень, как и время года.
    nonisolated(unsafe) static var stretch: Double = 1

    /// Во сколько раз быстрее сохнет на балконе, чем в квартире, — сад
    /// досушивает растения комнат под открытым небом, см. `Garden.advance`.
    nonisolated(unsafe) static var boost: Double = 1

    static func settle(_ climate: Climate?, on: Bool, now: Date = Date()) {
        guard on, let climate, climate.fresh(at: now) else {
            stretch = 1
            boost = 1
            return
        }
        let inside = climate.pace(outdoor: false)
        stretch = 1 / inside
        boost = climate.pace(outdoor: true) / inside
    }
}
