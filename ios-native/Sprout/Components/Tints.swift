import SwiftUI

/// Замеры кружков и клеток. Не состоянием: меняются каждый кадр прокрутки, а
/// нужны только в миг нажатия — откуда пустить волну.
final class Spots {
    private var rects: [Int: CGRect] = [:]

    func put(_ rect: CGRect, at key: Int) { rects[key] = rect }

    func rect(_ key: Int) -> CGRect { rects[key] ?? .zero }
}

/// Ряд кружков с оттенками — насыщенной ипостасью, с тонкой обводкой. Замер
/// кружка отдаётся выбирающему: волна идёт оттуда, где попали пальцем.
struct SproutTints: View {
    let current: Tint
    let spots: Spots
    let pick: (Tint, CGRect) -> Void

    init(current: Tint, spots: Spots,
         pick: @escaping (Tint, CGRect) -> Void) {
        self.current = current
        self.spots = spots
        self.pick = pick
    }

    /// По шесть в ряд: одиннадцать кружков в одну строку не влезают.
    private static let columns = Array(repeating: GridItem(.flexible(),
                                                           spacing: 6),
                                       count: 6)

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 8) {
            ForEach(Tint.allCases) { tint in
                let picked = tint == current
                Button {
                    withAnimation(Motion.pill) {
                        pick(tint, spots.rect(tint.rawValue))
                    }
                } label: {
                    Circle()
                        .fill(Palette.swatch(tint))
                        .overlay {
                            Circle().strokeBorder(Palette.ink.opacity(0.12),
                                                  lineWidth: 0.5)
                        }
                        .frame(width: Metrics.swatch, height: Metrics.swatch)
                        .padding(4)
                        .overlay {
                            if picked {
                                Circle().strokeBorder(Palette.accent,
                                                      lineWidth: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tint.title)
                .accessibilityAddTraits(picked ? .isSelected : [])
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                    action: { spots.put($0, at: tint.rawValue) }
            }
        }
    }
}
