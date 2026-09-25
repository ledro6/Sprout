import SwiftUI

/// Тревожная тень под плашкой — одна на карточку и экран растения, чтобы
/// влажность читалась одинаково. Своим слоем, кольцом вокруг плашки: цветное
/// под стеклом красило бы её изнутри. Цвет ступенькой (оранжевый → красный на
/// 20%), сила — плавно.
struct PlantGlow<S: Shape>: ViewModifier {
    let plant: Plant
    let shape: S

    /// Гаснет на время разворачивания карточки: размытый слой смазывался бы
    /// за ней хвостом.
    @Environment(\.sproutHalos) private var halos

    func body(content: Content) -> some View {
        content.background { glow }
    }

    private var glow: some View {
        ZStack {
            if plant.thirst != .calm {
                shape.sproutHalo(alarmColour.opacity(alarmStrength),
                                 blur: Metrics.glowBlur)
                    .modifier(Breath(active: plant.moisture <= 0,
                                     phase: plant.pulsePhase))
            }
        }
        .opacity(halos ? 1 : 0)
    }

    private var alarmColour: Color {
        plant.thirst == .alarm ? Palette.alarm : Palette.warn
    }

    private var alarmStrength: Double {
        Metrics.glowFaint
            + (Metrics.glowFull - Metrics.glowFaint) * plant.alarm
    }

}

/// Пульс свечения у растения, досохшего до нуля: ровная тень не отличает ноль
/// от девяти процентов. Медленный — читается дыханием; при «Уменьшении
/// движения» не пульсирует. Не `Pulse`: это имя уже занято в модуле.
private struct Breath: ViewModifier {
    let active: Bool

    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    /// Свой период у каждого растения: с одним на всех карточки дышали бы
    /// строем.
    private var period: Double {
        Motion.pulsePeriod * (1 + Motion.pulseSpread * (phase - 0.5))
    }

    func body(content: Content) -> some View {
        content
            .opacity(active && dim ? Motion.pulseLow : 1)
            .onChange(of: active, initial: true) { _, on in
                guard on, !reduceMotion else {
                    dim = false
                    return
                }
                withAnimation(
                    .easeInOut(duration: period)
                        .repeatForever(autoreverses: true)
                ) {
                    dim = true
                }
            }
    }
}
