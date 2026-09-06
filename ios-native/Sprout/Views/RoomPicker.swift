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
/// В макете она стоит на 19..47 по вертикали — это ровно область Dynamic
/// Island, и там её на живом телефоне не видно. Поэтому висит сразу под
/// строкой состояния, а не в ней.
struct SproutBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            SproutLogo(height: 21)
            Text("Sprout")
                .font(Typography.wordmark)
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Palette.greenSoft, in: .capsule)
    }
}
