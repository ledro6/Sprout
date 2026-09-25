package com.ledro6.sprout.model

/** Подсказка на экране: что подсветить и что об этом сказать. */
data class Hint(val target: Target, val title: String, val text: String) {
    /** Что подсвечивается: «экран.место». */
    enum class Target(val raw: String) {
        STATS_PERIOD("stats.period"), STATS_NOW("stats.now"), STATS_ORRERY("stats.orrery"),
        STATS_SUM("stats.sum"), STATS_AIM("stats.aim"), STATS_CALENDAR("stats.calendar"),
        STATS_AHEAD("stats.ahead"), STATS_PLANTS("stats.plants"),
        ORRERY_DIAL("orrery.dial"), ORRERY_GATE("orrery.gate"), ORRERY_CARD("orrery.card"),
        ORRERY_TIME("orrery.time"), ORRERY_PLAY("orrery.play"), ORRERY_PARADES("orrery.parades"),
        BOOK_FIGURES("book.figures"), BOOK_AIM("book.aim"), BOOK_HISTORY("book.history"),
        PLANT_PHOTO("plant.photo"), PLANT_POUR("plant.pour"), PLANT_TOOLS("plant.tools"),
        PLANT_NOTES("plant.notes"), PLANT_DIARY("plant.diary"),
        ADD_PICTURE("add.picture"), ADD_ABOUT("add.about"), ADD_HABITS("add.habits"),
        ADD_PLANT("add.plant"),
        PROFILE_PERSON("profile.person"), PROFILE_PLOT("profile.plot"),
        PROFILE_RIVALS("profile.rivals"), PROFILE_MORE("profile.more"),
        SEARCH_BOARD("search.board"), SEARCH_RECENTS("search.recents"),
        SETTINGS_LOOK("settings.look"), SETTINGS_BACKDROP("settings.backdrop"),
        SETTINGS_WATERING("settings.watering"), SETTINGS_ABOUT("settings.about"),
        TUNING_ABOUT("tuning.about"), TUNING_HABITS("tuning.habits"), TUNING_TENDING("tuning.tending"),
        AR_HINT("ar.hint"), AR_CONTROLS("ar.controls"),
        TRIP_DATES("trip.dates"), TRIP_PLAN("trip.plan"), TRIP_ACTIONS("trip.actions"),
        ROOMS_LIST("rooms.list"),
    }
}

/**
 * Экраны с подсказками. Каждый показывает свои один раз, при первом заходе,
 * — дальше по «?» или после «Показать подсказки снова».
 */
enum class Walk(val raw: String) {
    STATS("stats"), ORRERY("orrery"), BOOK("book"), PLANT("plant"), ADD("add"),
    PROFILE("profile"), SEARCH("search"), SETTINGS("settings"), TUNING("tuning"),
    AR("ar"), TRIP("trip"), ROOMS("rooms");

