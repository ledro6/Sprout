import Foundation

/// Слова приложения, которые понятны не всем, — с пояснением простыми
/// словами. Видны по «?» рядом со словом и списком в «Словарике».
enum Term: String, CaseIterable, Identifiable, Sendable {
    case ar, model, moisture, period, seasons, rhythm, feeding, repotting,
         reminders, parallax, sway, wave, frolic, lock, trip, accuracy,
         streak, orrery, parade, pets, motif, agenda, weather

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
        case .parallax: Lang.text("Узор движется при наклоне")
        case .sway: Lang.text("Фигурки плывут порознь")
        case .wave: Lang.text("Волна")
        case .frolic: Lang.text("Кутерьма")
        case .lock: Lang.text("Замок")
        case .trip: Lang.text("Уезжаю")
        case .accuracy: Lang.text("Полив вовремя")
        case .streak: Lang.text("Дни подряд")
        case .orrery: Lang.text("Планетарий")
        case .parade: Lang.text("Парад")
        case .pets: Lang.text("Кошкам и собакам")
        case .motif: Lang.text("Узор по времени года")
        case .agenda: Lang.text("Сроки в Календаре")
        case .weather: Lang.text("Погода")
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
                Объёмная копия растения для AR. Модели видов уже лежат в \
                приложении, а свою можно придумать по фото или \
                отсканировать — кнопка «Модель» на экране растения.
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
        case .weather:
            Lang.text("""
                Жара и сухой воздух торопят землю, прохлада и сырость — \
                придерживают. Дома погода чувствуется вполовину, на \
                балконе — целиком. Погоду даёт Apple Weather по примерному \
                месту.
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
                Уведомление на телефон в тот день, когда растению пора \
                полить, — для тех же растений, у которых на главной \
                «Полить сегодня».
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
        case .accuracy:
            Lang.text("""
                Сколько воды оставалось в земле, когда вы поливали. \
                «В срок» — когда карточка светится оранжевым: в земле \
                20–40%. Раньше — «Рано», позже — «Впритык».
                """)
        case .streak:
            Lang.text("""
                Сколько дней подряд вы поливали хоть одно растение. \
                Пропущенный день начинает счёт заново.
                """)
        case .orrery:
            Lang.text("""
                Сад как солнечная система: растение — планета, круг — срок \
                полива. Дошла до ворот наверху — пора поливать.
                """)
        case .parade:
            Lang.text("""
                День, когда воды попросят сразу три растения и больше, — \
                удобно полить всех за один заход.
                """)
        case .pets:
            Lang.text("""
                Можно ли ставить растение туда, где до него доберётся \
                питомец. По базе ASPCA, которой пользуются ветеринары. \
                Съел лист ядовитого — сразу к ветеринару.
                """)
        case .motif:
            Lang.text("""
                Зимой в узор вплетаются снежинки, осенью — кленовые \
                листья, а с 20 декабря по 10 января капли горят \
                новогодней гирляндой.
                """)
        case .agenda:
            Lang.text("""
                В Календаре телефона появится календарь «Sprout»: в какой \
                день кого полить и подкормить, на три недели вперёд. План \
                обновляется, когда вы выходите из приложения.
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
        case .accuracy: "scope"
        case .streak: "flame"
        case .orrery: "circle.circle"
        case .parade: "sparkles.rectangle.stack"
        case .pets: "pawprint"
        case .motif: "snowflake"
        case .agenda: "calendar.badge.plus"
        case .weather: "cloud.sun"
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

    /// Страница, где выбирают время напоминания и «Пока без уведомлений».
    static let reminderPage = 2

    static var pages: [Page] {
        [
            Page(id: 0, icon: "leaf.fill",
                 title: Lang.text("Это ваш сад"),
                 text: Lang.text("""
                     Каждая карточка — растение, а число рядом с кличкой — \
                     сколько воды осталось в земле. Sprout считает сроки сам \
                     и подскажет, кого пора полить сегодня.
                     """)),
            Page(id: 1, icon: "drop.fill",
                 title: Lang.text("Как поливать"),
                 text: Lang.text("""
                     Нажмите на каплю на карточке. В списке — проведите по \
                     растению вправо. А на экране «Домой» и на экране \
                     блокировки есть виджет: «Полить» не открывая приложения.
                     """)),
            Page(id: 2, icon: "bell.fill",
                 title: Lang.text("Напоминать по утрам?"),
                 text: Lang.text("""
                     Один раз в день скажем, кого пора полить. Не больше двух \
                     уведомлений в день, ночью тишина. Во сколько напоминать?
                     """)),
        ]
    }
}
