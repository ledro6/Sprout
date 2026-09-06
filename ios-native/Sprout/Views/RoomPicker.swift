import SwiftUI

/// Кнопка выбора комнаты: «Спальня ⌄».
struct RoomPickerButton: View {
    let room: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(room)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 15, weight: .semibold))
            }
            .font(Typography.room)
            .foregroundStyle(Palette.accent)
        }
        .buttonStyle(.plain)
        .frame(height: 44, alignment: .leading)
    }
}

/// Всплывающее меню комнат.
///
/// Собрано вручную, а не системным `Menu`, потому что системное меню
/// рисует строки со своими разделителями, а в макете три отдельные
/// пилюли внутри стеклянной панели. Материал при этом всё равно
/// системный, и появление — штатной пружиной `.smooth`, а не самописной.
struct RoomMenu: View {
    let rooms: [String]
    let selected: Int
    /// Левый верхний угол кнопки в координатах экрана: панель в макете
    /// сдвинута относительно неё на 4 pt влево и вниз.
    let anchor: CGPoint
    let onPick: (Int) -> Void
    let onDismiss: () -> Void

    private var sheetHeight: CGFloat {
        Metrics.sheetPadding * 2
            + CGFloat(rooms.count) * Metrics.menuItemHeight
            + CGFloat(rooms.count - 1) * Metrics.menuItemGap
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: Metrics.menuItemGap) {
                ForEach(Array(rooms.enumerated()), id: \.offset) { index, name in
                    Button {
                        onPick(index)
                    } label: {
                        Text(name)
                            .font(Typography.menuItem)
                            .foregroundStyle(
                                index == selected ? Palette.accent : .black)
                            .frame(maxWidth: .infinity)
                            .frame(height: Metrics.menuItemHeight)
                            .background(
                                Palette.menuItemFill,
                                in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Metrics.sheetPadding)
            .frame(width: Metrics.sheetWidth, height: sheetHeight)
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: Metrics.sheetRadius, style: .continuous))
            .shadow(color: Palette.shadow, radius: 15, x: 0, y: 6)
            .offset(x: anchor.x - 4, y: anchor.y + 4)
        }
        .transition(.opacity)
    }
}
