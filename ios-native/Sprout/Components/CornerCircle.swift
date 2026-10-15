import SwiftUI

/// Круглые значки шапок — «Вид», «•••», «Готово», «Закрыть», шестерёнка — одного
/// размера на всех экранах: круг `size`, значок `glyph` полужирный. Область
/// касания — `touch`, круг её не сужает.
enum CornerCircle {
    static let size: CGFloat = 36
    static let glyph: CGFloat = 15
    static let touch: CGFloat = 44
}

extension View {
    /// Значок круглой кнопки: стеклянный круг `CornerCircle.size`, касание
    /// `CornerCircle.touch`. Кнопке ставится `.buttonStyle(.plain)`: стиль
    /// `.glass` добавляет свои поля, и круг выходит больше. С `tint` круг
    /// закрашивается — для главного действия («Готово»).
    func cornerCircle(tint: Color? = nil) -> some View {
        modifier(CornerCircleModifier(tint: tint))
    }
}

private struct CornerCircleModifier: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .font(.system(size: CornerCircle.glyph, weight: .semibold))
            .foregroundStyle(tint == nil ? Palette.ink : Color.white)
            .frame(width: CornerCircle.size, height: CornerCircle.size)
            .glassEffect(glass, in: .circle)
            .frame(width: CornerCircle.touch, height: CornerCircle.touch)
            .contentShape(.circle)
    }

    private var glass: Glass {
        guard let tint else { return .regular.interactive() }
        return .regular.tint(tint).interactive()
    }
}
