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

    /// Размер подписи. Задаётся снаружи: на главном экране кнопка растёт
    /// при прокрутке, дорастая до заголовка раздела, и размер приходит
    /// оттуда пересчитанным на каждый кадр.
    var size = Typography.roomSize

    var body: some View {
        Menu {
            Picker("Комната", selection: $selection) {
                ForEach(rooms.indices, id: \.self) { index in
                    Text(rooms[index]).tag(index)
                }
            }
        } label: {
            HStack(spacing: size / 6) {
                Text(rooms[selection])
                    .font(.system(size: size, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    // Стрелка чуть мельче подписи — как в макете, где при
                    // 18 у подписи у неё было 15.
                    .font(.system(size: size * 0.83, weight: .semibold))
            }
            .foregroundStyle(Palette.accent)
        }
        // Не жёсткая высота, а наименьшая: 44 — площадь нажатия, а
        // подпись бывает и выше её, когда дорастает до заголовка.
        .frame(minHeight: 44, alignment: .leading)
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
                // Чёрный в обеих темах: плашка светло-зелёная и в тёмной
                // остаётся такой же — это знак, а не поверхность экрана.
                .foregroundStyle(.black)
        }
        .padding(.leading, 6.9)
        .padding(.trailing, 7.6)
        .frame(height: 28)
        .background(Palette.greenSoft, in: .capsule)
    }
}
