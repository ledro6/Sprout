import SwiftUI

/// Выбор комнаты — системное меню с `Picker`: стекло, галочку, анимацию и
/// отклик рисует система.
struct RoomPicker: View {
    let rooms: [String]
    @Binding var selection: Int

    /// Размер приходит снаружи: на главной подпись дорастает до заголовка при
    /// прокрутке.
    var size = Typography.roomSize

    var onEdit: (() -> Void)? = nil

    /// Номер придерживаем в границах: после удаления комнаты он на кадр
    /// смотрит мимо списка.
    private var chosen: String {
        rooms.indices.contains(selection) ? rooms[selection]
            : rooms.last ?? ""
    }

    var body: some View {
        Menu {
            Picker("Комната", selection: $selection) {
                ForEach(rooms.indices, id: \.self) { index in
                    Text(rooms[index]).tag(index)
                }
            }
            if let onEdit {
                Divider()
                Button { onEdit() } label: {
                    Label("Изменить комнаты…", systemImage: "pencil")
                }
            }
        } label: {
            HStack(spacing: size / 6) {
                Text(chosen)
                    .font(.system(size: size, weight: .semibold))
                    .contentTransition(.numericText())
                    .animation(Motion.number, value: selection)
                    // В строке с тремя кнопками длинная комната ужимается, а
                    // не обрезается многоточием.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: size * 0.83, weight: .semibold))
            }
            .foregroundStyle(Palette.accent)
        }
        // Наименьшая высота, а не жёсткая: доросшая подпись выше 44.
        .frame(minHeight: 44, alignment: .leading)
    }
}

/// Плашка под чёлкой: логотип и название. Размеры из макета.
struct SproutBadge: View {
    var body: some View {
        HStack(spacing: 2.5) {
            SproutLogo()
            Text("Sprout")
                .font(Typography.wordmark)
                // Чёрный в обеих темах: плашка светло-зелёная всегда — это
                // знак, а не поверхность.
                .foregroundStyle(.black)
        }
        .padding(.leading, 6.9)
        .padding(.trailing, 7.6)
        .frame(height: 28)
        .background(Palette.greenSoft, in: .capsule)
    }
}

/// Подменю «Переехать» — одно на меню карточки и экрана растения.
struct MoveMenu: View {
    let current: String?
    let rooms: [String]

    let move: (String) -> Void

    let ask: () -> Void

    var body: some View {
        Menu {
            ForEach(rooms.filter { $0 != current }, id: \.self) { name in
                Button(name) { move(name) }
            }
            Divider()
            Button { ask() } label: {
                Label("Новая комната…", systemImage: "plus")
            }
        } label: {
            Label("Переехать", systemImage: "door.left.hand.open")
        }
    }
}
