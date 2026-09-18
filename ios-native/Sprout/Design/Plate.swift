import SwiftUI

extension Shape {
    /// Тревожное свечение вокруг карточки: залитая форма, размытая, с
    /// вырезанным силуэтом самой карточки.
    ///
    /// Своё, потому что системного такого нет: это не отделка плашки, а
    /// показание — насколько растению сухо. Тень плашки здесь тоже
    /// рисовалась этим, и больше не рисуется: её кладёт сам материал.
    ///
    /// Вырез обязателен. Стекло полупрозрачно, и без выреза свечение
    /// просвечивало бы сквозь него, крася плашку изнутри, — в макете у
    /// теней по той же причине стоит «не рисовать под самим слоем».
    /// Обводкой это не заменить: обводка стоит серединой на кромке, и её
    /// внутренняя половина оказывается под плашкой.
    func sproutHalo(_ color: Color, blur: CGFloat,
                    offsetY: CGFloat = 0) -> some View {
        ZStack {
            fill(color)
                .blur(radius: blur)
                .offset(y: offsetY)
            // Цвет здесь не рисуется, а вырезает: важна только его
            // непрозрачность, поэтому он не участвует в темах.
            fill(.black)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// Рисовать ли тревожное свечение под карточкой.
///
/// Через окружение, а не свойством: спрашивают его и сама плашка, и
/// карточка растения, и передавать флаг вручную сквозь всю сетку значило
/// бы тащить его через вью, которым до него нет дела.
private struct SproutHalosKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Свечение под карточкой. Гаснет на время разворачивания карточки в
    /// экран: оно лежит отдельным размытым слоем и в переходе не
    /// перетекает вместе с карточкой, а смазывается за ней хвостом.
    var sproutHalos: Bool {
        get { self[SproutHalosKey.self] }
        set { self[SproutHalosKey.self] = newValue }
    }
}

extension View {
    /// Материал плашек — системное стекло iOS, и ничего сверх него.
    ///
    /// Сверх него здесь было двое: белая вуаль под стеклом и своя тень,
    /// размытой копией формы с вырезанным силуэтом. Оба слоя повторяли
    /// руками то, что материал делает сам. `.regular` подтемняет то, что
    /// под ним, кладёт свою тень и подстраивает цвет содержимого под
    /// просвечивающий фон; в макете это записано как «заливка белым 10%
    /// плюс стеклянный эффект» — потому что в Figma стекла как материала
    /// нет и вуаль там за него и отдувалась.
    ///
    /// Стояло при этом `.clear` — самый прозрачный вариант. Он для
    /// панелей поверх фотографий и видео: читаемость не вытягивает и
    /// цвет содержимого не подстраивает, и её как раз и добирала вуаль.
    /// Для плашек с текстом Apple называет `.regular`, он же и умолчание.
    ///
    /// `interactive` включает отклик стекла на нажатие: оно проминается
    /// под пальцем и отпускает пружиной. Это поведение системы, писать
    /// его не нужно, но и вешать на неинтерактивные панели незачем.
    func sproutPlate(in shape: some Shape,
                     interactive: Bool = false) -> some View {
        glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
            // Стекло рисуется по форме, но нажатия ловит рамка вью —
            // очерчиваем плашку, чтобы тап у скруглённого угла не
            // проходил мимо.
            .contentShape(shape)
    }
}

/// Прыжок на гребне волны полива.
///
/// Полили — и по узору расходится волна. Этот модификатор сажает на ту же
/// волну всё, что лежит поверх узора: кнопку, заголовок, карточку. Каждый
/// чуть подпрыгивает, когда гребень доходит до него.
///
/// Волны под ними не видно — её закрывают плашки и панели, — но раз
/// элементы подпрыгивают по очереди, от места полива и дальше, её ход
/// виден и по ним. Тем и держится: прыжок сам по себе ничего не значит,
/// значит очередь прыжков.
///
/// Черёд считается той же формулой, что у фигурки узора: доля пути до
/// элемента от размаха волны, умноженная на её длительность. Фора, с
/// которой волна трогается из-под плашки политого растения, тоже учтена —
/// от неё отсчёт и идёт.
private struct Ride: ViewModifier {
    /// Насколько элемент сейчас приподнят.
    @State private var lift: CGFloat = 0

    /// Где он на экране. Не состоянием: замер обновляется на каждом кадре
    /// прокрутки, а читается ровно в миг полива. Та же причина, что у
    /// `Spot` на экране растения.
    @State private var spot = Spot()

    /// Прыжок, поставленный в очередь. Полить можно чаще, чем волна
    /// успевает дойти, и новый прыжок должен отменять недождавшийся.
    @State private var hop = Hop()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Замер до смещения, а не после: иначе прыжок сдвигал бы
            // собственную мерку.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { spot.rect = $0 }
            .offset(y: lift)
            .onChange(of: Cheer.shared.start) { _, now in
                guard let now, !reduceMotion else { return }
                ride(from: now)
            }
    }

    private func ride(from start: Date) {
        let middle = CGPoint(x: spot.rect.midX, y: spot.rect.midY)
        let far = hypot(middle.x - Cheer.shared.origin.x,
                        middle.y - Cheer.shared.origin.y)
        let turn = Double(min(far / Metrics.waveReach, 1))
            * (1 - Metrics.popSpan)
        let wait = turn * Motion.cheerSeconds - Date().timeIntervalSince(start)

        hop.run?.cancel()
        hop.run = Task { @MainActor in
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            withAnimation(Motion.rideUp) { lift = -Metrics.ride }
            try? await Task.sleep(for: .seconds(Motion.rideUpSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.rideDown) { lift = 0 }
        }
    }
}

/// Задача прыжка, спрятанная от перерисовок. По той же причине, что и
/// замер: хранить её в состоянии значило бы пересобирать элемент всякий
/// раз, когда она сменилась.
private final class Hop {
    var run: Task<Void, Never>?
}

extension View {
    /// Подпрыгнуть на гребне волны полива — см. `Ride`.
    func sproutRide() -> some View {
        modifier(Ride())
    }
}
