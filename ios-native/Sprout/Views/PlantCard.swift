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
                // Числовой переход системы: меняются только сами цифры,
                // они пролистываются вверх и на ходу размываются, а знак
                // процента стоит на месте. Подмены текста целиком тут
                // нет — значит, нет и двух текстов разом, толкающих
                // кличку вбок.
                Text(plant.moistureLabel)
                    .contentTransition(.numericText())
            }
            .font(Typography.cardTitle)
            .foregroundStyle(Palette.ink)
            .animation(Motion.number, value: plant.moisture)

            Text(plant.wateringLabel)
                .font(Typography.cardCaption)
                .foregroundStyle(Palette.ink)
                // Одна строка во всех видах подписи. Самая длинная — «до
                // 22 дней» — чуть шире карточки, и на неё одну текст
                // ужимается; остальные встают как есть.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .sproutPlate(in: shape, interactive: true)
        .modifier(PlantGlow(plant: plant, shape: shape))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }
}

/// Тень под плашкой растения: тревожная и всплеск при поливе.
///
/// Одна на оба экрана. На витрине и на самом растении состояние у
/// плашки то же самое, и считаться оно должно одинаково — иначе одна и
/// та же влажность читалась бы там и там по-разному.
///
/// Тревожная — тот же ореол, что и обычная тень, только цветной и без
/// смещения: он лежит вокруг плашки ровным кольцом, а внутри она
/// остаётся нейтральной. Цвет ступенькой: оранжевый, пока влаги больше
/// двадцати процентов, красный ниже. Сила плавно, из самой влажности,
/// поэтому с каждым процентом тень ярче, а на смене цвета яркость не
/// прыгает: красное подхватывает там, где кончилось оранжевое.
struct PlantGlow<S: Shape>: ViewModifier {
    let plant: Plant
    let shape: S

    /// Гасится вместе с тенью плашки — тем же флагом из окружения.
    @Environment(\.sproutHalos) private var halos

    /// Идёт ли сейчас всплеск и насколько он ещё ярок.
    ///
    /// Два состояния, а не одно: доля нужна для яркости, а признак — для
    /// того, чтобы убрать слой совсем. Гасить слой по нулевой доле
    /// нельзя, тело вью видит конечное значение сразу, и всплеск исчез бы
    /// в тот же кадр, не начавшись.
    @State private var splashing = false
    @State private var splash: Double = 0

    func body(content: Content) -> some View {
        content
            .background { glow }
            // Полив ловим по самой влажности: поднять её больше нечему, а
            // поливают из двух меню и с двух экранов — всплеск должен
            // быть один и тот же, откуда бы ни пришёл.
            .onChange(of: plant.moisture) { was, now in
                if now > was { flash() }
            }
    }

