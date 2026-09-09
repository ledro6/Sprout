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

    /// Сколько разных фигурок в узоре: от одной до четырёх.
    ///
    /// Не набор, а количество: фигурки идут в заданном порядке — росток,
    /// капля, цветок, горшок, — и настройка отвечает на вопрос «докуда».
    /// Выбором вразнобой можно было бы оставить один горшок без ростка, а
    /// узор этого приложения начинается с ростка.
    ///
    /// Двойка по умолчанию: ровно тот узор из макета, что был здесь до
    /// настройки, — росток и капля через одну.
    static let kinds = 1...4
    static let defaultKinds = 2

    /// Пороги напоминания, доли влажности. Двадцать процентов посередине
    /// и по умолчанию: это и есть порог, на котором тревожная тень
    /// краснеет, — см. `Thirst.alarmBelow`.
    static let thresholds: [Double] = [0.1, 0.2, 0.3, 0.4]
    static let defaultThreshold = 0.2

    var theme: Theme {
        didSet { store.set(theme.rawValue, forKey: Key.theme) }
    }

    /// Ставится через `choose(kinds:)`, а не присваиванием.
    ///
    /// Загонять число в границы прямо в наблюдателе нельзя: `@Observable`
    /// превращает свойство в вычисляемое, и присваивание из его же
    /// наблюдателя снова зовёт установщик — рекурсия до переполнения
    /// стека. Проверено падением на прогоне модели.
    private(set) var patternKinds: Int {
        didSet { store.set(patternKinds, forKey: Key.kinds) }
    }

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

    /// Выбрать, сколько фигурок в узоре. Число загоняется в границы
    /// здесь: снаружи его берут из ряда кнопок, но настройка переживает
    /// обновления приложения, а фигурок в нём может стать меньше.
    func choose(kinds: Int) {
        patternKinds = min(max(kinds, Self.kinds.lowerBound),
                           Self.kinds.upperBound)
    }

    @ObservationIgnored private let store: UserDefaults

    private enum Key {
        static let theme = "theme"
        static let kinds = "patternKinds"
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
        // отсутствие и ноль, а нулевого количества фигурок не бывает.
        let saved = store.integer(forKey: Key.kinds)
        patternKinds = Self.kinds.contains(saved) ? saved : Self.defaultKinds
        reminders = store.bool(forKey: Key.reminders)
        let level = store.double(forKey: Key.threshold)
        threshold = Self.thresholds.contains(level) ? level
            : Self.defaultThreshold
    }
}
