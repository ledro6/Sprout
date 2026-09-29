import SwiftUI

extension Shape {
    /// Тревожное свечение вокруг карточки: размытая форма с вырезанным
    /// силуэтом. Вырез обязателен — стекло полупрозрачно, и свечение красило
    /// бы плашку изнутри; обводкой не заменить, её внутренняя половина лежит
    /// под плашкой.
    func sproutHalo(_ color: Color, blur: CGFloat,
                    offsetY: CGFloat = 0) -> some View {
        ZStack {
            fill(color)
                .blur(radius: blur)
                .offset(y: offsetY)
            // Этот цвет только вырезает — важна непрозрачность, темы его не
            // касаются.
            fill(.black)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// Через окружение: флаг нужен глубоко в карточке, и тащить его свойством
/// через всю сетку незачем.
private struct SproutHalosKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Гаснет на время разворачивания карточки в экран: размытый слой не
    /// перетекает с карточкой, а смазывается хвостом.
    var sproutHalos: Bool {
        get { self[SproutHalosKey.self] }
        set { self[SproutHalosKey.self] = newValue }
    }
}

extension View {
    /// Материал плашек — системное стекло `.regular`, и ничего сверх него:
    /// вуаль и тень материал кладёт сам. Не `.clear` — он для панелей поверх
    /// фото и не вытягивает читаемость текста. Не `.interactive()`: такое
    /// стекло откликается уже на касание, с которого начинается прокрутка,
    /// и плашка тянулась за пальцем и дёргалась. Нажатие показывает
    /// `SproutPress`.
    func sproutPlate(in shape: some Shape) -> some View {
        glassEffect(.regular, in: shape)
            // Нажатия ловит рамка вью — очерчиваем, чтобы тап у скруглённого
            // угла не проходил мимо.
            .contentShape(shape)
    }
}

/// Нажатие на плашку — лёгкое проседание. Кнопка в прокрутке узнаёт
/// нажатие, только когда ясно, что палец не листает, — на прокрутке плашка
/// стоит твёрдо, как приклеенная.
struct SproutPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Motion.pressScale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Прыжок на гребне волны полива: всё, что лежит поверх узора, подпрыгивает
/// ровно тогда, когда под ним проходит гребень, — по очереди прыжков виден
/// ход волны. Черёд — та же формула, что у фигурок узора, с учётом форы
/// из-под плашки.
private struct Ride: ViewModifier {
    @State private var lift: CGFloat = 0

    /// Не состоянием: замер меняется каждый кадр прокрутки, а читается только
    /// в миг полива.
    @State private var spot = Spot()

    /// Номер последнего прыжка: опускает плашку только последний — прыжки
    /// разных волн не обрывают друг друга.
    @State private var hop = Hop()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Замер до смещения, иначе прыжок сдвигал бы собственную мерку.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { spot.rect = $0 }
            .offset(y: lift)
            // Каждый новый круг — свой прыжок; ушедшие круги прыжков не
            // дают.
            .onChange(of: Cheer.shared.rings) { old, now in
                guard !reduceMotion else { return }
                for ring in now where !old.contains(ring) { ride(on: ring) }
            }
    }

    private func ride(on ring: WaterRing) {
        let middle = CGPoint(x: spot.rect.midX, y: spot.rect.midY)
        let far = hypot(middle.x - ring.origin.x, middle.y - ring.origin.y)
        let turn = Double(min(far / Metrics.waveReach, 1))
            * (1 - Metrics.popSpan)
        let wait = turn * Motion.cheerSeconds
            - Date().timeIntervalSince(ring.start)

        Task { @MainActor in
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            hop.serial &+= 1
            let mine = hop.serial
            withAnimation(Motion.rideUp) { lift = -Metrics.ride }
            try? await Task.sleep(for: .seconds(Motion.rideUpSeconds))
            // Следующий гребень уже поднял плашку — опустит он.
            guard hop.serial == mine else { return }
            withAnimation(Motion.rideDown) { lift = 0 }
        }
    }
}

/// Счёт прыжков вне состояния — по той же причине, что и замер.
private final class Hop {
    var serial = 0
}

extension View {
    func sproutRide() -> some View {
        modifier(Ride())
    }
}
