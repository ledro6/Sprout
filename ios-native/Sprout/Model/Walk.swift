import Foundation

/// Подсказка на экране: что подсветить и что об этом сказать.
struct Hint: Identifiable, Hashable, Sendable {
    /// Что подсвечивается. Имя — «экран.место»: одно пространство имён на
    /// всё приложение.
    enum Target: String, CaseIterable, Sendable {
        case statsPeriod = "stats.period"
        case statsNow = "stats.now"
        case statsOrrery = "stats.orrery"
        case statsSum = "stats.sum"
        case statsAim = "stats.aim"
        case statsAhead = "stats.ahead"
        case statsPlants = "stats.plants"

        case orreryDial = "orrery.dial"
        case orreryGate = "orrery.gate"
        case orreryCard = "orrery.card"
        case orreryTime = "orrery.time"
        case orreryPlay = "orrery.play"
        case orreryParades = "orrery.parades"

        case bookFigures = "book.figures"
        case bookAim = "book.aim"
        case bookHistory = "book.history"

        case plantPhoto = "plant.photo"
        case plantPour = "plant.pour"
        case plantTools = "plant.tools"
        case plantNotes = "plant.notes"
        case plantDiary = "plant.diary"

        case addPicture = "add.picture"
        case addAbout = "add.about"
        case addHabits = "add.habits"
        case addPlant = "add.plant"

        case profilePerson = "profile.person"
        case profilePlot = "profile.plot"
        case profileRivals = "profile.rivals"
        case profileMore = "profile.more"

        case searchBoard = "search.board"
        case searchRecents = "search.recents"

        case settingsLook = "settings.look"
        case settingsBackdrop = "settings.backdrop"
        case settingsWatering = "settings.watering"
        case settingsAbout = "settings.about"

        case tuningAbout = "tuning.about"
        case tuningHabits = "tuning.habits"
        case tuningTending = "tuning.tending"

        case arHint = "ar.hint"
        case arControls = "ar.controls"

        case tripDates = "trip.dates"
        case tripPlan = "trip.plan"
        case tripActions = "trip.actions"

        case roomsList = "rooms.list"
    }

    let target: Target
    let title: String
    let text: String

    var id: Target { target }
}

/// Экраны с подсказками. Каждый показывает свои один раз, при первом
/// заходе, — дальше по «?» или после «Показать подсказки снова».
enum Walk: String, CaseIterable, Identifiable, Sendable {
    case stats, orrery, book, plant, add, profile, search, settings, tuning,
         ar, trip, rooms

    var id: String { rawValue }

