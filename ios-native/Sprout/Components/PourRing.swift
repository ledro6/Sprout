import SwiftUI

/// Отклик на полив у самой кнопки: кольцо воды расходится от неё и гаснет
/// за ≈400 мс (`Motion.pourSeconds`). При «Уменьшении движения» кольца нет —
/// только смена состояния кнопки и лёгкая хаптика (`Feel.water`).
struct PourRing<Outline: Shape>: ViewModifier {
    let shape: Outline
    /// Растёт на каждый полив — кольцо стартует заново.
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var still

    private struct Ring {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }

    func body(content: Content) -> some View {
        content.overlay {
            if !still {
                shape
                    .stroke(Palette.water, lineWidth: 2)
                    .keyframeAnimator(initialValue: Ring(),
                                      trigger: trigger) { ring, value in
                        ring
                            .scaleEffect(value.scale)
                            .opacity(value.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            CubicKeyframe(Motion.pourSpread,
                                          duration: Motion.pourSeconds)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(0.9, duration: 0.04)
                            LinearKeyframe(0, duration: Motion.pourSeconds - 0.04)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    /// Кольцо полива вокруг кнопки формы `shape`, см. `PourRing`.
    func pourRing(_ shape: some Shape, trigger: Int) -> some View {
        modifier(PourRing(shape: shape, trigger: trigger))
    }
}
