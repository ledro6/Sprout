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
    /// фото и не вытягивает читаемость текста.
    func sproutPlate(in shape: some Shape,
                     interactive: Bool = false) -> some View {
        glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
            // Нажатия ловит рамка вью — очерчиваем, чтобы тап у скруглённого
            // угла не проходил мимо.
            .contentShape(shape)
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

    /// Новый прыжок отменяет недождавшийся.
    @State private var hop = Hop()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Замер до смещения, иначе прыжок сдвигал бы собственную мерку.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { spot.rect = $0 }
            .offset(y: lift)
            .onChange(of: Cheer.shared.start) { _, now in
                guard let now, !reduceMotion else { return }
                ride(from: now)
            }
    }

    private func ride(from start: Date) {
        let middle = CGPoint(x: spot.rect.midX, y: spot.rect.midY)
        let far = hypot(middle.x - Cheer.shared.origin.x,
                        middle.y - Cheer.shared.origin.y)
        let turn = Double(min(far / Metrics.waveReach, 1))
            * (1 - Metrics.popSpan)
        let wait = turn * Motion.cheerSeconds - Date().timeIntervalSince(start)

        hop.run?.cancel()
        hop.run = Task { @MainActor in
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            withAnimation(Motion.rideUp) { lift = -Metrics.ride }
            try? await Task.sleep(for: .seconds(Motion.rideUpSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.rideDown) { lift = 0 }
        }
    }
}

/// Задача прыжка вне состояния — по той же причине, что и замер.
private final class Hop {
    var run: Task<Void, Never>?
}

extension View {
    func sproutRide() -> some View {
        modifier(Ride())
    }
}