    val hints: List<Hint>
        get() = when (this) {
            STATS -> listOf(
                Hint(
                    Hint.Target.STATS_PERIOD, Lang.text("Период"),
                    Lang.text("Неделя, месяц, год или всё время — цифры и графики ниже пересчитаются."),
                ),
                Hint(
                    Hint.Target.STATS_NOW, Lang.text("Сейчас"),
                    Lang.text(
                        "Кольцо — сколько растений довольны. Полоска под ним — влажность " +
                            "каждого, от самого сухого.",
                    ),
                ),
                Hint(
                    Hint.Target.STATS_ORRERY, Lang.text("Планетарий"),
                    Lang.text(
                        "Ваш сад как солнечная система: растения кружат по орбитам полива. " +
                            "Загляните — там можно послушать месяц.",
                    ),
                ),
                Hint(
                    Hint.Target.STATS_SUM, Lang.text("Итог"),
                    Lang.text(
                        "Сколько раз поливали, сколько дней подряд и какая доля поливов " +
                            "пришлась вовремя.",
                    ),
                ),
                Hint(
                    Hint.Target.STATS_AIM, Lang.text("Точность полива"),
                    Lang.text(
                        "Сколько воды оставалось в земле, когда вы поливали. Оранжевая зона — " +
                            "в самый раз.",
                    ),
                ),
                Hint(
                    Hint.Target.STATS_CALENDAR, Lang.text("Календарь поливов"),
                    Lang.text(
                        "Квадрат — день за последние четыре месяца: чем гуще цвет, тем больше " +
                            "поливов. Нажмите на квадрат — появится дата.",
                    ),
                ),
                Hint(
                    Hint.Target.STATS_AHEAD, Lang.text("Прогноз"),
                    Lang.text(
                        "Скольким растениям понадобится вода в ближайшие дни. Нажмите на " +
                            "столбик — появятся клички.",
                    ),
                ),
                Hint(
                    Hint.Target.STATS_PLANTS, Lang.text("Растения"),
                    Lang.text(
                        "Кого поливают чаще всех, а кого дольше всех не поливали. Нажмите на " +
                            "растение — откроется его статистика.",
                    ),
                ),
            )
            ORRERY -> listOf(
                Hint(
                    Hint.Target.ORRERY_DIAL, Lang.text("Планеты — ваши растения"),
                    Lang.text(
                        "Один круг — один срок полива. Ближние орбиты у тех, кто сохнет " +
                            "быстро, дальние — у терпеливых.",
                    ),
                ),
                Hint(
                    Hint.Target.ORRERY_GATE, Lang.text("Ворота полива"),
                    Lang.text(
                        "Планета дошла до ворот — земля высохла, пора поливать. Политая " +
                            "проходит сквозь них и идёт на новый круг.",
                    ),
                ),
                Hint(
                    Hint.Target.ORRERY_CARD, Lang.text("Нажмите на планету"),
                    Lang.text("Появятся кличка, влажность и срок, а полить можно прямо отсюда."),
                ),
                Hint(
                    Hint.Target.ORRERY_TIME, Lang.text("Машина времени"),
                    Lang.text(
                        "Ведите ползунок — сад перенесётся на дни вперёд, если поливать вовремя.",
                    ),
                ),
                Hint(
                    Hint.Target.ORRERY_PLAY, Lang.text("Музыка сфер"),
                    Lang.text(
                        "Месяц пролетит за двадцать секунд, и каждый полив прозвучит нотой: " +
                            "ближние планеты поют выше.",
                    ),
                ),
                Hint(
                    Hint.Target.ORRERY_PARADES, Lang.text("Парады"),
                    Lang.text(
                        "Дни, когда воды попросят сразу несколько растений, — удобно полить " +
                            "всех за один заход.",
                    ),
                ),
            )
            BOOK -> listOf(
                Hint(
                    Hint.Target.BOOK_FIGURES, Lang.text("Цифры"),
                    Lang.text("Сколько раз его поливали за период и всего и когда в последний раз."),
                ),
                Hint(
                    Hint.Target.BOOK_AIM, Lang.text("Когда поливаете"),
                    Lang.text("При скольких процентах воды в земле вы обычно берётесь за лейку."),
                ),
                Hint(
                    Hint.Target.BOOK_HISTORY, Lang.text("История"),
                    Lang.text("Каждая точка — полив. Чем выше точка, тем больше воды ещё было в земле."),
                ),
            )
            PLANT -> listOf(
                Hint(
                    Hint.Target.PLANT_PHOTO, Lang.text("Тень вокруг фото"),
                    Lang.text("Чем суше земля, тем ярче тень: оранжевая — скоро поливать, красная — пора."),
                ),
                Hint(
                    Hint.Target.PLANT_POUR, Lang.text("Полить сейчас"),
                    Lang.text("Одно нажатие — и полив записан. Передумали — внизу появится «Вернуть»."),
                ),
                Hint(
                    Hint.Target.PLANT_TOOLS, Lang.text("AR, модель и настройки"),
                    Lang.text(
                        "Посмотрите на растение у себя в комнате, сделайте ему свою модель по " +
                            "фото или поменяйте кличку, вид и срок полива.",
                    ),
                ),
                Hint(
                    Hint.Target.PLANT_NOTES, Lang.text("Заметки"),
                    Lang.text("Пишите, что важно: где любит стоять, чем подкармливали."),
                ),
                Hint(
                    Hint.Target.PLANT_DIARY, Lang.text("Поливы"),
                    Lang.text("Все поливы этого растения. Ошибочную запись удалит долгое нажатие."),
                ),
            )
            ADD -> listOf(
                Hint(
                    Hint.Target.ADD_PICTURE, Lang.text("Снимок"),
                    Lang.text("Сфотографируйте растение — телефон попробует узнать его вид."),
                ),
                Hint(
                    Hint.Target.ADD_ABOUT, Lang.text("Кличка и вид"),
                    Lang.text("Придумайте имя. По виду подставится обычный срок полива."),
                ),
                Hint(
                    Hint.Target.ADD_HABITS, Lang.text("Комната и полив"),
                    Lang.text(
                        "Где стоит растение и раз в сколько дней его поливать — барабан " +
                            "крутится пальцем.",
                    ),
                ),
                Hint(
                    Hint.Target.ADD_PLANT, Lang.text("Посадить"),
                    Lang.text("Готово? Растение появится на главной, в выбранной комнате."),
                ),
            )
            PROFILE -> listOf(
                Hint(
                    Hint.Target.PROFILE_PERSON, Lang.text("Хозяин"),
                    Lang.text(
                        "Назовитесь — приложение будет здороваться по имени. Нажмите на " +
                            "кружок, чтобы поставить фото.",
                    ),
                ),
                Hint(
                    Hint.Target.PROFILE_PLOT, Lang.text("Сад"),
                    Lang.text(
                        "Сколько у вас растений и комнат и сколько дней вы ухаживаете за садом.",
                    ),
                ),
                Hint(
                    Hint.Target.PROFILE_RIVALS, Lang.text("Друзья"),
                    Lang.text(
                        "«Позвать» отправит другу ваш счёт. Его ответ вставьте кнопкой " +
                            "«Вставить» — и он встанет в таблицу.",
                    ),
                ),
                Hint(
                    Hint.Target.PROFILE_MORE, Lang.text("Ещё"),
                    Lang.text(
                        "Настройки приложения и «Стереть сад» — если захотите начать заново.",
                    ),
                ),
            )
            SEARCH -> listOf(
                Hint(
                    Hint.Target.SEARCH_BOARD, Lang.text("Поиск"),
                    Lang.text("Поле поиска — вверху. Ищет по кличке, виду и заметкам."),
                ),
                Hint(
                    Hint.Target.SEARCH_RECENTS, Lang.text("Недавние запросы"),
                    Lang.text("Нажмите, чтобы искать снова. Долгое нажатие — забыть запрос."),
                ),
            )
            SETTINGS -> listOf(
                Hint(
                    Hint.Target.SETTINGS_LOOK, Lang.text("Оформление"),
                    Lang.text("Тема, вид карточек и порядок растений на главной."),
                ),
                Hint(
                    Hint.Target.SETTINGS_BACKDROP, Lang.text("Фон"),
                    Lang.text("Фигурки узора, его цвет и цвет волны после полива."),
                ),
                Hint(
                    Hint.Target.SETTINGS_WATERING, Lang.text("Полив"),
                    Lang.text("Напоминания и поправка срока на время года."),
                ),
                Hint(
                    Hint.Target.SETTINGS_ABOUT, Lang.text("О приложении"),
                    Lang.text("Знакомство, словарик и подсказки — их можно показать снова."),
                ),
            )
            TUNING -> listOf(
                Hint(
                    Hint.Target.TUNING_ABOUT, Lang.text("Кличка и вид"),
                    Lang.text("Поменяли вид — в AR встанет модель нового вида."),
                ),
                Hint(
                    Hint.Target.TUNING_HABITS, Lang.text("Срок полива"),
                    Lang.text("Покрутите барабан — ниже видно, как новый срок ляжет на карточку."),
                ),
                Hint(
                    Hint.Target.TUNING_TENDING, Lang.text("Подкормка и пересадка"),
                    Lang.text("Приложение напомнит, когда пора удобрять и пересаживать."),
                ),
            )
            AR -> listOf(
                Hint(
                    Hint.Target.AR_HINT, Lang.text("Что делать"),
                    Lang.text(
                        "Здесь всегда написан следующий шаг: навести камеру, поставить " +
                            "растение, выбрать его.",
                    ),
                ),
                Hint(
                    Hint.Target.AR_CONTROLS, Lang.text("Кнопки"),
                    Lang.text("«Полить» зовёт лейку: полив засчитается, когда вода коснётся земли."),
                ),
            )
            TRIP -> listOf(
                Hint(Hint.Target.TRIP_DATES, Lang.text("Даты"), Lang.text("Когда уезжаете и когда вернётесь.")),
                Hint(
                    Hint.Target.TRIP_PLAN, Lang.text("Кого полить соседу"),
                    Lang.text("Кто без вас не дождётся и в какие дни его полить. Остальные потерпят."),
                ),
                Hint(
                    Hint.Target.TRIP_ACTIONS, Lang.text("Перед отъездом"),
                    Lang.text("Полейте всех разом и отправьте соседу памятку."),
                ),
            )
            ROOMS -> listOf(
                Hint(
                    Hint.Target.ROOMS_LIST, Lang.text("Комнаты"),
                    Lang.text("Имя правится прямо в строке, порядок — за ручку справа, удалить — смахнуть влево."),
                ),
            )
        }
}
