import SwiftUI

/// Значения из макета Figma «орпи». Выгружены tool/figma_extract.py и
/// отранжированы по частоте — то, что встречается в макете десятки раз,
/// и есть токен.
///
/// Макет нарисован под ширину 402 pt (iPhone 16/17 Pro). Отступы берутся
/// отсюда как есть, сетка карточек считается от реальной ширины экрана.
enum Palette {
    /// Фон приложения.
    static let background = Color.white

    /// Узор из капель: #CFF8C9 с прозрачностью 30%.
    static let pattern = Color(red: 207 / 255, green: 248 / 255, blue: 201 / 255)
        .opacity(0.3)

    /// Системный синий iOS: выбранная комната и активная вкладка.
    static let accent = Color(red: 0, green: 136 / 255, blue: 1)

    /// Зелёный логотипа.
    static let green = Color(red: 55 / 255, green: 181 / 255, blue: 81 / 255)

    /// Светло-зелёная плашка логотипа.
    static let greenSoft = Color(red: 198 / 255, green: 250 / 255, blue: 183 / 255)

    /// Голубой капли на логотипе.
    static let water = Color(red: 71 / 255, green: 181 / 255, blue: 228 / 255)

    /// Тень всех плашек макета: #0000001F. У карточки на главном экране
    /// в данных стоит вчетверо плотнее, но это выброс: в самом рендере
    /// под её нижней кромкой фон темнеет ровно настолько же, насколько
    /// под остальными плашками, — на 8%, сходя на нет за 25 pt.
    static let shadow = Color.black.opacity(0.12)

    /// Заливка плашек: белый 10%. Ровно вуаль, сквозь которую виден узор.
    static let plateFill = Color.white.opacity(0.1)

    /// Тревожное свечение — полив завтра: #FF000066.
    static let thirsty = Color.red.opacity(0.4)

    /// То же в критической стадии — полив сегодня: #FF000099.
    static let thirstyNow = Color.red.opacity(0.6)

    /// Затемнение экрана под всплывающим меню: #00000024.
    static let scrim = Color.black.opacity(0.14)

    /// Системная заливка iOS под пунктами меню: #78788029.
    static let menuItemFill = Color(
        red: 120 / 255, green: 120 / 255, blue: 128 / 255
    ).opacity(0.16)
}

/// Начертания. Шрифт намеренно не задан именем: система подставит SF Pro,
/// на котором макет и нарисован. Вес 590 в Figma — это semibold, 510 — medium.
enum Typography {
    /// Приветствие из макета — 26.3/34 semibold. Сам экран его больше не
    /// показывает: заголовок раздела там теперь системный, крупный, как в
    /// остальных вкладках.
    static let greeting = Font.system(size: 26.3, weight: .semibold)

    /// Кнопка выбора комнаты — 18/28 semibold.
    static let room = Font.system(size: 18, weight: .semibold)

    /// Имя растения и влажность на карточке — 16/19 medium.
    static let cardTitle = Font.system(size: 16, weight: .medium)

    /// «Следующий полив…» — 10/12 regular.
    static let cardCaption = Font.system(size: 10, weight: .regular)

    /// Пункт всплывающего меню — 12.4/16 medium.
    static let menuItem = Font.system(size: 12.4, weight: .medium)

    /// Заголовок экрана растения — 21/28 semibold.
    static let navTitle = Font.system(size: 21, weight: .semibold)

    /// Строка списка на экране растения — 17/28 semibold.
    static let detail = Font.system(size: 17, weight: .semibold)

    /// Название приложения на плашке под чёлкой.
    static let wordmark = Font.system(size: 15, weight: .regular)
}

/// Размеры и отступы макета в логических пикселях.
enum Metrics {
    /// Ширина, под которую нарисован макет.
    static let designWidth: CGFloat = 402

    /// Боковое поле контента на экране растения — из макета.
    static let margin: CGFloat = 33

    /// Боковое поле разделов со списками. Не из макета: заголовок здесь
    /// системный, и содержимое должно вставать по его левому краю, а не
    /// по макетным 33.
    static let contentMargin: CGFloat = 20

    /// Промежутки между карточками: по горизонтали 36, по вертикали 25.
    static let gutterH: CGFloat = 36
    static let gutterV: CGFloat = 25

    /// Скругление карточки и внутреннее поле.
    static let cardRadius: CGFloat = 26
    static let cardPadding: CGFloat = 11

    /// Тень плашки: смещение из макета, размытие подобрано под рендер.
    static let plateShadowY: CGFloat = 8
    static let plateShadowBlur: CGFloat = 7

    /// Размытие тревожного свечения. Подобрано под рендер макета: там у
    /// кромки красного примерно 17%, на 10 pt в сторону — 10%, на 24 —
    /// 2.5%. Ореол отдаёт у кромки половину своего цвета, дальше сходит
    /// по гауссиане, и с сигмой 14 от #FF000066 получается ровно это.
    static let glowBlur: CGFloat = 14

    /// Всплывающее меню комнат.
    static let sheetRadius: CGFloat = 24.8
    static let sheetWidth: CGFloat = 219
    static let menuItemHeight: CGFloat = 35
    static let menuItemGap: CGFloat = 7.5
    static let sheetPadding: CGFloat = 10

    /// Плашка с логотипом — в 19 pt от верха экрана, как в макете. Там
    /// она наполовину под вырезом, и это намеренно: на скриншотах вырез
    /// не снимается, и плашка оказывается на виду.
    static let badgeTop: CGFloat = 19

    /// Растяжка под закреплённой строкой комнаты: полупрозрачная, чтобы
    /// сквозь неё читался узор, как сквозь панель в мессенджерах.
    ///
    /// Ровная часть накрывает строку и всё, что выше неё, — иначе у
    /// растяжки был бы виден верхний край.
    static let headerWashOpacity: CGFloat = 0.82
    static let headerWashFade: CGFloat = 32
    static let headerWashRise: CGFloat = 200

    /// Насколько сход свисает ниже строки комнаты: его длина минус те
    /// 13 pt, что пустуют у кнопки под подписью (её 44 pt — площадь
    /// нажатия, сама подпись занимает 18). На столько же отодвинуты
    /// карточки — тогда сход кончается ровно там, где они начинаются.
    static let headerWashDrop: CGFloat = headerWashFade - 13

    /// Белые растяжки поверх узора: полоса 166 pt, сплошной белый до 40%.
    static let washHeight: CGFloat = 166
    static let washStop: CGFloat = 0.4
}
