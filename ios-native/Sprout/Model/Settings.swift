import Foundation
import Observation

/// Настройки приложения: тема, узор на фоне, напоминания о поливе.
///
/// Один на приложение, как `Garden`. Сад передаётся через окружение — он
/// у каждого свой и его правят с экранов, — а настройки читает и фон, и
/// подложка под вырезом, и корень приложения, то есть места, куда
/// окружение не дотягивается: узор рисуется внутри замыкания холста, и
/// протащить туда значение через `@Environment` нечем.
///
/// Пишутся в `UserDefaults`, а не в файл рядом с садом. Это ровно то, для
/// чего он есть: несколько чисел, которые нужно помнить между запусками и
/// прочесть до того, как соберётся первый экран. Сад же — данные хозяина,
/// им место в Documents и в резервной копии.
@Observable
final class Settings {
    static let shared = Settings()

    /// Тема оформления: за системой, светлая или тёмная.
    ///
    /// «За системой» первая и она же по умолчанию: приложение и рисовалось
    /// так, обе половины палитры живут в `Palette`, и до этой настройки
    /// оно всегда шло за телефоном.
    enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "Как в системе"
            case .light: "Светлая"
            case .dark: "Тёмная"
            }
        }

        /// Короткая подпись — для ряда из трёх кнопок, где места на
        /// «Как в системе» нет.
        var short: String {
            switch self {
            case .system: "Система"
            case .light: "Светлая"
            case .dark: "Тёмная"
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

    /// Сколько всего фигурок нарисовано — росток, капля, цветок, горшок.
    /// Их номера совпадают с порядком в `SproutShapes.pieces`.
    static let shapeCount = 4

    /// Что в узоре, пока не выбрали другое: росток и капля — ровно тот
    /// узор из макета, что был здесь до всякой настройки.
    static let defaultShapes: Set<Int> = [0, 1]

    /// Пороги напоминания, доли влажности. Двадцать процентов посередине
    /// и по умолчанию: это и есть порог, на котором тревожная тень
    /// краснеет, — см. `Thirst.alarmBelow`.
    static let thresholds: [Double] = [0.1, 0.2, 0.3, 0.4]
    static let defaultThreshold = 0.2

    var theme: Theme {
        didSet { store.set(theme.rawValue, forKey: Key.theme) }
    }

    /// Какие фигурки в узоре, номерами.
    ///
    /// Набор, а не количество. Сперва настройка отвечала на вопрос
    /// «докуда идти по ряду» — фигурки включались слева направо, и
    /// оставить одну каплю без ростка было нельзя. Причина была та, что
    /// узор этого приложения начинается с ростка; но это довод за то,
    /// каким узор приходит по умолчанию, а не за то, каким его нельзя
    /// сделать. Теперь каждая фигурка включается сама по себе.
    ///
    /// Ставится через `toggle(shape:)`: присваивание из наблюдателя
    /// снова звало бы установщик — `@Observable` превращает свойство в
    /// вычисляемое, и выходит рекурсия до переполнения стека. Проверено
    /// падением на прогоне модели.
    private(set) var shapes: Set<Int> {
        didSet { store.set(Self.mask(of: shapes), forKey: Key.shapes) }
    }

    /// Выбранные фигурки по порядку. Узор раскладывает их именно так —
    /// росток раньше капли, капля раньше цветка, — чтобы при одном и том
    /// же выборе узор всегда был одним и тем же.
    var chosen: [Int] { shapes.sorted() }

    /// Напоминать ли о поливе. Само разрешение на уведомления спрашивает
    /// экран настроек — в тот миг, когда переключатель включают, а не при
    /// запуске: спрашивать до того, как человек попросил, невежливо, и
    /// отказ потом уже не переспросишь.
    var reminders: Bool {
        didSet { store.set(reminders, forKey: Key.reminders) }
    }

    /// При какой влажности будить хозяина.
    var threshold: Double {
        didSet { store.set(threshold, forKey: Key.threshold) }
    }

    /// Включить или выключить фигурку.
    ///
    /// Последнюю выключить нельзя, и это не придирка: пустой набор — это
    /// голый фон, а узор здесь не украшение, а сам фон и есть. Нажатие на
    /// единственную включённую поэтому ничего не делает — так же, как
    /// нажатие на уже выбранную тему.
    func toggle(shape: Int) {
        guard (0 ..< Self.shapeCount).contains(shape) else { return }
        if shapes.contains(shape) {
            guard shapes.count > 1 else { return }
            shapes.remove(shape)
        } else {
            shapes.insert(shape)
        }
    }

    /// Набор в число и обратно: в `UserDefaults` кладётся битовая маска.
    ///
    /// Маской, а не списком номеров: список пришлось бы кодировать и
    /// разбирать, а маска — то же самое одним числом, которое ключ и так
    /// умеет хранить. Четыре фигурки укладываются в четыре бита.
    private static func mask(of shapes: Set<Int>) -> Int {
        shapes.reduce(0) { $0 | (1 << $1) }
    }

    private static func shapes(from mask: Int) -> Set<Int> {
        Set((0 ..< shapeCount).filter { mask & (1 << $0) != 0 })
    }

    @ObservationIgnored private let store: UserDefaults

    private enum Key {
        static let theme = "theme"
        /// Прежний ключ — количество фигурок. Читается один раз, ради
        /// тех, у кого настройка уже сохранена.
        static let kinds = "patternKinds"
        static let shapes = "patternShapes"
        static let reminders = "reminders"
        static let threshold = "remindThreshold"
    }

    /// Хранилище задаётся снаружи только ради проверок: им нужно своё,
    /// чтобы не топтаться в настройках самого приложения.
    init(store: UserDefaults = .standard) {
        self.store = store
        theme = Theme(rawValue: store.string(forKey: Key.theme) ?? "")
            ?? .system
        // Ноль здесь значит «ключа нет»: `UserDefaults` не различает
        // отсутствие и ноль, а пустого набора фигурок не бывает.
        let mask = store.integer(forKey: Key.shapes)
        if mask != 0 {
            shapes = Self.shapes(from: mask)
        } else {
            // Настройка старого вида — «сколько фигурок слева направо».
            // Переводим её в набор, чтобы у тех, кто уже выбирал, узор не
            // сбросился на умолчание.
            let count = store.integer(forKey: Key.kinds)
            shapes = (1 ... Self.shapeCount).contains(count)
                ? Set(0 ..< count) : Self.defaultShapes
        }
        reminders = store.bool(forKey: Key.reminders)
        let level = store.double(forKey: Key.threshold)
        threshold = Self.thresholds.contains(level) ? level
            : Self.defaultThreshold
    }
}
