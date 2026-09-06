import SwiftUI

/// Карточка растения: стеклянная плашка, фото, кличка, влажность и срок
/// полива.
///
/// Тени на самом стекле нет намеренно. `.shadow` заставляет систему
/// растеризовать вью отдельным слоем, стекло при этом теряет фон, который
/// должно преломлять, и превращается в глухую тёмную плашку. Всё, что
/// нужно нарисовать за стеклом, кладётся в `.background` — он рисуется
/// позади вью вместе со стеклом, и стекло его честно преломляет.
struct PlantCard: View {
    let plant: Plant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(plant.photo)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

            HStack {
                Text(plant.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text(plant.moistureLabel)
            }
            .font(Typography.cardTitle)
            .foregroundStyle(.black)

            Text(plant.wateringLabel)
                .font(Typography.cardCaption)
                .foregroundStyle(.black)
                .lineLimit(2)
                .frame(height: 24, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .glassEffect(.clear.interactive(), in: shape)
        .background {
            ZStack {
                shadow
                glow
            }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }

    /// Тень под карточкой.
    ///
    /// Силуэт самой карточки из тени вырезается. Это не украшательство:
    /// стекло прозрачное и преломляет всё, что лежит в `.background`, —
    /// тень без выреза оказалась бы прямо под карточкой и замутила бы её
    /// изнутри. В макете у этой тени по той же причине стоит
    /// «не рисовать под самим слоем».
    private var shadow: some View {
        ZStack {
            shape
                .fill(Palette.cardShadow)
                .blur(radius: Metrics.cardShadowBlur)
                .offset(y: Metrics.cardShadowY)
            shape
                .fill(.black)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    /// Тревожное свечение — ореолом по контуру, а не заливкой: заливка
    /// просвечивала бы сквозь прозрачное стекло и красила саму карточку,
    /// а в макете розовое лежит вокруг неё.
    @ViewBuilder
    private var glow: some View {
        if plant.thirst != .calm {
            shape
                .stroke(
                    plant.thirst == .now ? Palette.thirstyNow : Palette.thirsty,
                    lineWidth: Metrics.glowWidth)
                .blur(radius: Metrics.glowBlur)
                .opacity(Metrics.glowAttenuation)
        }
    }
}

/// Появление карточки: поднимается снизу, чуть приближаясь, и
/// проявляется. Соседняя стартует на полкадра позже — сетка не
/// подставляется разом, а набегает волной.
///
/// Движение взято с ленты Сообщений: там при прокрутке вверх содержимое
/// приходит одной пружиной, без затухающей кривой, и потому читается как
/// продолжение жеста, а не как проигранный ролик.
struct CardAppear: ViewModifier {
    /// Порядковый номер карточки в сетке — от него задержка.
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.9, anchor: .top)
            .offset(y: shown ? 0 : 26)
            .onAppear(perform: reveal)
    }

    private func reveal() {
        guard !reduceMotion else {
            shown = true
            return
        }
        withAnimation(
            .spring(duration: 0.45, bounce: 0.28)
                .delay(Double(index) * 0.055)
        ) {
            shown = true
        }
    }
}
