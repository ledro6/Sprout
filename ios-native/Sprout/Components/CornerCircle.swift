import SwiftUI

/// Круглые кнопки-значки — «Вид», «•••», «Готово», «Закрыть», шестерёнка,
/// «назад» — на всех экранах одного размера и с родной физикой нажатия:
/// системное стекло `.glass` в форме круга. Значок — в рамке одного
/// размера, иначе круг под широким значком («•••») выходил бы шире, чем
/// под узким («×»).
enum CornerCircle {
    /// Рамка значка; круг стекла — она плюс системные поля кнопки.
    static let box: CGFloat = 24
    static let glyph: CGFloat = 17
}

extension View {
    /// Значок внутри круглой кнопки (`label` у `Button`, `Menu`,
    /// `ShareLink`).
    func cornerGlyph() -> some View {
        font(.system(size: CornerCircle.glyph, weight: .semibold))
            .frame(width: CornerCircle.box, height: CornerCircle.box)
    }

    /// Сама кнопка: круг системного стекла. `prominent` — закрашенный, для
    /// главного действия («Готово»).
    @ViewBuilder
    func cornerButton(prominent: Bool = false) -> some View {
        if prominent {
            buttonStyle(.glassProminent).buttonBorderShape(.circle)
        } else {
            buttonStyle(.glass).buttonBorderShape(.circle)
        }
    }
}
