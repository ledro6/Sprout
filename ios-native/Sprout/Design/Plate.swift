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
            fill(.black)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
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
        glassEffect(interactive ? .clear.interactive() : .clear, in: shape)
            .background { shape.fill(Palette.plateFill) }
            .background {
                shape.sproutHalo(Palette.shadow,
                                 blur: Metrics.plateShadowBlur,
                                 offsetY: Metrics.plateShadowY)
            }
            // Стекло рисуется по форме, но нажатия ловит рамка вью —
            // очерчиваем плашку, чтобы тап у скруглённого угла не
            // проходил мимо.
            .contentShape(shape)
    }
}
