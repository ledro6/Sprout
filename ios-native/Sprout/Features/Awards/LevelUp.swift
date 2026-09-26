import SwiftUI

/// Новый уровень садовника: затемнение, оранжерея нового уровня вырастает
/// на месте, сверху — золотые блёстки. Показывается после медалей.
struct LevelUp: View {
    let level: Int
    let done: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(shown ? 0.62 : 0))
                .ignoresSafeArea()
            Glitter(alloy: .gold)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 14) {
                Text("Новый уровень")
                    .font(Typography.groupTitle)
                    .foregroundStyle(.white.opacity(0.75))
                    .textCase(.uppercase)
                GlasshouseView(house: Gardener(
                    experience: Gardener.threshold(level)).glasshouse,
                               animated: true)
                    .frame(maxWidth: 320)
                    .environment(\.colorScheme, .dark)
                Text(Gardener.title(level))
                    .font(Typography.welcome)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(Lang.format("Уровень %lld", level))
                    .font(Typography.settingNote)
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
                Text("В оранжерее прибавилось жизни.")
                    .font(Typography.settingRow)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
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