    private var glow: some View {
        ZStack {
            if plant.thirst != .calm {
                shape.sproutHalo(alarmColour.opacity(alarmStrength),
                                 blur: Metrics.glowBlur)
                    .modifier(Pulse(active: plant.moisture <= 0,
                                    phase: plant.pulsePhase))
            }
            if splashing {
                // Всплеск не расходится, а стягивается: в начале свечение
                // широкое и размытое, к концу сходится к обычному ореолу
                // и гаснет. Расходись оно — уехало бы за плашку, и вместо
                // свечения читалась бы вторая рамка со своим краем.
                shape.sproutHalo(Palette.splash.opacity(Metrics.glowSplash),
                                 blur: splashBlur)
                    .opacity(splash)
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

    /// Размытие всплеска: широкое в начале, обычное к концу.
    private var splashBlur: CGFloat {
        Metrics.glowBlur * (1 + Metrics.splashSpread * CGFloat(splash))
    }

    /// Полили: ореол вспыхивает синим во всю силу и стягивается.
    ///
    /// Волну по фону отсюда не пускаем, хотя раньше пускали. Полив ловится
    /// по влажности, а её подъём видят все плашки этого растения разом —
    /// и карточка на витрине, и плашка на его экране. Кто из них позовёт
    /// волну первым, не определено, а точка у волны от этого разная. Зовёт
    /// её теперь та кнопка, которую нажали.
    private func flash() {
        splashing = true
        splash = 1
        withAnimation(Motion.splash) { splash = 0 }
        // Слой снимаем, когда всплеск отыграл. По самой доле этого не
        // узнать: она станет нулём в теле вью сразу.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.splashSeconds))
            splashing = false
        }
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

    /// Доля разброса, 0…1. Своя у каждого растения — считается от его
    /// клички.
    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    /// Свой период у каждого растения, вокруг общего.
    ///
    /// Одного сдвига фазы мало: при одинаковом периоде карточки идут
    /// параллельно, и разница читается небрежностью, а не несколькими
    /// растениями. С разным периодом они расходятся и сходятся сами, и в
    /// такт не собираются никогда.
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

/// Меню растения по долгому нажатию: то же, что в панели на экране
/// растения, только не нужно туда заходить.
///
/// Отдельным типом, а не строками на каждом экране: меню одинаково на
/// главной и в поиске, а держать при нём приходится и переименование, и
/// подтверждение удаления.
struct PlantMenu: ViewModifier {
    let id: Plant.ID

    @Environment(Garden.self) private var garden

    /// Что пришло снаружи: сетка гасит ореол у карточки, которую
    /// открывают. Своё гашение накладывается на это, а не отменяет его.
    @Environment(\.sproutHalos) private var halos

    @State private var renaming = false
    @State private var draft = ""
    @State private var deleting = false

    /// Открыто ли меню. Ведём по предпросмотру: он живёт ровно столько
    /// же, и другого признака у контекстного меню нет.
    @State private var previewing = false

    /// Где карточка лежит на экране. Отсюда по фону расходится волна:
    /// нажали на карточку — от неё и пошло. Не состоянием — см. `Spot`.
    @State private var spot = Spot()

    private var plant: Plant? { garden.plant(id: id) }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { spot.rect = $0 }
            .environment(\.sproutHalos, halos && !previewing)
            .contextMenu {
                Button { water() } label: {
                    Label("Полить сейчас", systemImage: "drop.fill")
                }
                Button {
                    draft = plant?.name ?? ""
                    renaming = true
                } label: {
                    Label("Переименовать", systemImage: "pencil")
                }
                Button(role: .destructive) { deleting = true } label: {
                    Label("Удалить", systemImage: "trash")
                }
            } preview: {
                preview
            }
            .alert("Переименовать", isPresented: $renaming) {
                TextField("Кличка", text: $draft)
                Button("Отмена", role: .cancel) {}
                Button("Сохранить") { garden.rename(id, to: draft) }
            } message: {
                Text("Как теперь зовут растение?")
            }
            .confirmationDialog("Удалить «\(plant?.name ?? "")»?",
                                isPresented: $deleting,
                                titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { garden.delete(id) }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Растение исчезнет из комнаты. Вернуть его будет нельзя.")
            }
    }

    /// Полить: сад меняет влажность, а по узору от карточки расходится
    /// волна.
    ///
    /// Полив с анимацией: проценты прыгают к сотне разом, и без неё
    /// тревожная тень гасла бы щелчком.
    private func water() {
        withAnimation(Motion.appear) { garden.water(id) }
        Cheer.shared.now(from: spot.rect)
    }

    /// Предпросмотр для меню — свой, а не системный снимок.
    ///
    /// Снимок берётся с карточки как есть, вместе с ореолом, и в меню она
    /// всплывает со свечением вокруг. Свой предпросмотр рисуется без него.
    ///
    /// Он же — единственный признак, по которому видно, что меню
    /// закрылось: предпросмотр исчезает вместе с ним. Отсюда и возврат
    /// ореола — тот же, что после закрытия экрана растения: секунду его
    /// нет, потом он набирает яркость.
    @ViewBuilder
    private var preview: some View {
        if let plant {
            PlantCard(plant: plant)
                .environment(\.sproutHalos, false)
                .onAppear { previewing = true }
                .onDisappear {
                    withAnimation(Motion.halo) { previewing = false }
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
