import Foundation
import Observation

/// Настройки приложения. Не в окружении, а общим экземпляром: их читает и фон
/// изнутри замыкания холста, куда `@Environment` не дотягивается. В
/// `UserDefaults`: это несколько чисел, нужных до первого экрана, а не данные
/// сада.
@Observable
final class Settings {
    static let shared = Settings()

    /// «За системой» по умолчанию: обе половины палитры живут в `Palette`.
    enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: Lang.text("Как в системе")
            case .light: Lang.text("Светлая")
            case .dark: Lang.text("Тёмная")
            }
        }

        /// Для ряда из трёх кнопок, где «Как в системе» не помещается.
        var short: String {
            switch self {
            case .system: Lang.text("Система")
            case .light: Lang.text("Светлая")
            case .dark: Lang.text("Тёмная")
            }
        }

        var icon: String {
            switch self {
            case .system: "iphone"
            case .light: "sun.max.fill"
            case .dark: "moon.fill"
            }
        }
    }

    /// Как лежат растения. Плитка по умолчанию — в ней видно само растение;
    /// список вдвое плотнее.
    enum Look: String, CaseIterable, Identifiable {
        case grid, list

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .grid: "square.grid.2x2"
            case .list: "list.bullet"
            }
        }

        var title: String {
            switch self {
            case .grid: Lang.text("Плиткой")
            case .list: Lang.text("Списком")
            }
        }
    }

    /// Порядок растений. Сортировки ручной порядок не трогают — вернёшься к
    /// «Вручную», и всё стоит, как стояло.
    enum Order: String, CaseIterable, Identifiable {
        case manual, thirsty, name, newest

        var id: String { rawValue }

        var title: String {
            switch self {
            case .manual: Lang.text("Вручную")
            case .thirsty: Lang.text("Сначала сухие")
            case .name: Lang.text("По имени")
            case .newest: Lang.text("Сначала новые")
            }
        }

        var icon: String {
            switch self {
            case .manual: "hand.draw"
            case .thirsty: "drop"
            case .name: "textformat"
            case .newest: "calendar"
            }
        }

        /// Равные остаются в ручном порядке, иначе менялись бы местами от
        /// пересборки к пересборке. «Сначала сухие» — по дням до полива, а не
        /// по процентам: 20% у папоротника — день, у кактуса — две недели.
        func arrange(_ plants: [Plant]) -> [Plant] {
            let lined = Array(plants.enumerated())
            let sorted: [(offset: Int, element: Plant)]
            switch self {
            case .manual:
                return plants
            case .thirsty:
                sorted = lined.sorted { a, b in
                    let x = a.element.moisture * a.element.dryingDays
                    let y = b.element.moisture * b.element.dryingDays
                    return x != y ? x < y : a.offset < b.offset
                }
            case .name:
                sorted = lined.sorted { a, b in
                    switch a.element.name
                        .localizedStandardCompare(b.element.name) {
                    case .orderedAscending: true
                    case .orderedDescending: false
                    case .orderedSame: a.offset < b.offset
                    }
                }
            case .newest:
                sorted = lined.sorted { a, b in
                    let x = Self.day(a.element.addedOn)
                    let y = Self.day(b.element.addedOn)
                    return x != y ? x > y : a.offset < b.offset
                }
            }
            return sorted.map(\.element)
        }

        private static func day(_ date: DateComponents) -> Int {
            (date.year ?? 0) * 10_000 + (date.month ?? 0) * 100
                + (date.day ?? 0)
        }
    }

    /// Номера — по порядку в `SproutShapes.pieces`.
    static let shapeCount = 4

    /// Росток и капля — узор макета.
    static let defaultShapes: Set<Int> = [0, 1]

    /// Узор и волна — двумя настройками: узор — фон, волна — событие, и
    /// различаться они должны и цветом.
    var patternTint: Tint {
        didSet { store.set(patternTint.rawValue, forKey: Key.patternTint) }
    }

    var waveTint: Tint {
        didSet { store.set(waveTint.rawValue, forKey: Key.waveTint) }
    }

    /// Своей настройкой: кружок — про человека, а не про фон.
    var avatarTint: Tint {
        didSet { store.set(avatarTint.rawValue, forKey: Key.avatarTint) }
    }

    /// Фото хозяина — имя файла среди снимков, см. `Shots`; нет — кружок
    /// с буквой цвета `avatarTint`.
    var avatarShot: String? {
        didSet { store.set(avatarShot, forKey: Key.avatarShot) }
    }

    /// Двадцать процентов по умолчанию — порог, на котором тень краснеет, см.
    /// `Thirst.alarmBelow`. Выбирается барабаном — любым целым процентом.
    static let thresholds = 1 ... 99
    static let defaultThreshold = 0.2

    var theme: Theme {
        didSet { store.set(theme.rawValue, forKey: Key.theme) }
    }

    /// Вид и порядок — одни на главную и поиск.
    var look: Look {
        didSet { store.set(look.rawValue, forKey: Key.look) }
    }

    var order: Order {
        didSet { store.set(order.rawValue, forKey: Key.order) }
    }

    /// Набор, а не количество: каждая фигурка включается сама по себе.
    /// Ставится через `toggle(shape:)` — присваивание из наблюдателя звало бы
    /// установщик снова, и `@Observable` уходил в рекурсию.
    private(set) var shapes: Set<Int> {
        didSet { store.set(Self.mask(of: shapes), forKey: Key.shapes) }
    }

    /// По порядку — чтобы при одном выборе узор всегда был одним и тем же.
    var chosen: [Int] { shapes.sorted() }

    /// Сила отклика в руке, 0…1; ноль — отклика нет. Своя настройка:
    /// «Системная вибрация» не гасит рисунки `CoreHaptics`, а весь отклик
    /// приложения — они.
    var hapticStrength: Double {
        didSet { store.set(hapticStrength, forKey: Key.strength) }
    }

    var haptics: Bool { hapticStrength > 0 }

    /// Беззвучный режим телефона звуки глушит и так; это — чтобы молчали и
    /// со включённым звонком.
    var sounds: Bool {
        didSet { store.set(!sounds, forKey: Key.muted) }
    }

    /// Своя, а не «Уменьшение движения»: то выключает всё, а мешать может
    /// один фон. Датчик не гасится — тряску выключать не просили.
    var parallax: Bool {
        didSet { store.set(!parallax, forKey: Key.stillPattern) }
    }

    /// Разъезд фигурок — отдельно от параллакса; выключен — узор едет куском.
    var sway: Bool {
        didSet { store.set(!sway, forKey: Key.stiffShapes) }
    }

    /// Срок полива длиннее зимой и короче летом, см. `Season`.
    var seasons: Bool {
        didSet { store.set(!seasons, forKey: Key.flatYear) }
    }

    /// Снежинки, листья и гирлянда в узоре, см. `Motif`.
    var seasonalPattern: Bool {
        didSet { store.set(!seasonalPattern, forKey: Key.plainPattern) }
    }

    /// Разрешение спрашивает экран настроек, когда включают переключатель.
    var reminders: Bool {
        didSet { store.set(reminders, forKey: Key.reminders) }
    }

    /// Сроки в Календаре телефона, см. `Agenda`. Доступ к календарю — так
    /// же, по переключателю.
    var calendar: Bool {
        didSet { store.set(calendar, forKey: Key.calendar) }
    }

    var threshold: Double {
        didSet { store.set(threshold, forKey: Key.threshold) }
    }

    /// Знакомство при первом запуске уже показано — см. `Tour`. Повторить
    /// его можно из настроек.
    var toured: Bool {
        didSet { store.set(toured, forKey: Key.toured) }
    }

    /// Экраны, чьи подсказки уже показаны, — см. `Walk`. Показать снова —
    /// значит забыть их все.
    private(set) var walked: Set<String> {
        didSet { store.set(walked.sorted(), forKey: Key.walked) }
    }

    func seen(_ walk: Walk) -> Bool { walked.contains(walk.rawValue) }

    /// Который по счёту запуск. Подсказки экранов сами показываются только в
    /// первый: во второй раз хозяин уже знает, где что.
    private(set) var launches: Int {
        didSet { store.set(launches, forKey: Key.launches) }
    }

    var firstRun: Bool { launches <= 1 }

    /// Зовётся один раз, при старте приложения.
    func launched() { launches += 1 }

    func mark(_ walk: Walk) { walked.insert(walk.rawValue) }

    func rewalk() { walked = [] }

    /// Последнюю не выключить: пустой набор — голый фон. Отвечает, изменилось
    /// ли что-нибудь, — по нему экран решает, пускать ли всходы.
    @discardableResult
    func toggle(shape: Int) -> Bool {
        guard (0 ..< Self.shapeCount).contains(shape) else { return false }
        if shapes.contains(shape) {
            guard shapes.count > 1 else { return false }
            shapes.remove(shape)
        } else {
            shapes.insert(shape)
        }
        return true
    }

    /// В `UserDefaults` — битовой маской: четыре фигурки в четыре бита.
    private static func mask(of shapes: Set<Int>) -> Int {
        shapes.reduce(0) { $0 | (1 << $1) }
    }

    private static func shapes(from mask: Int) -> Set<Int> {
        Set((0 ..< shapeCount).filter { mask & (1 << $0) != 0 })
    }

    @ObservationIgnored private let store: UserDefaults

    private enum Key {
        static let theme = "theme"
        static let look = "plantLook"
        static let order = "plantOrder"
        /// Прежний ключ — количество фигурок; читается ради тех, у кого он
        /// сохранён.
        static let kinds = "patternKinds"
        static let shapes = "patternShapes"
        static let reminders = "reminders"
        static let calendar = "calendarSync"
        static let threshold = "remindThreshold"
        static let patternTint = "patternTint"
        static let waveTint = "waveTint"
        static let avatarTint = "avatarTint"
        static let avatarShot = "avatarShot"
        /// Прежний переключатель, наоборот — «без отклика». Читается, пока
        /// силы не задали: выключивший отклик не должен почувствовать его
        /// снова.
        static let hushed = "hushedHaptics"
        static let strength = "hapticStrength"
        /// Тоже наоборот.
        static let muted = "mutedSounds"
        /// Тоже наоборот.
        static let stillPattern = "stillPattern"
        static let stiffShapes = "stiffShapes"
        /// Тоже наоборот: время года учитывается по умолчанию.
        static let flatYear = "ignoreSeasons"
        /// Тоже наоборот: узор по времени года — по умолчанию.
        static let plainPattern = "plainPattern"
        static let toured = "toured"
        static let walked = "walkedScreens"
        static let launches = "launches"
    }

    /// Отсутствие ключа ловим отдельно: `UserDefaults` отвечает нулём, а ноль
    /// — зелёный, и волна сбросилась бы на зелёную.
    private static func tint(_ store: UserDefaults, _ key: String) -> Tint? {
        guard store.object(forKey: key) != nil else { return nil }
        return Tint(rawValue: store.integer(forKey: key))
    }

    /// Хранилище снаружи — ради проверок.
    init(store: UserDefaults = .standard) {
        self.store = store
        theme = Theme(rawValue: store.string(forKey: Key.theme) ?? "")
            ?? .system
        look = Look(rawValue: store.string(forKey: Key.look) ?? "") ?? .grid
        order = Order(rawValue: store.string(forKey: Key.order) ?? "")
            ?? .manual
        // Ноль — «ключа нет»: пустого набора фигурок не бывает.
        let mask = store.integer(forKey: Key.shapes)
        if mask != 0 {
            shapes = Self.shapes(from: mask)
        } else {
            // Настройка старого вида — переводим в набор, чтобы узор не
            // сбросился.
            let count = store.integer(forKey: Key.kinds)
            shapes = (1 ... Self.shapeCount).contains(count)
                ? Set(0 ..< count) : Self.defaultShapes
        }
        patternTint = Self.tint(store, Key.patternTint) ?? Tint.defaultPattern
        waveTint = Self.tint(store, Key.waveTint) ?? Tint.defaultWave
        avatarTint = Self.tint(store, Key.avatarTint) ?? Tint.defaultAvatar
        avatarShot = store.string(forKey: Key.avatarShot)
        if store.object(forKey: Key.strength) != nil {
            hapticStrength = min(max(store.double(forKey: Key.strength), 0), 1)
        } else {
            hapticStrength = store.bool(forKey: Key.hushed) ? 0 : 1
        }
        sounds = !store.bool(forKey: Key.muted)
        parallax = !store.bool(forKey: Key.stillPattern)
        sway = !store.bool(forKey: Key.stiffShapes)
        seasons = !store.bool(forKey: Key.flatYear)
        seasonalPattern = !store.bool(forKey: Key.plainPattern)
        reminders = store.bool(forKey: Key.reminders)
        calendar = store.bool(forKey: Key.calendar)
        let level = (store.double(forKey: Key.threshold) * 100).rounded()
        threshold = Self.thresholds.contains(Int(level)) ? level / 100
            : Self.defaultThreshold
        toured = store.bool(forKey: Key.toured)
        walked = Set(store.stringArray(forKey: Key.walked) ?? [])
        // Счётчика не было, а знакомство уже прошло — сад старый: первым
        // этот запуск не считаем.
        launches = max(store.integer(forKey: Key.launches),
                       store.bool(forKey: Key.toured) ? 1 : 0)
    }
}
