import SwiftUI

/// Карточка растения: фото, кличка, влажность и срок полива.
///
/// Материал плашки общий для всего приложения — см. `sproutPlate`.
/// У карточки стекло отзывчивое: под пальцем оно проминается и
/// отпускает пружиной, всё это делает сама система.
struct PlantCard: View {
    let plant: Plant

    /// Гасятся вместе с тенью плашки — тем же флагом из окружения.
    @Environment(\.sproutHalos) private var halos

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
                // Смена процента идёт штатным переходом системы: старое
                // число размывается и уступает место новому. Подмена
                // опознаётся по самой подписи — от неё же и анимация.
                //
                // Стопка вокруг обязательна. Подмена — это удаление
                // одного текста и вставка другого, и мгновение оба живы;
                // в строке они встали бы рядом и толкнули кличку, а в
                // стопке ложатся друг на друга.
                ZStack(alignment: .trailing) {
                    Text(plant.moistureLabel)
                        .transition(.blurReplace)
                        .id(plant.moistureLabel)
                }
            }
            .font(Typography.cardTitle)
            .foregroundStyle(Palette.ink)
            .animation(Motion.number, value: plant.moistureLabel)

            Text(plant.wateringLabel)
                .font(Typography.cardCaption)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                // Наименьшая высота, а не жёсткая: подпись идёт за
                // настройкой размера текста, и на крупной ей нужно
                // больше двух строк в 24 пункта. Наименьшая при этом
                // держит карточки одной высоты, когда подпись короткая.
                .frame(minHeight: 24, alignment: .top)
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

    /// Тревожная тень: тот же ореол, что и обычная, только цветной и без
    /// смещения — он лежит вокруг карточки ровным кольцом, а внутри она
    /// остаётся нейтральной.
    ///
    /// Цвет ступенькой: оранжевый, пока влаги больше двадцати процентов,
    /// красный ниже. Сила — плавно, из самой влажности, поэтому с каждым
    /// процентом тень заметно ярче, а на смене цвета яркость не прыгает:
    /// красное подхватывает ровно там, где кончилось оранжевое.
    @ViewBuilder
    private var glow: some View {
        if plant.thirst != .calm {
            shape.sproutHalo(glowColour.opacity(glowStrength),
                             blur: Metrics.glowBlur)
                .modifier(Pulse(active: plant.moisture <= 0))
                .opacity(halos ? 1 : 0)
        }
    }

    private var glowColour: Color {
        plant.thirst == .alarm ? Palette.alarm : Palette.warn
    }

    private var glowStrength: Double {
        Metrics.glowFaint
            + (Metrics.glowFull - Metrics.glowFaint) * plant.alarm
    }
}

/// Пульс свечения у растения, досохшего до нуля.
///
/// Ноль — это уже не «скоро полить», а «проглядели», и ровная тень такое
/// не отличает от девяти процентов. Пульс отличает: он единственное на
/// экране, что движется само по себе, и взгляд цепляется за него даже
/// боковым зрением.
///
/// Медленный намеренно. Быстрое мигание читается поломкой и раздражает,
/// а на этом темпе — дыханием. При включённом «Уменьшении движения» не
/// пульсирует вовсе: свечение и так на месте, а настройка ровно про это.
private struct Pulse: ViewModifier {
    let active: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(active && dim ? Motion.pulseLow : 1)
            .onChange(of: active, initial: true) { _, on in
                guard on, !reduceMotion else {
                    dim = false
                    return
                }
                withAnimation(
                    .easeInOut(duration: Motion.pulsePeriod)
                        .repeatForever(autoreverses: true)
                ) {
                    dim = true
                }
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
    ///
    /// Ответ должен быть свежим на каждую пересборку карточки, а не
    /// снятым однажды. Сетка ленивая: уехавшую за край карточку она
    /// создаёт заново и берёт этот флаг из тела экрана — и если тело с
    /// прошлого раза не пересобиралось, флаг застывает на «играй». Ради
    /// этого журнал в сетке и лежит в состоянии, а не рядом с ним.
    let animates: Bool

    /// Сказать сетке, что эту карточку уже показали.
    let onShown: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Стоит ли карточка на своём месте.
    ///
    /// Начальное значение приходит из журнала сетки, а не «нет». Ленивая
    /// сетка выбрасывает уехавшие за край карточки и создаёт их заново, и
    /// с «нет» такая карточка первым кадром рисовалась прозрачной и
    /// сдвинутой: `onChange` с `initial` срабатывает уже после отрисовки,
    /// и на место она вставала только следующим кадром. Прокрутка идёт со
    /// своей анимацией, эта подстановка в неё попадала — и появление
    /// играло заново на каждом проходе. Теперь первый же кадр верный, и
    /// подставлять нечего.
    @State private var shown: Bool

    init(index: Int, room: Int, animates: Bool,
         onShown: @escaping () -> Void) {
        self.index = index
        self.room = room
        self.animates = animates
        self.onShown = onShown
        _shown = State(initialValue: !animates)
    }

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
