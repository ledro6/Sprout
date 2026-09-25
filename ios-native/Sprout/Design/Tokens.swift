import SwiftUI
import UIKit

/// Значения из макета Figma «орпи» (выгружены tool/figma_extract.py). Макет
/// только светлый; тёмная тема — не инверсия: белое становится серым, а не
/// чёрным, иначе стеклу плашек не за что зацепиться.
enum Palette {
    /// Через UIKit, а не ассеты: обе половины видны в одной строке.
    private static func dual(_ light: Color, _ dark: Color) -> Color {
        Color(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    static let background = dual(.white, rgb(43, 46, 44))

    /// В тёмной теме не чистый белый: на сером он звенит.
    static let ink = dual(.black, rgb(238, 241, 237))

    /// Приветственный экран — зелёный в обеих темах: он фирменный.
    static let welcome = dual(rgb(207, 248, 201), rgb(18, 54, 13))
    static let welcomeInk = dual(.black, .white)

    /// Системный синий iOS; в тёмной теме светлее, как у самой iOS.
    static let accent = dual(rgb(0, 136, 255), rgb(74, 168, 255))

    static let green = rgb(55, 181, 81)

    static let greenSoft = rgb(198, 250, 183)

    static let water = rgb(71, 181, 228)

    /// Цвет фигурки узора: 0 — покой, 1 — гребень волны.
    ///
    /// На белом узор — бледной ипостасью в 48%: под стеклом плашек в треть
    /// силы он читался бледнее макета. На сером — насыщенной в 16.5%: бледная
    /// малой долей давала серый, и все цвета выглядели одинаково. Волна
    /// плотнее покоя — 46% и 62%: всплеск должен читаться вспышкой. Поверх —
    /// тление `ember`: цвет фигурки ведётся к красному, так что полив виден и
    /// посреди отсчёта.
    static func pattern(_ base: Shade, wave: Shade, splash level: Double,
                        ember: Double = 0) -> Color {
        let k = min(max(level, 0), 1)
        let e = min(max(ember, 0), 1)
        return dual(paint(mixed(mixed(ink(base.pale, restLight),
                                      ink(wave.vivid, splashLight), k),
                                emberLight, e)),
                    paint(mixed(mixed(ink(base.vivid, restDark),
                                      ink(wave.vivid, splashDark), k),
                                emberDark, e)))
    }

    /// Своя доля, плотнее волны: размытое свечение иначе не читалось бы.
    /// Тление светится сильнее гребня — оно держится весь отсчёт и должно
    /// читаться тревогой.
    static func glow(_ wave: Shade, level: Double, ember: Double = 0)
        -> Color {
        let k = min(max(level, 0), 1)
        let e = min(max(ember, 0), 1)
        return dual(paint(mixed(ink(wave.vivid, glowLight * k),
                                emberGlowLight, e)),
                    paint(mixed(ink(wave.vivid, glowDark * k),
                                emberGlowDark, e)))
    }

    /// Насыщенной ипостасью: бледный кружок на плашке не разглядеть.
    static func swatch(_ tint: Tint) -> Color { colour(tint.vivid, 1) }

    private static let restLight = 0.48
    private static let restDark = 0.165
    private static let splashLight = 0.46
    private static let splashDark = 0.62
    private static let glowLight = 0.5
    private static let glowDark = 0.7

    /// Красный тления — плотнее всего в узоре: удаляемое должно быть видно
    /// краем глаза. В тёмной теме светлее, как и тревожная тень.
    private static let emberLight: Ink = (255, 45, 35, 0.8)
    private static let emberDark: Ink = (255, 72, 60, 0.88)
    private static let emberGlowLight: Ink = (255, 45, 35, 0.55)
    private static let emberGlowDark: Ink = (255, 72, 60, 0.75)

    private typealias Ink = (r: Double, g: Double, b: Double, a: Double)

    private static func ink(_ c: Channels, _ a: Double) -> Ink {
        (c.red, c.green, c.blue, a)
    }

    private static func colour(_ c: Channels, _ a: Double) -> Color {
        Color(red: c.red / 255, green: c.green / 255, blue: c.blue / 255)
            .opacity(a)
    }

    private static func mixed(_ from: Ink, _ to: Ink, _ k: Double) -> Ink {
        let mix = { (a: Double, b: Double) in a + (b - a) * k }
        return (mix(from.r, to.r), mix(from.g, to.g), mix(from.b, to.b),
                mix(from.a, to.a))
    }

    private static func paint(_ ink: Ink) -> Color {
        Color(red: ink.r / 255, green: ink.g / 255, blue: ink.b / 255)
            .opacity(ink.a)
    }

    /// Тревожная тень от 40 до 20 процентов влажности. В тёмной теме светлее.
    static let warn = dual(rgb(255, 149, 0), rgb(255, 169, 46))

    /// Ниже двадцати. Силу тени считает сама карточка.
    static let alarm = dual(rgb(255, 59, 48), rgb(255, 92, 82))

    /// Земля досуха — темнее тревоги: в статистике её надо отличить от
    /// «в последний момент».
    static let parched = dual(rgb(150, 32, 26), rgb(205, 72, 62))

    /// Небо планетария — ночное в обеих темах: планеты видны только на
    /// тёмном.
    static let space = rgb(7, 11, 24)
    static let spaceGlow = rgb(22, 40, 74)
}

/// Шрифты — стилями системы, а не пунктами: так они идут за «Размером
/// текста». Числа макета сместились на пункт-другой к ближайшему стилю (18 →
/// 17, 21 → 20, 10 → 11).
enum Typography {
    static let cardTitle = Font.system(.callout, weight: .medium)

    static let cardCaption = Font.system(.caption2)

    static let navTitle = Font.system(.title3, weight: .semibold)

    static let detail = Font.system(.body, weight: .semibold)

    /// Единственный шрифт в пунктах: плашка — знак с капсулой известной
    /// высоты, и выросший текст её разорвал бы.
    static let wordmark = Font.system(size: 15, weight: .regular)

    static let welcome = Font.system(.title, weight: .bold)

    static let groupTitle = Font.system(.footnote, weight: .semibold)

    static let settingRow = Font.system(.body)
    static let settingNote = Font.system(.footnote)

    /// В пунктах: буква держит пропорцию с кружком, заданным в пунктах.
    static let avatar = Font.system(size: 30, weight: .semibold)

    /// Число — заголовочным стилем, подпись — ярлык, который не надо
    /// склонять.
    static let figure = Font.system(.title, weight: .semibold)
    static let figureCaption = Font.system(.caption)

    /// Числами: между ними идёт плавный перебор при прокрутке.
    static let roomSize: CGFloat = 22
    static let roomGrown: CGFloat = 34

    static let toastTitle = Font.system(.subheadline, weight: .semibold)
    static let toastNote = Font.system(.footnote)
    static let toastCount = Font.system(.caption, weight: .bold)
    static let toastAction = Font.system(.body, weight: .semibold)

    /// Проценты модели на снимке: цифры одной ширины — значок не дрожит,
    /// пока они бегут.
    static let modelBadge = Font.system(.caption2, weight: .semibold)
        .monospacedDigit()
}

/// Размеры и отступы макета.
enum Metrics {
    /// Поле экрана растения — из макета.
    static let margin: CGFloat = 33

    /// Поле разделов со списками — по краю системного заголовка, а не
    /// макетные 33.
    static let contentMargin: CGFloat = 20

    static let gutterH: CGFloat = 36
    static let gutterV: CGFloat = 25

    static let cardRadius: CGFloat = 26
    static let cardPadding: CGFloat = 11

    /// Подобрано под рендер макета: у кромки ~17% красного, на 10 pt — 10%,
    /// на 24 — 2.5%; с сигмой 14 от #FF000066 выходит ровно это.
    static let glowBlur: CGFloat = 14

    /// Сила тревожной тени — от еле заметной у 40% до полной у сухой земли,
    /// плавно.
    static let glowFaint = 0.18
    static let glowFull = 0.62

    /// В макете 19, здесь 5: при 19 капсула вылезала из-под чёлки iPhone 13
    /// Pro.
    static let badgeTop: CGFloat = 5

    /// Лента комнат на главной: высота строки — как у кнопки, чтобы попадал
    /// палец.
    static let roomRow: CGFloat = 44

    /// Зазор между текущим именем и следующим на барабане.
    static let roomGap: CGFloat = 12

    /// На сколько градусов отвёрнуто следующее имя — как на барабане
    /// выбора: видно, что за ним есть ещё, но читается оно не сразу.
    static let roomTurn: Double = 50

    /// Сход у правого края: длинное следующее имя гаснет, а не обрывается.
    static let roomTail: CGFloat = 36

    /// Размытие соседа — доля кегля: 2.6 pt у подписи в покое, 4 у
    /// доросшей. Имя угадывается, но не читается текущим.
    static let roomBlur: CGFloat = 0.12

    /// Выглядывающее имя — вполсилы; уходящее гаснет за две трети пути,
    /// раньше, чем провернётся.
    static let roomDim: CGFloat = 0.45
    static let roomLeave: CGFloat = 1.5

    /// Между лентой и первыми карточками.
    static let shelfDrop: CGFloat = 19

    /// Под последними карточками, над панелью вкладок.
    static let shelfTail: CGFloat = 24

    /// Заголовок «Главная» тает, пройдя эту долю своей высоты: к тому
    /// времени, как лента встанет на его место, его уже нет.
    static let titleFade: CGFloat = 0.7

    /// Всплеск фигурки на волне: доля всей волны (остаток — время прихода
    /// волны к дальним), размах на гребне и поджим вокруг.
    ///
    /// Окно широкое — полосами по три-четыре ряда, а не перебором рядов:
    /// узкое читалось чертой. На деле выходит 1.15 на гребне и 0.66 в ямке.
    /// Гребень упирается в потолок: два соседних поднявшихся ряда смыкаются
    /// впритык (46.68 pt при шаге 46.68).
    static let popSpan = 0.36
    static let popAmp = 0.15
    static let popDip = 0.62

    /// Плавный переход размаха в поджим у нуля: по знаку наклон прыгал
    /// вчетверо, и фигурка спотыкалась. Шире — поджим подмешивается в подъём
    /// соседнего ряда.
    static let popBlend = 0.3

    /// Доля всходов на одну фигурку. Большая: фигурки идут внахлёст, иначе
    /// вышла бы бегущая строка.
    static let bloomSpan = 0.38

    static let waveReach = CGFloat(Front.reach)

    /// Отступ приветствия от безопасной зоны и высота логотипа — по макету.
    static let welcomeTop: CGFloat = 48
    static let welcomeLogo: CGFloat = 342

    /// Достаточно, чтобы буквы в начале не читались вовсе — иначе это
    /// затемнение, а не проступание.
    static let chromeBlur: CGFloat = 12

    /// Меньше шага сетки узора: движение должно читаться подкладкой, а не
    /// ездой.
    static let parallax: CGFloat = 14

    /// Плашки настроек — того же покроя, что карточка.
    static let groupGap: CGFloat = 26
    static let groupPadding: CGFloat = 16
    static let rowGap: CGFloat = 14

    /// Четыре клетки с промежутками умещаются в строку и на узком телефоне.
    static let pieceTile: CGFloat = 44

    /// Не до нуля: выключенная фигурка показывает, что её можно включить.
    static let pieceOff = 0.22

    /// Коробка задаёт размер кнопки, шестерёнка крупнее коробки и выходит за
    /// неё.
    static let gearBox: CGFloat = 24
    static let gearGlyph: CGFloat = 24

    /// Мельче шестерёнки: клетки и полоски плотнее и читались бы жирнее.
    static let cornerGlyph: CGFloat = 19

    static let cornerGap: CGFloat = 8

    /// Строка списка. Поле 10 при скруглении 26 даёт картинке 16 — углы идут
    /// параллельно.
    static let rowPhoto: CGFloat = 60
    static let rowPadding: CGFloat = 10
    static let rowTrail: CGFloat = 16
    static let listGap: CGFloat = 12

    static let gripGlyph: CGFloat = 17

    /// Тащимая карточка на своём месте бледнеет, а не исчезает: брошенное
    /// мимо перетаскивание система не сообщает, и пустое место так бы и
    /// осталось.
    static let ghost = 0.3

    /// Значок готовности модели — в углу снимка, чуть отступив от
    /// скругления: не липнет к краю.
    static let modelBadgeInset: CGFloat = 7

    /// Подсказки на экранах: ниже этого от низа экрана пузырь не встаёт —
    /// там панель вкладок и полоска «Домой».
    static let coachFloor: CGFloat = 96

    /// Пузырь пояснения: строк в пять, как сноска, а не лист.
    static let hintWidth: CGFloat = 280

    /// Поле вокруг «?», которое ловит палец: сам значок мельче пальца.
    static let hintReach: CGFloat = 8

    /// Знак страницы знакомства и стеклянный круг под ним.
    static let tourGlyph: CGFloat = 52
    static let tourBadge: CGFloat = 116

    static let ring: CGFloat = 30

    /// Статистика: толщина кольца «сейчас», высота полоски влажности,
    /// полосы зон и столбиков дней недели, высота графиков.
    static let statRing: CGFloat = 14
    static let statRingSize: CGFloat = 118
    static let stripHeight: CGFloat = 34
    static let zoneBar: CGFloat = 12
    static let weekBars: CGFloat = 54
    static let chartHeight: CGFloat = 170
    static let hourClock: CGFloat = 150

    /// Планетарий: планета, выбранная планета, солнце и превью на обзоре.
    static let planet: CGFloat = 11
    static let planetPicked: CGFloat = 20
    static let sun: CGFloat = 40
    static let teaser: CGFloat = 92
    static let ringLine: CGFloat = 2.5

    static let toastGap: CGFloat = 10

    /// Всплеск тления длится столько же, сколько у полива: волна та же, только
    /// идёт весь отсчёт.
    static let emberSpan = popSpan * Motion.cheerSeconds / Motion.undoSeconds

    /// Обратная волна: всплески короткие, фронт проходит экран за треть
    /// секунды.
    static let emberBackSpan = 0.5

    /// Мельче размытия панели: строки при той же силе проступали бы из пятна.
    static let textBlur: CGFloat = 8

    static let diaryGap: CGFloat = 10

    /// Экран растения: плашки идут плотно, кнопки под фото — ещё плотнее,
    /// одной связкой.
    static let plantGap: CGFloat = 16
    static let actionGap: CGFloat = 10
    static let toolRadius: CGFloat = 20

    /// Барабан срока полива: три строки видно, как у «Таймера».
    static let wheelWidth: CGFloat = 76
    static let wheelHeight: CGFloat = 118

    /// «100%» помещается, и число не толкает ползунок.
    static let percentWidth: CGFloat = 52

    /// Предпросмотру меню размера не предлагают, и карточка без числа
    /// свернулась бы. Чуть крупнее, чем в сетке.
    static let previewCard: CGFloat = 200

    /// Тот же случай для снимка; настоящее предложение это число перекрывает.
    static let photoIdeal: CGFloat = 160

    /// Крупный: единственная картинка на экране, мелкий читался бы значком
    /// строки.
    static let avatar: CGFloat = 66

    /// Цветов шесть — меньше клетки с фигуркой, иначе в строку не встанут.
    static let swatch: CGFloat = 28

    /// Мало нарочно: фигурка на гребне раздаётся на три пункта, и прыгнувший
    /// выше элемент ехал бы сам по себе.
    static let ride: CGFloat = 5

    static let splashGlow: CGFloat = 8

    /// Доля перекраски на одну фигурку: видны и перекрашенное, и прежнее, и
    /// полоса между ними. Та же, что у всплеска.
    static let repaintSpan = popSpan

    /// Доля смены набора на одну фигурку. Большая: иначе сетка успевала бы
    /// исчезнуть прежде, чем появиться.
    static let swapSpan = popSpan

    /// Растяжка у нижнего края под панелью вкладок; верхняя из макета убрана
    /// — край держит подложка в корне.
    static let washHeight: CGFloat = 166
    static let washStop: CGFloat = 0.4
}
