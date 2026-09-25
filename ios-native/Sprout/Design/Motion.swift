import SwiftUI

/// Движение интерфейса — в одном месте. Везде пружины: прерванная, она
/// продолжает с набранной скорости, а кривая прыгнула бы. Числа проверены на
/// телефоне: «плавнее» — и волна переставала быть заметной.
enum Motion {
    static let appear = Animation.spring(duration: 0.45, bounce: 0.28)

    /// Шаг волны появления: восемь карточек укладываются в полсекунды.
    static let stagger = 0.055

    static let leave = Animation.easeOut(duration: 0.24)

    /// Секунду ореола нет вовсе — карточка складывается и встаёт на место,
    /// потом он проявляется за полсекунды. При открытии гаснет сразу, без
    /// анимации.
    static let haloWait: Duration = .seconds(1)
    static let halo = Animation.easeOut(duration: 0.5)

    /// Вернуть ореол после выдержки. Выдержка — таймером, а не `.delay` у
    /// анимации: в конце складывания SwiftUI заново ставит карточку на полку,
    /// отложенная анимация при этом терялась, и ореол вспыхивал сразу, под
    /// ещё не вставшей карточкой. Здесь же до конца выдержки он погашен в
    /// самом состоянии. Отменили раньше — открыли карточку снова, ушли с
    /// экрана — ореол не трогаем.
    @MainActor
    static func haloBack(_ reveal: () -> Void) async {
        try? await Task.sleep(for: haloWait)
        guard !Task.isCancelled else { return }
        withAnimation(halo) { reveal() }
    }

    static let number = Animation.easeInOut(duration: 0.3)

    /// Вдох-выдох за 2.5 с: читается дыханием, а не миганием.
    static let pulsePeriod = 1.25

    static let pulseLow = 0.45

    /// Волна всплесков по узору после полива. Не короче: переходы ускорили до
    /// 1.5 с, но у волны нажатие одно, и спешить ей некуда; до дальнего угла
    /// она доходит примерно за полторы секунды.
    static let cheerSeconds = 2.4

    /// Прыжок на гребне: вверх и обратно — вместе 0.66 с, ровно всплеск одной
    /// фигурки (`popSpan`). Пружинами, почти без отскока: упругие читались
    /// щелчком. Вниз вдвое дольше, как и у фигурки.
    static let rideUpSeconds = 0.28
    static let rideUp = Animation.spring(duration: rideUpSeconds, bounce: 0.1)
    static let rideDown = Animation.spring(duration: 0.55, bounce: 0.02)

    /// Разброс периода пульса: с одинаковым периодом карточки дышали бы
    /// строем.
    static let pulseSpread = 0.5

    static let chrome = Animation.easeOut(duration: 0.5)

    /// Отставание панели от разворачивания карточки, как в Музыке. Отдельным
    /// числом, а не `delay`: иначе с задержкой шёл бы и уход.
    static let chromeDelay = 0.18

    /// Уход панели — с быстрым началом: за `easeIn` к закрытию она не
    /// успевала погаснуть.
    static let chromeOutSeconds = 0.2
    static let chromeOut = Animation.easeOut(duration: chromeOutSeconds)

    /// Закрытие ждёт ухода панели: на складывание UIKit снимает с неё кадр.
    static let chromeLead = chromeOutSeconds - 0.02

    /// Заставка: элементы всплывают поочерёдно и держатся, пока приложение
    /// поднимается.
    static let welcomeIn = Animation.spring(duration: 0.55, bounce: 0.18)
    static let welcomeStep = 0.22
    static let welcomeHold = 1.6
    static let welcomeLeaveSeconds = 0.45
    static let welcomeLeave = Animation.easeOut(duration: welcomeLeaveSeconds)

    static let welcomeScale: CGFloat = 0.86

    /// Логотип собирается по частям снизу вверх. Ход общий, части расходятся
    /// задержкой `logoLag`: рисует их один холст.
    static let logoSeconds = 0.85
    static let logoLag = 0.13

    static let logoScale: CGFloat = 0.7

    /// Вход приложения ступенями: узор, заголовок, комната, сетка, панель
    /// вкладок.
    static let enter = Animation.spring(duration: 0.5, bounce: 0.2)
    static let enterStep = 0.13

    static let enterRise: CGFloat = 22

    /// Всходы узора: каждая фигурка вырастает своим чередом — прозрачностью
    /// восьмипроцентный узор не показать.
    static let bloomSeconds = 1.1

    /// Промежуток между переходами в очереди: чтобы два не слились в один.
    static let changeGap = 0.08

    /// Сколько переходов ждут очереди. Переполнилась — последний ждущий
    /// перенимает новую цель: хвост не растёт, конец верный.
    static let queued = 3

    /// Перекраска и смена фигурок — та же волна, что у полива (общие
    /// `Front.reach` и `popSpan`), но короче: переходы встают в очередь.
    static let repaintSeconds = 1.5
    static let swapSeconds = 1.5

    /// Капсула выбора: короткая пружина с мелким отскоком — она отметка, а не
    /// брошенный предмет.
    static let pill = Animation.spring(duration: 0.32, bounce: 0.16)

    static let rise: CGFloat = 26
    static let scale: CGFloat = 0.9

    /// Перестановка карточек, правка и смена вида.
    static let arrange = Animation.spring(duration: 0.32, bounce: 0.16)

    /// Листание к комнате нажатием: без отскока — страница не брошена, а
    /// подведена.
    static let page = Animation.smooth(duration: 0.42)

    /// Покачивание полки — как значки «Домой»: такт один на всех, фаза у
    /// каждой карточки своя. Угол меньше, чем у значка (там около двух
    /// градусов): карточка втрое крупнее, и край ходил бы втрое дальше. Такт
    /// — чуть больше четверти секунды: на более частом крупная карточка
    /// дрожит, а не качается.
    static let jiggleAngle = 1.2
    static let jigglePeriod = 0.28

    /// Дрожь по восьмёрке — в полпункта: её не видно, но без неё карточка
    /// ходит маятником.
    static let jiggleShake: CGFloat = 0.5

    /// Качание набирает размах и стихает, а не включается щелчком.
    static let jiggleIn = Animation.easeOut(duration: 0.25)
    static let jiggleOut = Animation.easeOut(duration: 0.2)

    /// Сколько держать палец после меню, чтобы полка закачалась, — как на
    /// «Домой»: подержал дольше меню — меню уходит, значки качаются.
    static let holdToArrange = 0.8

    /// Модель собралась — значок ещё миг показывает сотню и уходит: сразу
    /// ушедший, он не давал бы увидеть, что дошло до конца.
    static let modelLinger = 0.6

    /// Сколько секунд удалённое можно вернуть.
    static let undoSeconds = 5.0

    /// Погасание быстрее разгорания: разгорание — отсчёт, погасание — ответ.
    static let emberOutSeconds = 0.6

    static let toast = Animation.spring(duration: 0.4, bounce: 0.18)
}