    var hints: [Hint] {
        switch self {
        case .stats:
            [
                Hint(target: .statsPeriod, title: Lang.text("Период"),
                     text: Lang.text("""
                         Неделя, месяц, год или всё время — цифры и графики \
                         ниже пересчитаются.
                         """)),
                Hint(target: .statsNow, title: Lang.text("Сейчас"),
                     text: Lang.text("""
                         Кольцо — сколько растений довольны. Полоска под ним \
                         — влажность каждого, от самого сухого.
                         """)),
                Hint(target: .statsOrrery, title: Lang.text("Планетарий"),
                     text: Lang.text("""
                         Ваш сад как солнечная система: растения кружат по \
                         орбитам полива. Загляните — там можно послушать \
                         месяц.
                         """)),
                Hint(target: .statsSum, title: Lang.text("Итог"),
                     text: Lang.text("""
                         Сколько раз поливали, сколько дней подряд и какая \
                         доля поливов пришлась вовремя.
                         """)),
                Hint(target: .statsAim, title: Lang.text("Точность полива"),
                     text: Lang.text("""
                         Сколько воды оставалось в земле, когда вы поливали. \
                         Оранжевая зона — в самый раз.
                         """)),
                Hint(target: .statsAhead, title: Lang.text("Прогноз"),
                     text: Lang.text("""
                         Скольким растениям понадобится вода в ближайшие дни. \
                         Нажмите на столбик — появятся клички.
                         """)),
                Hint(target: .statsPlants, title: Lang.text("Растения"),
                     text: Lang.text("""
                         Кого поливают чаще всех, а кого дольше всех не \
                         поливали. Нажмите на растение — откроется его \
                         статистика.
                         """)),
            ]
        case .orrery:
            [
                Hint(target: .orreryDial,
                     title: Lang.text("Планеты — ваши растения"),
                     text: Lang.text("""
                         Один круг — один срок полива. Ближние орбиты у тех, \
                         кто сохнет быстро, дальние — у терпеливых.
                         """)),
                Hint(target: .orreryGate, title: Lang.text("Ворота полива"),
                     text: Lang.text("""
                         Планета дошла до ворот — земля высохла, пора \
                         поливать. Политая перелетает их и идёт на новый \
                         круг.
                         """)),
                Hint(target: .orreryCard,
                     title: Lang.text("Нажмите на планету"),
                     text: Lang.text("""
                         Появятся кличка, влажность и срок, а полить можно \
                         прямо отсюда.
                         """)),
                Hint(target: .orreryTime, title: Lang.text("Машина времени"),
                     text: Lang.text("""
                         Ведите ползунок — сад перенесётся на дни вперёд, \
                         если поливать вовремя.
                         """)),
                Hint(target: .orreryPlay, title: Lang.text("Музыка сфер"),
                     text: Lang.text("""
                         Месяц пролетит за двадцать секунд, и каждый полив \
                         прозвучит нотой: ближние планеты поют выше.
                         """)),
                Hint(target: .orreryParades, title: Lang.text("Парады"),
                     text: Lang.text("""
                         Дни, когда воды попросят сразу несколько растений, — \
                         удобно полить всех за один заход.
                         """)),
            ]
        case .book:
            [
                Hint(target: .bookFigures, title: Lang.text("Цифры"),
                     text: Lang.text("""
                         Сколько раз его поливали за период и всего и когда \
                         в последний раз.
                         """)),
                Hint(target: .bookAim, title: Lang.text("Когда поливаете"),
                     text: Lang.text("""
                         При скольких процентах воды в земле вы обычно \
                         берётесь за лейку.
                         """)),
                Hint(target: .bookHistory, title: Lang.text("История"),
                     text: Lang.text("""
                         Каждая точка — полив. Чем выше точка, тем больше \
                         воды ещё было в земле.
                         """)),
            ]
        case .plant:
            [
                Hint(target: .plantPhoto, title: Lang.text("Тень вокруг фото"),
                     text: Lang.text("""
                         Чем суше земля, тем ярче тень: оранжевая — скоро \
                         поливать, красная — пора.
                         """)),
                Hint(target: .plantPour, title: Lang.text("Полить сейчас"),
                     text: Lang.text("""
                         Одно нажатие — и полив записан. Передумали — внизу \
                         появится «Вернуть».
                         """)),
                Hint(target: .plantTools, title: Lang.text("AR и настройки"),
                     text: Lang.text("""
                         Посмотрите на растение у себя в комнате или \
                         поменяйте кличку, вид и срок полива.
                         """)),
                Hint(target: .plantNotes, title: Lang.text("Заметки"),
                     text: Lang.text("""
                         Пишите, что важно: где любит стоять, чем \
                         подкармливали.
                         """)),
                Hint(target: .plantDiary, title: Lang.text("Поливы"),
                     text: Lang.text("""
                         Все поливы этого растения. Ошибочную запись удалит \
                         долгое нажатие.
                         """)),
            ]
        case .add:
            [
                Hint(target: .addPicture, title: Lang.text("Снимок"),
                     text: Lang.text("""
                         Сфотографируйте растение — телефон попробует узнать \
                         вид и соберёт модель для AR.
                         """)),
                Hint(target: .addAbout, title: Lang.text("Кличка и вид"),
                     text: Lang.text("""
                         Придумайте имя. По виду подставится обычный срок \
                         полива.
                         """)),
                Hint(target: .addHabits, title: Lang.text("Комната и полив"),
                     text: Lang.text("""
                         Где стоит растение и раз в сколько дней его \
                         поливать — барабан крутится пальцем.
                         """)),
                Hint(target: .addPlant, title: Lang.text("Посадить"),
                     text: Lang.text("""
                         Готово? Растение появится на главной, в выбранной \
                         комнате.
                         """)),
            ]
        case .profile:
            [
                Hint(target: .profilePerson, title: Lang.text("Хозяин"),
                     text: Lang.text("""
                         Назовитесь — приложение будет здороваться по имени.
                         """)),
                Hint(target: .profilePlot, title: Lang.text("Сад"),
                     text: Lang.text("""
                         Сколько у вас растений и комнат и сколько дней вы \
                         ухаживаете за садом.
                         """)),
                Hint(target: .profileRivals, title: Lang.text("Друзья"),
                     text: Lang.text("""
                         «Позвать» отправит другу ваш счёт. Его ответ \
                         вставьте кнопкой «Вставить» — и он встанет в \
                         таблицу.
                         """)),
                Hint(target: .profileMore, title: Lang.text("Ещё"),
                     text: Lang.text("""
                         Сохраните сад в файл или перенесите его с другого \
                         телефона.
                         """)),
            ]
        case .search:
            [
                Hint(target: .searchBoard, title: Lang.text("Поиск"),
                     text: Lang.text("""
                         Поле поиска — внизу, у панели вкладок. Ищет по \
                         кличке, виду и заметкам.
                         """)),
                Hint(target: .searchRecents,
                     title: Lang.text("Недавние запросы"),
                     text: Lang.text("""
                         Нажмите, чтобы искать снова. Долгое нажатие — \
                         забыть запрос.
                         """)),
            ]
        case .settings:
            [
                Hint(target: .settingsLook, title: Lang.text("Оформление"),
                     text: Lang.text("""
                         Тема, вид карточек и порядок растений на главной.
                         """)),
                Hint(target: .settingsBackdrop, title: Lang.text("Фон"),
                     text: Lang.text("""
                         Фигурки узора, его цвет и цвет волны после полива.
                         """)),
                Hint(target: .settingsWatering, title: Lang.text("Полив"),
                     text: Lang.text("""
                         Напоминания и поправка срока на время года.
                         """)),
                Hint(target: .settingsAbout, title: Lang.text("О приложении"),
                     text: Lang.text("""
                         Знакомство, словарик и подсказки — их можно \
                         показать снова.
                         """)),
            ]
        case .tuning:
            [
                Hint(target: .tuningAbout, title: Lang.text("Кличка и вид"),
                     text: Lang.text("""
                         Поменяли вид — модель для AR пересоберётся сама.
                         """)),
                Hint(target: .tuningHabits, title: Lang.text("Срок полива"),
                     text: Lang.text("""
                         Покрутите барабан — ниже видно, как новый срок \
                         ляжет на карточку.
                         """)),
                Hint(target: .tuningTending,
                     title: Lang.text("Подкормка и пересадка"),
                     text: Lang.text("""
                         Приложение напомнит, когда пора удобрять и \
                         пересаживать.
                         """)),
            ]
        case .ar:
            [
                Hint(target: .arHint, title: Lang.text("Что делать"),
                     text: Lang.text("""
                         Здесь всегда написан следующий шаг: навести камеру, \
                         поставить растение, выбрать его.
                         """)),
                Hint(target: .arControls, title: Lang.text("Кнопки"),
                     text: Lang.text("""
                         «Полить» зовёт лейку: полив засчитается, когда вода \
                         коснётся земли.
                         """)),
            ]
        case .trip:
            [
                Hint(target: .tripDates, title: Lang.text("Даты"),
                     text: Lang.text("""
                         Когда уезжаете и когда вернётесь.
                         """)),
                Hint(target: .tripPlan, title: Lang.text("Кого полить соседу"),
                     text: Lang.text("""
                         Кто без вас не дождётся и в какие дни его полить. \
                         Остальные потерпят.
                         """)),
                Hint(target: .tripActions,
                     title: Lang.text("Перед отъездом"),
                     text: Lang.text("""
                         Полейте всех разом и отправьте соседу памятку.
                         """)),
            ]
        case .rooms:
            [
                Hint(target: .roomsList, title: Lang.text("Комнаты"),
                     text: Lang.text("""
                         Имя правится прямо в строке, порядок — за ручку \
                         справа, удалить — смахнуть влево.
                         """)),
            ]
        }
    }
}
