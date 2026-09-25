import SwiftUI

/// Появление карточки: подъём с приближением одной пружиной, соседние — со
/// сдвигом. Один раз на комнату: уехавшие за край карточки ленивая сетка
/// создаёт заново, и без журнала они всплывали бы снова.
struct CardAppear: ViewModifier {
    let index: Int

    /// Появление привязано к номеру комнаты, а не к `onAppear`: вернувшись в
    /// комнату, SwiftUI переиспользует карточку с состоянием.
    let room: Int

    /// Журнал показанных ведёт сетка — она живёт дольше карточки. Флаг должен
    /// быть свежим на каждую пересборку, поэтому журнал в состоянии экрана.
    let animates: Bool

    let onShown: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Начальное значение — из журнала, а не «нет»: с «нет» пересозданная
    /// карточка первым кадром была прозрачной, и появление играло на каждой
    /// прокрутке.
    @State private var shown: Bool

    init(index: Int, room: Int, animates: Bool,
         onShown: @escaping () -> Void) {
        self.index = index
        self.room = room
        self.animates = animates
        self.onShown = onShown
        _shown = State(initialValue: !animates)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : Motion.scale, anchor: .top)
            .offset(y: shown ? 0 : Motion.rise)
            // Через окружение, а не размытием всей карточки: размываем только
            // текст, не стекло и фото.
            .environment(\.sproutSharp, shown)
            .onChange(of: room, initial: true) { _, _ in restart() }
    }

    private func restart() {
        guard animates, !reduceMotion else {
            shown = true
            return
        }
        shown = false
        // Следующим проходом: сброс и подъём в одном проходе SwiftUI
        // схлопнет, а менять журнал посреди отрисовки сетки нельзя.
        Task { @MainActor in
            onShown()
            withAnimation(Motion.appear.delay(Double(index) * Motion.stagger)) {
                shown = true
            }
        }
    }
}

private struct SproutSharpKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Ставит `CardAppear`, читает `Sharpen`.
    var sproutSharp: Bool {
        get { self[SproutSharpKey.self] }
        set { self[SproutSharpKey.self] = newValue }
    }
}

/// Текст карточки наводится на резкость, пока карточка всплывает.
struct Sharpen: ViewModifier {
    @Environment(\.sproutSharp) private var sharp
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.blur(radius: sharp || reduceMotion ? 0 : Metrics.textBlur)
    }
}
