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

private struct SproutJigglingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Гаснет на время разворачивания карточки в экран: размытый слой не
    /// перетекает с карточкой, а смазывается хвостом.
    var sproutHalos: Bool {
        get { self[SproutHalosKey.self] }
        set { self[SproutHalosKey.self] = newValue }
    }

    /// Плашка качается — правка на главной, «Выбрать» в статистике; ставит
    /// `Jiggle`.
    var sproutJiggling: Bool {
        get { self[SproutJigglingKey.self] }
        set { self[SproutJigglingKey.self] = newValue }
    }
}

extension View {
    /// Материал плашек — системное стекло `.regular`, и ничего сверх него:
    /// вуаль и тень материал кладёт сам. Не `.clear` — он для панелей поверх
    /// фото и не вытягивает читаемость текста.
    func sproutPlate(in shape: some Shape,
                     interactive: Bool = false) -> some View {
        modifier(PlateGlass(shape: AnyShape(shape), interactive: interactive))
    }
}

/// Стекло плашки. Качаясь, стекло пересчитывало бы фон под собой на каждом
/// кадре и дёргалось; на время качания его сменяет плотная заливка того же
/// тона — плашка качается ровно, как карточка «Итогов года». Стекло не
/// снимается, а гаснет (`.identity`): вью остаётся тем же, и состояние
/// карточки не сбрасывается.
private struct PlateGlass: ViewModifier {
    let shape: AnyShape
    let interactive: Bool

    @Environment(\.sproutJiggling) private var jiggling

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(Palette.plateSolid)
                    .opacity(jiggling ? 1 : 0)
                    .animation(Motion.jiggleIn, value: jiggling)
            }
            .glassEffect(jiggling ? .identity
                         : interactive ? .regular.interactive() : .regular,
                         in: shape)
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
