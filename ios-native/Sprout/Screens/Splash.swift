import SwiftUI

/// Заставка на холодном запуске: приветствие и логотип на зелёном.
///
/// Экран из макета — «приветственный экран». Он не заставляет ждать: пока
/// он на экране, приложение уже поднимается под ним, и держится он ровно
/// затем, чтобы на месте поднимающегося не было чёрного прямоугольника.
///
/// Цвет фона тот же, что у системного экрана запуска (набор `Launch` в
/// каталоге). Системный показывается раньше, чем SwiftUI успевает нарисовать
/// первый кадр, и разного цвета они мигнули бы стыком.
struct Splash: View {
    /// Приветствие из макета. Имя в нём записано прямо — своего у
    /// приложения пока нет: ни учётной записи, ни настроек.
    private static let greeting = "Добро пожаловать, Святослав!"

    /// Всплыло ли приветствие. Логотип отдельно и не флагом: он
    /// собирается по частям, и ему нужна доля, а не «да/нет».
    @State private var hello = false
    @State private var mark: Double = 0

    var body: some View {
        ZStack {
            Palette.welcome
                .ignoresSafeArea()

            // Логотип ровно посередине экрана — так он стоит и в макете:
            // от него до верха и до низа поровну.
            SproutLogo(height: Metrics.welcomeLogo, aspect: SproutLogo.plain,
                       reveal: mark)

            VStack(spacing: 0) {
                Text(Self.greeting)
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

    /// Приветствие, следом логотип — а тот сам собой по частям.
    ///
    /// Первый шаг — не пауза для красоты. Смену, случившуюся в том же
    /// проходе, где вью появилась, SwiftUI схлопывает: элементы просто
    /// оказались бы на месте, и всплывать было бы нечему.
    ///
    /// У логотипа ход ровный, без пружины: разъезд частей задан внутри
    /// него задержками, и кривая снаружи их бы перекосила.
    private func show() async {
        try? await Task.sleep(for: .milliseconds(30))
        withAnimation(Motion.welcomeIn) { hello = true }
        try? await Task.sleep(for: .seconds(Motion.welcomeStep))
        withAnimation(.linear(duration: Motion.logoSeconds)) { mark = 1 }
    }
}

/// Появление приветствия: подрастает на место из мелкого, прозрачного и
/// размытого.
///
/// Просто подрастает — ни подъёма, ни разъезда: строка стоит посреди
/// пустого экрана, и любое движение вбок или вверх читалось бы там
/// промахом вёрстки, а рост — появлением.
///
/// Размытие ей нужно сверх роста. Буквам роста мало: мелкий текст
/// читается не мелким текстом, а неразборчивым, и глаз цепляется за него
/// раньше, чем тот встал на место. Из размытия он собирается ровно тогда,
/// когда его можно прочесть.
///
/// Логотип этим модификатором не пользуется: он собирается по частям и
/// растит их сам, внутри своего холста.
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
