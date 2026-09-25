import Foundation
import Observation

/// Время года для полива: зимой земля сохнет медленнее — меньше света и
/// тепла, растение почти не растёт, — летом быстрее. Полушарие — по стране
/// из настроек телефона, без сети и без места на карте; у экватора времён
/// года нет, и срок не меняется.
enum Season {
    enum Side: Equatable, Sendable {
        case north
        case south
        case tropics
    }

    /// Во сколько раз срок сейчас длиннее записанного. Ставит корень при
    /// запуске, при смене дня и когда выключают настройку; сад и подписи
    /// читают отсюда. Единица — время года не учитывается.
    nonisolated(unsafe) static var stretch: Double = 1

    /// Сейчас пора роста — идёт счёт до подкормки.
    nonisolated(unsafe) static var growing = true

    /// Страны южного полушария с заметной зимой.
    private static let southern: Set<String> = [
        "AR", "AU", "BW", "CL", "FK", "LS", "NA", "NZ", "PY", "SZ", "UY", "ZA",
    ]

    /// Около экватора: разница между «зимой» и «летом» — дожди, а не свет.
    private static let equatorial: Set<String> = [
        "BN", "BR", "CO", "CR", "EC", "GA", "GH", "ID", "KE", "LK", "MV", "MY",
        "NG", "PA", "PE", "PH", "SG", "SR", "TH", "TZ", "UG", "VE", "VN",
    ]

    static func side(region: String?) -> Side {
        guard let region = region?.uppercased() else { return .north }
        if southern.contains(region) { return .south }
        if equatorial.contains(region) { return .tropics }
        return .north
    }

    /// Месяц 1…12 по ту сторону экватора: южный январь — северный июль.
    private static func northern(_ month: Int, _ side: Side) -> Int {
        side == .south ? (month + 5) % 12 + 1 : month
    }

    /// Множитель срока по месяцу. Декабрь—февраль — треть сверху, лето —
    /// на седьмую часть короче; весна и осень посередине, чтобы срок не
    /// прыгал в первое число.
    static func stretch(month: Int, side: Side) -> Double {
        guard side != .tropics else { return 1 }
        switch northern(month, side) {
        case 12, 1, 2: return 1.35
        case 3, 11: return 1.15
        case 4, 10: return 1
        case 5, 9: return 0.95
        default: return 0.85
        }
    }

    /// Март—сентябрь на севере: растут и едят. Зимой удобрение только жжёт
    /// корни.
    static func growing(month: Int, side: Side) -> Bool {
        side == .tropics || (3 ... 9).contains(northern(month, side))
    }

    /// Поправка на сегодня; выключено — круглый год как записано. Пора роста
    /// считается и при выключенной: подкормке зима вредна всё равно.
    static func settle(on: Bool, now: Date = Date(),
                       region: String? = Locale.current.region?.identifier,
                       calendar: Calendar = .current) {
        let month = calendar.component(.month, from: now)
        let here = side(region: region)
        stretch = on ? stretch(month: month, side: here) : 1
        growing = growing(month: month, side: here)
    }

    /// Узор на этот день. Гирлянда — с 20 декабря по 10 января по обе
    /// стороны экватора: Новый год встречают и там, где он летом. У экватора
    /// ни снега, ни листопада.
    static func motif(month: Int, day: Int, side: Side) -> Motif {
        if (month == 12 && day >= 20) || (month == 1 && day <= 10) {
            return .garland
        }
        guard side != .tropics else { return .plain }
        switch northern(month, side) {
        case 12, 1, 2: return .snow
        case 9, 10, 11: return .leaves
        default: return .plain
        }
    }

    /// Строка для экрана растения; летом и осенью молчит — там срок почти
    /// тот же.
    static func line(stretch: Double) -> String? {
        switch stretch {
        case 1.3...: Lang.text("Зима: земля сохнет медленнее, поливать реже")
        case 1.1 ..< 1.3: Lang.text("Прохладно: земля сохнет чуть медленнее")
        case ..<0.9: Lang.text("Лето: земля сохнет быстрее, поливать чаще")
        default: nil
        }
    }
}

/// Узор по времени года: зимой в него вплетаются снежинки, осенью —
/// кленовые листья, под Новый год капли горят гирляндой. Выбранные фигурки
/// остаются — время года только добавляет свою.
enum Motif: Equatable, Sendable {
    case plain
    case snow
    case leaves
    case garland

    /// Номер добавленной фигурки в `SproutShapes.every`: снежинка и клён
    /// идут за четырьмя из настроек, огоньки гирлянды — капли.
    var extra: Int? {
        switch self {
        case .plain: nil
        case .snow: 4
        case .leaves: 5
        case .garland: 1
        }
    }

    /// Набор узора: выбранное и фигурка времени года. По порядку — как
    /// `Settings.chosen`, чтобы раскладка не зависела от того, откуда набор.
    func dress(_ chosen: [Int]) -> [Int] {
        guard let extra, !chosen.contains(extra) else { return chosen }
        return (chosen + [extra]).sorted()
    }
}

/// Узор этого дня. Наблюдаемый: сменился день или выключили настройку —
/// фон перерисовывается сам. Ставит корень при запуске и возвращении.
@Observable
final class Festive {
    static let shared = Festive()

    private(set) var motif: Motif = .plain

    init() {}

    /// Отвечает прежним узором, если он сменился, — по нему корень пускает
    /// волну смены фигурок.
    @discardableResult
    func settle(on: Bool, now: Date = Date(),
                region: String? = Locale.current.region?.identifier,
                calendar: Calendar = .current) -> Motif? {
        let day = calendar.dateComponents([.month, .day], from: now)
        let next = on ? Season.motif(month: day.month ?? 1, day: day.day ?? 1,
                                     side: Season.side(region: region))
            : .plain
        guard next != motif else { return nil }
        let before = motif
        motif = next
        return before
    }
}

/// Подстройка срока по тому, как поливают на самом деле. Сколько воды
/// оставалось в земле в миг полива — в журнале; поливают стабильно при
/// трети и больше — значит, земля у хозяина сохнет быстрее записанного, и
/// срок стоит сократить. Время здесь не годится: сад живёт в ускоренных
/// часах, а журнал — в настоящих.
enum Rhythm {
    /// Меньше — случайность, а не привычка.
    static let enough = 3

    /// Столько последних поливов в счёт: привычки меняются.
    static let window = 6

    /// Поливают раньше, когда в земле остаётся столько, — есть о чём
    /// говорить.
    static let early = 0.25

    /// Новый срок в днях — или пусто, если поливают как записано. Предложение
    /// не повторяется, если его уже отклонили, пока оно то же.
    static func suggest(for plant: Plant, log: [Watering]) -> Double? {
        let left = log.filter { $0.plant == plant.id }
            .compactMap(\.left)
            .suffix(window)
        guard left.count >= enough else { return nil }
        let middle = left.sorted()[left.count / 2]
        guard middle >= early else { return nil }
        let days = max(1, (plant.dryingDays * (1 - middle)).rounded())
        guard days <= plant.dryingDays - 1, days != plant.quiet else {
            return nil
        }
        return days
    }
}
