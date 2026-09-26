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

/// Вкладка входит плавно, как в «Музыке»: содержимое проявляется и чуть
/// подрастает. Фон остаётся на месте — вешается на содержимое, а не на фон,
/// иначе между вкладками мелькал бы пустой цвет. Ушла вкладка — сбрасывается
/// без анимации, чтобы в следующий раз войти снова. На входе в приложение
/// появление ведёт заставка, а при «Уменьшении движения» — сразу.
struct TabEntrance: ViewModifier {
    @Environment(\.tabShown) private var shown
    @Environment(\.accessibilityReduceMotion) private var still

    @State private var entered = false

    func body(content: Content) -> some View {
        content
            .opacity(entered ? 1 : 0)
            .scaleEffect(entered ? 1 : Motion.tabScale)
            .onChange(of: shown, initial: true) { _, now in
                guard now else {
                    var quiet = Transaction()
                    quiet.disablesAnimations = true
                    withTransaction(quiet) { entered = false }
                    return
                }
                if still || Launch.shared.step < Launch.last {
                    entered = true
                } else {
                    withAnimation(Motion.tab) { entered = true }
                }
            }
    }
}
