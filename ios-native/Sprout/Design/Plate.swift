import SwiftUI

extension Shape {
    /// Ореол вокруг плашки: залитая форма, размытая, с вырезанным
    /// силуэтом самой плашки.
    ///
    /// Вырез обязателен. Заливка плашки полупрозрачная, и без выреза
    /// ореол просвечивал бы сквозь неё, крася плашку изнутри, — в макете
    /// у теней по той же причине стоит «не рисовать под самим слоем».
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

/// Рисовать ли ореолы под плашками — тень и тревожное свечение.
///
/// Через окружение, а не свойством: спрашивают его и сама плашка, и
/// карточка растения, и передавать флаг вручную сквозь всю сетку значило
/// бы тащить его через вью, которым до него нет дела.
private struct SproutHalosKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Ореолы под плашками. Гасятся на время разворачивания карточки в
    /// экран: они лежат отдельными размытыми слоями и в переходе не
    /// перетекают вместе с карточкой, а смазываются за ней хвостом.
    var sproutHalos: Bool {
        get { self[SproutHalosKey.self] }
        set { self[SproutHalosKey.self] = newValue }
    }
}

/// Материал плашек. Отдельным типом, а не одной цепочкой в расширении:
/// ему нужно читать окружение, а расширению вью читать нечего.
private struct SproutPlate<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @Environment(\.sproutHalos) private var halos

    func body(content: Content) -> some View {
        content
            .glassEffect(interactive ? .clear.interactive() : .clear, in: shape)
            .background { shape.fill(Palette.plateFill) }
            .background {
                shape.sproutHalo(Palette.shadow,
                                 blur: Metrics.plateShadowBlur,
                                 offsetY: Metrics.plateShadowY)
                    .opacity(halos ? 1 : 0)
            }
            // Стекло рисуется по форме, но нажатия ловит рамка вью —
            // очерчиваем плашку, чтобы тап у скруглённого угла не
            // проходил мимо.
            .contentShape(shape)
    }
}

extension View {
    /// Материал плашек: системное стекло iOS поверх тени из макета.
    ///
    /// В макете плашка — заливка белым 10% плюс стеклянный эффект.
    /// Заливка лежит под стеклом, как и там.
    ///
    /// `interactive` включает отклик стекла на нажатие: оно проминается
    /// под пальцем и отпускает пружиной. Это поведение системы, писать
    /// его не нужно, но и вешать на неинтерактивные панели незачем.
    ///
    /// Тень нельзя вешать через `.shadow`: она уводит вью в отдельный
    /// слой, и стекло теряет фон, который должно преломлять. Поэтому она
    /// рисуется в `.background`, откуда стекло её честно берёт.
    func sproutPlate(in shape: some Shape,
                     interactive: Bool = false) -> some View {
        modifier(SproutPlate(shape: shape, interactive: interactive))
    }
}
