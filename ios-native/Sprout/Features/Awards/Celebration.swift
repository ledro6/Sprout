import SwiftUI

/// Новая награда: затемнение, медаль влетает вращением, сверху сыплются
/// блёстки её металла. Одна за раз; следующая — после «Отлично».
struct Celebration: View {
    let award: Award
    let done: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(shown ? 0.62 : 0))
                .ignoresSafeArea()
            Glitter(alloy: award.alloy)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                Text("Новая награда")
                    .font(Typography.groupTitle)
                    .foregroundStyle(.white.opacity(0.75))
                    .textCase(.uppercase)
                MedalStage(award: award, earned: true, spinIn: true)
                    .frame(height: 300)
                Text(award.title)
                    .font(Typography.welcome)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(award.detail)
                    .font(Typography.settingRow)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    withAnimation(Motion.leave) { shown = false }
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        done()
                    }
                } label: {
                    Text("Отлично")
                        .font(Typography.detail)
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.top, 10)
            }
            .padding(.horizontal, 28)
            .scaleEffect(shown ? 1 : 0.86)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.28)) { shown = true }
            Feel.done()
            Chime.save.play()
        }
    }
}

/// Блёстки — квадратики металла медали и белые искры: падают, кружатся и
/// гаснут за три секунды. Холстом, по кадрам: сотня вью была бы дороже.
private struct Glitter: View {
    let alloy: Alloy

    @State private var start = Date()

    @Environment(\.accessibilityReduceMotion) private var still

    private static let count = 90
    private static let seconds = 3.2

    var body: some View {
        if still {
            Color.clear
        } else {
            TimelineView(.animation) { frame in
                let elapsed = frame.date.timeIntervalSince(start)
                Canvas { context, size in
                    guard elapsed < Self.seconds else { return }
                    for index in 0 ..< Self.count {
                        draw(index, at: elapsed, in: size, into: &context)
                    }
                }
            }
        }
    }

    /// Всё о блёстке — из её номера: без случайных чисел кадр от кадра не
    /// мигал бы.
    private func draw(_ index: Int, at time: Double, in size: CGSize,
                      into context: inout GraphicsContext) {
        func unit(_ salt: Int) -> Double {
            let mixed = (index &* 2_654_435_761 &+ salt &* 40_503) & 0xFFFF
            return Double(mixed) / Double(0xFFFF)
        }
        let delay = unit(1) * 0.8
        let t = time - delay
        guard t > 0 else { return }
        let fall = 180 + unit(2) * 220
        let wobble = sin(t * (1.5 + unit(4) * 2)) * 18
        let x = CGFloat(unit(3) * Double(size.width) + wobble)
        let drop = -20 + t * fall + 60 * t * t
        guard drop < Double(size.height) + 20 else { return }
        let y = CGFloat(drop)
        let fade = max(0, 1 - t / (Self.seconds - delay))
        let spin = t * (3 + unit(5) * 5) + unit(6) * .pi
        let side = CGFloat(5 + unit(7) * 6)
        let sparkle = index % 4 == 0
        let tone = Channels.mix(alloy.dark, alloy.light, 0.4 + unit(8) * 0.6)
        let colour = sparkle ? Color.white
            : Color(red: tone.red / 255, green: tone.green / 255,
                    blue: tone.blue / 255)
        var piece = context
        piece.opacity = fade
        piece.translateBy(x: x, y: y)
        piece.rotate(by: .radians(spin))
        // Плоский квадратик, повёрнутый ребром, — сжат по одной оси.
        piece.scaleBy(x: 1, y: CGFloat(abs(cos(spin * 0.7)) * 0.8 + 0.2))
        let rect = CGRect(x: -side / 2, y: -side / 2, width: side,
                          height: sparkle ? side / 2 : side)
        piece.fill(Path(roundedRect: rect, cornerRadius: 1.2),
                   with: .color(colour))
    }
}
