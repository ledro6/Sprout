import SwiftUI

/// Выбрана ли вкладка, в которой лежит экран, — ставит корень.
private struct TabShownKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var tabShown: Bool {
        get { self[TabShownKey.self] }
        set { self[TabShownKey.self] = newValue }
    }
}

/// Вкладка входит плавно, как в «Музыке»: содержимое проявляется. Не
/// прозрачностью самого содержимого: стекло карточек и мягкий край под
/// шапкой у полупрозрачного предка рисуются неверно и вспыхивали в конце —
/// элементы появлялись неровно. Поверх содержимого на миг ложится тот же
/// фон, что под ним, и растворяется: всё проявляется разом, одним слоем.
/// Ушла вкладка — вуаль ложится снова, без анимации. На входе в
/// приложение появление ведёт заставка, при «Уменьшении движения» — сразу.
struct TabEntrance: ViewModifier {
    /// Небо главной — часть её фона: вуаль повторяет и его.
    var sky = false

    @Environment(\.tabShown) private var shown
    @Environment(\.accessibilityReduceMotion) private var still

    @State private var veiled = true

    func body(content: Content) -> some View {
        content
            .overlay {
                if veiled {
                    ZStack {
                        SproutField()
                        if sky { DaySky() }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .onChange(of: shown, initial: true) { _, now in
                if now, !still, Launch.shared.step >= Launch.last {
                    withAnimation(Motion.tab) { veiled = false }
                } else {
                    var quiet = Transaction()
                    quiet.disablesAnimations = true
                    withTransaction(quiet) { veiled = !now }
                }
            }
    }
}
