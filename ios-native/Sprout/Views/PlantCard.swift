import SwiftUI

/// Карточка растения: фото, кличка, влажность и срок полива.
///
/// Материал плашки общий для всего приложения — см. `sproutPlate`.
/// У карточки стекло отзывчивое: под пальцем оно проминается и
/// отпускает пружиной, всё это делает сама система.
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
        .sproutPlate(in: shape, interactive: true)
        .background { glow }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }

    /// Тревожное свечение: тот же ореол, что и тень, только красный и без
    /// смещения. В макете розовое лежит строго вокруг карточки — внутри
    /// она остаётся нейтральной.
    @ViewBuilder
    private var glow: some View {
        if plant.thirst != .calm {
            shape.sproutHalo(
                plant.thirst == .now ? Palette.thirstyNow : Palette.thirsty,
                blur: Metrics.glowBlur)
        }
    }
}

/// Кто в этой комнате уже всплыл.
///
/// Класс, а не множество в состоянии экрана, — намеренно. Пометка
/// «показана» приходит по одной на карточку, и в состоянии каждая из них
/// перерисовывала бы весь экран вместе с фоном: восемь перерисовок за те
/// же полсекунды, что идёт волна. Ссылочный тип в `@State` живёт ровно
/// столько же, но SwiftUI за ним не следит и на записи не отзывается —
/// а следить и не нужно, показ карточка ведёт своим состоянием.
final class RevealLog {
    private var shown: Set<String> = []

    func contains(_ id: String) -> Bool { shown.contains(id) }
    func insert(_ id: String) { shown.insert(id) }
    func reset() { shown.removeAll() }
}

/// Появление карточки: поднимается снизу, чуть приближаясь, и
/// проявляется. Соседняя стартует на полкадра позже — сетка не
/// подставляется разом, а набегает волной.
///
/// Движение взято с ленты Сообщений: там при прокрутке вверх содержимое
/// приходит одной пружиной, без затухающей кривой, и потому читается как
/// продолжение жеста, а не как проигранный ролик.
///
/// Каждая карточка играет один раз на комнату. Кто уже показался, тот
/// при обратной прокрутке просто стоит на месте: сетка ленивая, уехавшие
/// за край карточки она выбрасывает и создаёт заново, и без этого они
/// заново всплывали бы на каждом проходе.
struct CardAppear: ViewModifier {
    /// Порядковый номер карточки в сетке — от него задержка.
    let index: Int

    /// Номер комнаты. Появление привязано к нему, а не к появлению вью:
    /// на `onAppear` полагаться нельзя — вернувшись в уже открытую
    /// комнату, SwiftUI переиспользует карточку вместе с её состоянием,
    /// и играть становится нечего.
    let room: Int

    /// Играть ли вообще. Список показанных ведёт сетка: она живёт дольше
    /// карточки и потому помнит то, чего сама карточка помнить не может.
    let animates: Bool

    /// Сказать сетке, что эту карточку уже показали.
    let onShown: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : Motion.scale, anchor: .top)
            .offset(y: shown ? 0 : Motion.rise)
            .onChange(of: room, initial: true) { _, _ in restart() }
    }

    private func restart() {
        guard animates, !reduceMotion else {
            // Эту карточку в комнате уже показывали — она просто на месте.
            shown = true
            return
        }
        shown = false
        // Отметка и подъём уходят следующим проходом. Сброс и подъём в
        // одном проходе SwiftUI схлопнёт — анимировать станет нечего, — а
        // помечать карточку показанной прямо в обновлении вью значит
        // менять состояние сетки посреди её же отрисовки.
        Task { @MainActor in
            onShown()
            withAnimation(Motion.appear.delay(Double(index) * Motion.stagger)) {
                shown = true
            }
        }
    }
}
