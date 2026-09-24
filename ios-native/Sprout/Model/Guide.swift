import Foundation

/// Слова приложения, которые понятны не всем, — с пояснением простыми
/// словами. Видны по «?» рядом со словом и списком в «Словарике».
enum Term: String, CaseIterable, Identifiable, Sendable {
    case ar, model, moisture, period, seasons, rhythm, feeding, repotting,
         reminders, parallax, sway, wave, frolic, lock, trip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ar: Lang.text("AR — дополненная реальность")
        case .model: Lang.text("Модель растения")
        case .moisture: Lang.text("Влажность")
        case .period: Lang.text("Срок полива")
        case .seasons: Lang.text("Время года")
        case .rhythm: Lang.text("Ритм полива")
        case .feeding: Lang.text("Подкормка")
        case .repotting: Lang.text("Пересадка")
        case .reminders: Lang.text("Напоминание о поливе")
        case .parallax: Lang.text("Узор за наклоном")
        case .sway: Lang.text("Фигурки плывут порознь")
        case .wave: Lang.text("Волна")
        case .frolic: Lang.text("Кутерьма")
        case .lock: Lang.text("Замок")
        case .trip: Lang.text("Уезжаю")
        }
    }

    var meaning: String {
        switch self {
        case .ar:
            Lang.text("""
                Камера показывает вашу комнату, а приложение ставит в неё \
                объёмное растение. Его можно повернуть, растянуть и полить \
                лейкой.
                """)
        case .model:
            Lang.text("""
                Объёмная копия растения для AR. Приложение собирает её само — \
                по виду или по снимку. Пока собирается, на карточке бегут \
                проценты.
                """)
        case .moisture:
            Lang.text("""
                Сколько воды осталось в земле. После полива — сто процентов, \
                потом земля подсыхает. Чем суше, тем ярче тень вокруг \
                карточки.
                """)
        case .period:
            Lang.text("""
                Раз в сколько дней растение поливают — примерно за столько \
                земля высыхает. Меняется в настройках растения.
                """)
        case .seasons:
            Lang.text("""
                Зимой земля сохнет медленнее, летом — быстрее. Если \
                включено, срок полива подстраивается сам.
                """)
        case .rhythm:
            Lang.text("""
                Если вы поливаете раньше срока, приложение заметит и \
                предложит сделать срок короче.
                """)
        case .feeding:
            Lang.text("""
                Удобрение, разведённое в воде для полива. Нужно раз в \
                несколько недель, пока растение растёт.
                """)
        case .repotting:
            Lang.text("""
                Переезд в горшок побольше со свежей землёй. Обычно раз в \
                год-два, весной.
                """)
        case .reminders:
            Lang.text("""
                Уведомление на телефон, когда земля у растения подсохла \
                ниже выбранного порога.
                """)
        case .parallax:
            Lang.text("""
                Узор на фоне чуть сдвигается, когда вы наклоняете телефон, — \
                будто лежит глубже экрана.
                """)
        case .sway:
            Lang.text("""
                При наклоне каждая фигурка узора движется со своей \
                скоростью, будто плывёт в воде.
                """)
        case .wave:
            Lang.text("""
                После полива по узору бежит цветная волна — так видно, что \
                полив засчитан.
                """)
        case .frolic:
            Lang.text("""
                Потрясите телефон — фигурки узора разлетятся и соберутся \
                снова. Просто для радости.
                """)
        case .lock:
            Lang.text("""
                Сад открывается только по Face ID или код-паролю телефона — \
                чужие не посмотрят.
                """)
        case .trip:
            Lang.text("""
                План на отпуск: полить всех перед отъездом и отправить \
                соседу памятку, кого и когда поливать.
                """)
        }
    }

    var icon: String {
        switch self {
        case .ar: "arkit"
        case .model: "cube"
        case .moisture: "drop"
        case .period: "calendar"
        case .seasons: "leaf"
        case .rhythm: "calendar.badge.clock"
        case .feeding: "sparkles"
        case .repotting: "arrow.up.bin"
        case .reminders: "bell"
        case .parallax: "rotate.3d"
        case .sway: "water.waves"
        case .wave: "wave.3.right"
        case .frolic: "hands.and.sparkles"
        case .lock: "lock"
        case .trip: "airplane.departure"
        }
    }
}

/// Знакомство при первом запуске: как обращаться с приложением — коротко,
/// по странице на жест или кнопку. Строки берутся заново при каждом
/// обращении: язык мог смениться.
enum Tour {
    struct Page: Identifiable, Equatable {
        let id: Int
        let icon: String
        let title: String
        let text: String
    }

    static var pages: [Page] {
        [
            Page(id: 0, icon: "leaf.fill",
                 title: Lang.text("Это ваш сад"),
                 text: Lang.text("""
                     Каждая карточка — растение. Число рядом с кличкой — \
                     сколько воды осталось в земле: чем суше, тем ярче тень \
                     вокруг.
                     """)),
            Page(id: 1, icon: "hand.tap.fill",
                 title: Lang.text("Нажмите на карточку"),
                 text: Lang.text("""
                     Откроется растение: большая кнопка «Полить сейчас», \
                     история поливов, заметки и настройки.
                     """)),
            Page(id: 2, icon: "hand.point.up.left.fill",
                 title: Lang.text("Подержите палец"),
                 text: Lang.text("""
                     Появится меню: полить, переименовать, перевезти в \
                     другую комнату. Держите дольше или ведите пальцем — \
                     карточки закачаются, и их можно переставить.
                     """)),
            Page(id: 3, icon: "square.grid.2x2",
                 title: Lang.text("Кнопки вокруг"),
                 text: Lang.text("""
                     Сверху — комнаты, вид и порядок карточек, «Сад в AR», \
                     «Уезжаю…» и настройки. Внизу — вкладки: во «Добавить» \
                     сажают новое растение.
                     """)),
            Page(id: 4, icon: "arkit",
                 title: Lang.text("Растение у вас в комнате"),
                 text: Lang.text("""
                     AR — дополненная реальность: камера показывает комнату, \
                     а в ней — объёмное растение. Модель для него \
                     собирается сама, проценты — на карточке.
                     """)),
            Page(id: 5, icon: "questionmark.circle",
                 title: Lang.text("Непонятное слово?"),
                 text: Lang.text("""
                     Нажмите «?» рядом с ним — объясним простыми словами. \
                     Все слова собраны в словарике в настройках.
                     """)),
        ]
    }
}
