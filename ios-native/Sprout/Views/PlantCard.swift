import SwiftUI
import UIKit

/// Карточка растения: фото, кличка, влажность и срок полива.
///
/// Материал плашки общий для всего приложения — см. `sproutPlate`.
/// У карточки стекло отзывчивое: под пальцем оно проминается и
/// отпускает пружиной, всё это делает сама система.
struct PlantCard: View {
    let plant: Plant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlantPhoto(plant: plant)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

            HStack {
                // Кличку меняют переименованием — она собирается из
                // размытия тем же переходом, что и проценты рядом.
                Text(plant.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())
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
            .modifier(Sharpen())

            Text(plant.wateringLabel)
                .font(Typography.cardCaption)
                .foregroundStyle(Palette.ink)
                // Одна строка во всех видах подписи. С тех пор как из
                // неё ушло «через», самая длинная — «Следующий полив:
                // 22 дня» — в карточку помещается, и ужиматься уже
                // никому не приходится. Предел оставлен на случай
                // крупного шрифта в настройках.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Полили — «сегодня» сменяется сроком системным
                // размытием цифр, а не щелчком.
                .contentTransition(.numericText())
                .animation(Motion.number, value: plant.daysUntilWatering)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(Sharpen())
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
/// Рисуется своим слоем и останется своим: системная тень у плашки есть,
/// её кладёт сам материал, но она про то, что плашка приподнята над
/// фоном, а эта — про то, что растению сухо. Лежит вокруг плашки ровным
/// кольцом, без смещения, а внутри плашка остаётся нейтральной: цветное
/// под полупрозрачным стеклом красило бы её изнутри.
///
/// Цвет ступенькой: оранжевый, пока влаги больше
/// двадцати процентов, красный ниже. Сила плавно, из самой влажности,
/// поэтому с каждым процентом тень ярче, а на смене цвета яркость не
/// прыгает: красное подхватывает там, где кончилось оранжевое.
struct PlantGlow<S: Shape>: ViewModifier {
    let plant: Plant
    let shape: S

    /// Гаснет на время разворачивания карточки в экран — флагом из
    /// окружения. Слой этот отдельный и размытый, и в переходе он не
    /// перетекает вместе с карточкой, а смазывается за ней хвостом.
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
///
/// Зовётся дыханием, а не пульсом, и не только по смыслу: `Pulse` в модели
/// — форма отклика Taptic Engine, а два типа с одним именем в модуле
/// Xcode не пускает, даже когда один из них частный.
private struct Breath: ViewModifier {
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

/// Где какая карточка лежит на экране — по номеру растения.
///
/// Общий на приложение, а не состояние карточки, и это не экономия.
/// Состояние карточки принадлежит её месту в сетке, а не растению:
/// ленивая сетка создаёт и выбрасывает карточки на ходу, и замер, снятый
/// одной, мог достаться другой — волна уходила не от того растения,
/// которое полили. Здесь замер лежит под номером растения: кого поливают,
/// от того волна и идёт, чья бы вью его ни снимала.
final class Cards {
    static let shared = Cards()

    private var rects: [Plant.ID: CGRect] = [:]

    private init() {}

    func put(_ rect: CGRect, for id: Plant.ID) { rects[id] = rect }

    func rect(_ id: Plant.ID) -> CGRect { rects[id] ?? .zero }
}

/// Кто сейчас лежит в этой ячейке сетки.
///
/// Ссылка, а не значение, и это починка, а не украшение. Контекстное меню
/// живёт не в SwiftUI, а в UIKit: система ставит на вью распознаватель
/// долгого нажатия и держит при нём замыкания, собранные тогда, когда
/// распознаватель ставился. Ленивая сетка переиспользует вью под другое
/// растение — и замыкания у распознавателя остаются от прежнего. Нажатие
/// на нижнюю карточку поливало верхнюю: ту, что стояла в этой ячейке до
/// прокрутки.
///
/// Явный `id` у карточки этого не лечит: он задаёт личность узлу SwiftUI,
/// а замыкание уже запечатано в чужом распознавателе, и номер растения в
/// нём — копия, снятая в прошлой жизни ячейки.
///
/// Значение из запечатанного замыкания не вытащить. Ссылку — можно: она
/// одна и та же, а в ней всегда лежит тот, кто в ячейке сейчас. Живёт
/// ссылка в `@State`, то есть принадлежит месту в сетке — ровно как и
/// распознаватель, который её держит.
final class Tenant {
    var id: Plant.ID = ""
}

/// Меню растения по долгому нажатию: то же, что в панели на экране
/// растения, только не нужно туда заходить.
///
/// Отдельным типом, а не строками на каждом экране: меню одинаково на
/// главной и в поиске, а держать при нём приходится и переименование, и
/// переезд в новую комнату.
///
/// Удаление больше не спрашивает подтверждения: растение уходит сразу, и
/// пять секунд его можно вернуть с плашки внизу — см. `Bin`.
struct PlantMenu: ViewModifier {
    let id: Plant.ID

    /// Есть ли меню вообще. Пока правят порядок, его нет: долгое нажатие
    /// там поднимает карточку, чтобы её перетащить, и меню, всплывшее
    /// под пальцем, только мешало бы.
    var enabled = true

    @Environment(Garden.self) private var garden

    /// Что пришло снаружи: сетка гасит ореол у карточки, которую
    /// открывают. Своё гашение накладывается на это, а не отменяет его.
    @Environment(\.sproutHalos) private var halos

    @State private var renaming = false
    @State private var draft = ""

    /// Спрашивают ли имя новой комнаты, куда переезжать.
    @State private var moving = false
    @State private var roomDraft = ""

    /// Открыто ли меню. Ведём по предпросмотру: он живёт ровно столько
    /// же, и другого признака у контекстного меню нет.
    @State private var previewing = false

    /// Кто в этой ячейке сейчас. См. `Tenant`.
    @State private var tenant = Tenant()

    private var plant: Plant? { garden.plant(id: tenant.id) }

    func body(content: Content) -> some View {
        menu(content
            // Заселяем ячейку до всего остального: замыкания меню могут
            // быть какими угодно старыми, а читают они отсюда.
            .onChange(of: id, initial: true) { _, now in tenant.id = now }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { keep($0) }
            .environment(\.sproutHalos, halos && !previewing))
            .alert("Переименовать", isPresented: $renaming) {
                TextField("Кличка", text: $draft)
                Button("Отмена", role: .cancel) {}
                Button("Сохранить") {
                    // С анимацией: новая кличка на карточке собирается из
                    // размытия, а не подменяется щелчком.
                    withAnimation(Motion.number) {
                        garden.rename(tenant.id, to: draft)
                    }
                }
            } message: {
                Text("Как теперь зовут растение?")
            }
            .alert("Новая комната", isPresented: $moving) {
                TextField("Балкон", text: $roomDraft)
                Button("Отмена", role: .cancel) {}
                Button("Переехать") { relocate(to: roomDraft) }
            } message: {
                Text("Растение переедет туда, и комната появится в списке.")
            }
    }

    /// Само меню — или ничего, пока правят порядок.
    ///
    /// Ветвлением, а не пустым списком пунктов: пустое меню система всё
    /// равно может поднять одним предпросмотром, и перетаскивание с ним
    /// спорило бы за одно и то же удержание.
    @ViewBuilder
    private func menu(_ base: some View) -> some View {
        if enabled {
            base.contextMenu {
                Button { water() } label: {
                    Label("Полить сейчас", systemImage: "drop.fill")
                }
                Button {
                    draft = garden.plant(id: tenant.id)?.name ?? ""
                    renaming = true
                } label: {
                    Label("Переименовать", systemImage: "pencil")
                }
                // Комнаты — по номеру этого узла, а не жильца: пункты
                // строятся заново при каждой сборке тела, и номер здесь
                // всегда свежий. Запечатываются только нажатия, и они
                // идут через жильца.
                MoveMenu(current: garden.roomName(of: id),
                         rooms: garden.rooms.map(\.name),
                         move: relocate,
                         ask: {
                             roomDraft = ""
                             moving = true
                         })
                Button(role: .destructive) { toss() } label: {
                    Label("Удалить", systemImage: "trash")
                }
            } preview: {
                preview
            }
        } else {
            base
        }
    }

    /// Принять замер карточки — или не принять.
    ///
    /// Пустой замер отводим, и это не перестраховка. Открывая контекстное
    /// меню, система вынимает карточку из разметки и поднимает её в свой
    /// предпросмотр; на это время исходная вью отвечает то нулевым
    /// прямоугольником, то геометрией уже поднятой копии. Приняв такой
    /// замер, волна пошла бы из точки (0, 0) — то есть из левого верхнего
    /// угла экрана, где стоит первая карточка сетки. Ровно так это и
    /// выглядело: полил одно растение, а рябь пошла от другого.
    ///
    /// Пока меню открыто, не принимаем ничего: замер нужен тот, что был до
    /// него, — карточка стоит на своём месте и никуда не делась.
    private func keep(_ rect: CGRect) {
        guard !previewing, rect.width > 0, rect.height > 0 else { return }
        Cards.shared.put(rect, for: tenant.id)
    }

    /// Полить: сад меняет влажность, а по узору от карточки расходится
    /// волна.
    ///
    /// Полив с анимацией: проценты прыгают к сотне разом, и без неё
    /// тревожная тень гасла бы щелчком.
    private func water() {
        // Растения может уже не быть: меню держат открытым сколько угодно,
        // а сад за это время могли и поправить.
        // Номер берём у жильца, а не у самого модификатора: в замыкании
        // меню может быть запечатан номер прежнего растения этой ячейки.
        let who = tenant.id
        guard garden.plant(id: who) != nil else { return }
        withAnimation(Motion.appear) { garden.water(who) }
        // Замера может не оказаться вовсе — карточку могли полить, не
        // дождавшись первой разметки. Тогда волна идёт из середины экрана,
        // а не из угла: из угла она читается поломкой, из середины —
        // просто волной.
        let spot = Cards.shared.rect(who)
        Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
        Feel.water()
    }

    /// Удалить — сразу, с возможностью вернуть, и красным по узору от
    /// этой карточки. См. `Bin`.
    private func toss() {
        let who = tenant.id
        Bin.shared.toss(who, from: Cards.shared.rect(who), in: garden)
    }

    /// Перевезти в другую комнату. На главной карточка уходит из сетки —
    /// в этой комнате растения больше нет.
    private func relocate(to room: String) {
        let who = tenant.id
        withAnimation(Motion.appear) { garden.relocate(who, to: room) }
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
                // Ширина числом: предпросмотр — единственное место, где
                // размера не предлагают вовсе, а спрашивают у содержимого.
                // Без неё карточка сворачивалась бы по самому мелкому, что
                // в ней есть.
                .frame(width: Metrics.previewCard)
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
            // Текст карточки собирается из размытия, пока она всплывает, —
            // см. `Sharpen`. Через окружение, а не размытием всей карточки:
            // размывать стекло незачем, а фото в размытии читалось бы
            // пятном.
            .environment(\.sproutSharp, shown)
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

/// Собран ли текст на карточке — или ещё размыт, пока она всплывает.
private struct SproutSharpKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Текст карточки навёлся на резкость. Ставит появление карточки —
    /// `CardAppear`, читает `Sharpen`.
    var sproutSharp: Bool {
        get { self[SproutSharpKey.self] }
        set { self[SproutSharpKey.self] = newValue }
    }
}

/// Текст, который собирается из размытия вместе с появлением карточки.
///
/// Появление само по себе — подъём, приближение и проявление, — а текст
/// поверх него ещё и наводится на резкость, как цифры в системном
/// переходе: весь текст в приложении появляется размытием, и карточки не
/// исключение. Размывается только текст — стекло и фото приходят как
/// приходили.
struct Sharpen: ViewModifier {
    @Environment(\.sproutSharp) private var sharp
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.blur(radius: sharp || reduceMotion ? 0 : Metrics.textBlur)
    }
}
