import SwiftUI

/// Заставка на холодном запуске. Держится, пока приложение поднимается под
/// ней, чтобы не было чёрного экрана; цвет тот же, что у системного экрана
/// запуска, иначе на стыке мигнуло бы.
struct Splash: View {
    /// Свойством, а не из окружения: заставка висит поверх вкладок, и сад
    /// туда не достаёт.
    let owner: String

    @State private var hello = false
    @State private var mark: Double = 0

    var body: some View {
        ZStack {
            Palette.welcome
                .ignoresSafeArea()

            SproutLogo(height: Metrics.welcomeLogo, aspect: SproutLogo.plain,
                       reveal: mark)

            VStack(spacing: 0) {
                Text(Seed.greeting(for: owner))
                    .font(Typography.welcome)
                    .foregroundStyle(Palette.welcomeInk)
                    .multilineTextAlignment(.center)
                    .modifier(Grow(shown: hello, blurs: true))
                Spacer(minLength: 0)
            }
            .padding(.top, Metrics.welcomeTop)
            .padding(.horizontal, Metrics.margin)
        }
        .task { await show() }
    }

    /// Первый шаг — не пауза для красоты: смену в том же проходе, где вью
    /// появилась, SwiftUI схлопывает. У логотипа ход линейный: разъезд частей
    /// задан внутри него.
    private func show() async {
        try? await Task.sleep(for: .milliseconds(30))
        withAnimation(Motion.welcomeIn) { hello = true }
        try? await Task.sleep(for: .seconds(Motion.welcomeStep))
        withAnimation(.linear(duration: Motion.logoSeconds)) { mark = 1 }
    }
}

/// Приветствие подрастает на место и собирается из размытия. Без сдвигов:
/// посреди пустого экрана любое движение вбок читалось бы промахом вёрстки.
private struct Grow: ViewModifier {
    let shown: Bool
    var blurs = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : Motion.welcomeScale)
            .blur(radius: blurs && !shown && !reduceMotion
                  ? Metrics.chromeBlur : 0)
            .opacity(shown ? 1 : 0)
    }
}
