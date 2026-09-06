import SwiftUI

/// Выбор комнаты — системное меню.
///
/// Раньше здесь была своя всплывающая панель: стеклянный прямоугольник,
/// три пилюли, затемнение и анимация появления руками. Выглядело
/// самодельно, потому что таким и было.
///
/// Теперь это `Menu` с `Picker` внутри. Система сама рисует стеклянное
/// меню у кнопки, ставит галочку у выбранного пункта, анимирует
/// появление и закрытие, даёт тактильный отклик и закрывается по тапу
/// мимо. Ни одной строки анимации здесь нет и быть не должно.
struct RoomPicker: View {
    let rooms: [String]
    @Binding var selection: Int

    var body: some View {
        Menu {
            Picker("Комната", selection: $selection) {
                ForEach(rooms.indices, id: \.self) { index in
                    Text(rooms[index]).tag(index)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(rooms[selection])
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 15, weight: .semibold))
            }
            .font(Typography.room)
            .foregroundStyle(Palette.accent)
        }
        .frame(height: 44, alignment: .leading)
    }
}

/// Плашка под чёлкой: логотип и название.
///
/// Размеры из макета: капсула 81.6 × 28, логотип 14.6 шириной, между ним
/// и словом 2.5, поля 6.9 слева и 7.6 справа. Скругление в макете 19.8
/// при высоте 28 — Figma подрезает его до половины высоты, то есть это
/// капсула.
struct SproutBadge: View {
    var body: some View {
        HStack(spacing: 2.5) {
            SproutLogo()
            Text("Sprout")
                .font(Typography.wordmark)
                .foregroundStyle(.black)
        }
        .padding(.leading, 6.9)
        .padding(.trailing, 7.6)
        .frame(height: 28)
        .background(Palette.greenSoft, in: .capsule)
    }
}
