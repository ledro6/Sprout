import SwiftUI
import UIKit

/// Карточка растения: фото, кличка, влажность и срок полива.
struct PlantCard: View {
    let plant: Plant

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlantPhoto(plant: plant)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

            HStack {
                Text(plant.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())
                Spacer(minLength: 4)
                // Переход цифр: знак процента стоит на месте, и кличку ничто
                // не толкает вбок.
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
                // Одна строка: самая длинная подпись помещается; предел — на
                // случай крупного шрифта.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

/// Тревожная тень под плашкой — одна на карточку и экран растения, чтобы
/// влажность читалась одинаково. Своим слоем, кольцом вокруг плашки: цветное
/// под стеклом красило бы её изнутри. Цвет ступенькой (оранжевый → красный на
/// 20%), сила — плавно.
struct PlantGlow<S: Shape>: ViewModifier {
    let plant: Plant
    let shape: S

    /// Гаснет на время разворачивания карточки: размытый слой смазывался бы
    /// за ней хвостом.
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

/// Пульс свечения у растения, досохшего до нуля: ровная тень не отличает ноль
/// от девяти процентов. Медленный — читается дыханием; при «Уменьшении
/// движения» не пульсирует. Не `Pulse`: это имя уже занято в модуле.
private struct Breath: ViewModifier {
    let active: Bool

    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    /// Свой период у каждого растения: с одним на всех карточки дышали бы
    /// строем.
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

/// Где какая карточка на экране — по номеру растения, а не в состоянии
/// ячейки: ленивая сетка переиспользует ячейки, и волна уходила бы не от того
/// растения.
final class Cards {
    static let shared = Cards()

    private var rects: [Plant.ID: CGRect] = [:]

    private init() {}

    func put(_ rect: CGRect, for id: Plant.ID) { rects[id] = rect }

    func rect(_ id: Plant.ID) -> CGRect { rects[id] ?? .zero }
}

/// Кто сейчас в этой ячейке сетки.
///
/// Контекстное меню живёт в UIKit и держит замыкания, собранные, когда его
/// ставили. Ленивая сетка переиспользует вью под другое растение, а замыкания
/// остаются от прежнего — поливалось не то растение. Явный `id` этого не
/// лечит. Ссылка в `@State` лечит: замыкание старое, но читает из неё того,
/// кто в ячейке сейчас.
final class Tenant {
    var id: Plant.ID = ""
}

/// Меню растения по долгому нажатию — одно на главную и поиск. Удаление без
/// подтверждения: вернуть можно с плашки, см. `Bin`.
struct PlantMenu: ViewModifier {
    let id: Plant.ID

    /// В правке меню нет: долгое нажатие там поднимает карточку для
    /// перетаскивания.
    var enabled = true

    @Environment(Garden.self) private var garden

    /// Своё гашение накладывается на внешнее, а не отменяет его.
    @Environment(\.sproutHalos) private var halos

    @State private var renaming = false
    @State private var draft = ""

    @State private var moving = false
    @State private var roomDraft = ""

    /// Чьи настройки открыты — номер берётся у жильца в миг нажатия.
    @State private var tuning: Plant.ID?

    /// Открыто ли меню — по предпросмотру: другого признака у контекстного
    /// меню нет.
    @State private var previewing = false

    @State private var tenant = Tenant()

    private var plant: Plant? { garden.plant(id: tenant.id) }

    func body(content: Content) -> some View {
        menu(content
            // Заселяем ячейку первым делом: замыкания меню читают отсюда.
            .onChange(of: id, initial: true) { _, now in tenant.id = now }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { keep($0) }
            .environment(\.sproutHalos, halos && !previewing))
            .alert("Переименовать", isPresented: $renaming) {
                TextField("Кличка", text: $draft)
                Button("Отмена", role: .cancel) {}
                Button("Сохранить") {
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
            .sheet(isPresented: Binding(get: { tuning != nil },
                                        set: { if !$0 { tuning = nil } })) {
                if let tuning {
                    PlantSettingsView(plantID: tuning).environment(garden)
                }
            }
    }

    /// Ветвлением, а не пустым списком: пустое меню всё равно может подняться
    /// предпросмотром и спорить с перетаскиванием.
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
                Button { tuning = tenant.id } label: {
                    Label("Настройки", systemImage: "slider.horizontal.3")
                }
                // Комнаты — по номеру узла: пункты строятся при каждой сборке
                // тела. Запечатываются только нажатия, и они идут через
                // жильца.
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

    /// Пустой замер отводим: пока меню открыто, система отвечает то нулём, то
    /// геометрией поднятой копии, и волна шла бы из угла экрана.
    private func keep(_ rect: CGRect) {
        guard !previewing, rect.width > 0, rect.height > 0 else { return }
        Cards.shared.put(rect, for: tenant.id)
    }

    /// Полив с анимацией, иначе тревожная тень гасла бы щелчком.
    private func water() {
        // Номер — у жильца: в замыкании меню может быть номер прежнего
        // растения ячейки. И растения может уже не быть.
        let who = tenant.id
        guard Bin.shared.water(who, in: garden) else { return }
        // Замера нет — волна из середины экрана: из угла она читается
        // поломкой.
        let spot = Cards.shared.rect(who)
        Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
        Feel.water()
    }

    private func toss() {
        let who = tenant.id
        Bin.shared.toss(who, from: Cards.shared.rect(who), in: garden)
    }

    private func relocate(to room: String) {
        let who = tenant.id
        withAnimation(Motion.appear) { garden.relocate(who, to: room) }
    }

    /// Свой предпросмотр: системный снимок унёс бы ореол. Он же сообщает, что
    /// меню закрылось, — тогда ореол возвращается.
    @ViewBuilder
    private var preview: some View {
        if let plant {
            PlantCard(plant: plant)
                // Ширина числом: предпросмотру размера не предлагают, и
                // карточка свернулась бы.
                .frame(width: Metrics.previewCard)
                .environment(\.sproutHalos, false)
                .onAppear { previewing = true }
                .onDisappear {
                    withAnimation(Motion.halo) { previewing = false }
                }
        }
    }
}

/// Появление карточки: подъём с приближением одной пружиной, соседние — со
/// сдвигом. Один раз на комнату: уехавшие за край карточки ленивая сетка
/// создаёт заново, и без журнала они всплывали бы снова.
struct CardAppear: ViewModifier {
    let index: Int

    /// Появление привязано к номеру комнаты, а не к `onAppear`: вернувшись в
    /// комнату, SwiftUI переиспользует карточку с состоянием.
    let room: Int

    /// Журнал показанных ведёт сетка — она живёт дольше карточки. Флаг должен
    /// быть свежим на каждую пересборку, поэтому журнал в состоянии экрана.
    let animates: Bool

    let onShown: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Начальное значение — из журнала, а не «нет»: с «нет» пересозданная
    /// карточка первым кадром была прозрачной, и появление играло на каждой
    /// прокрутке.
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
            // Через окружение, а не размытием всей карточки: размываем только
            // текст, не стекло и фото.
            .environment(\.sproutSharp, shown)
            .onChange(of: room, initial: true) { _, _ in restart() }
    }

    private func restart() {
        guard animates, !reduceMotion else {
            shown = true
            return
        }
        shown = false
        // Следующим проходом: сброс и подъём в одном проходе SwiftUI
        // схлопнет, а менять журнал посреди отрисовки сетки нельзя.
        Task { @MainActor in
            onShown()
            withAnimation(Motion.appear.delay(Double(index) * Motion.stagger)) {
                shown = true
            }
        }
    }
}

private struct SproutSharpKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Ставит `CardAppear`, читает `Sharpen`.
    var sproutSharp: Bool {
        get { self[SproutSharpKey.self] }
        set { self[SproutSharpKey.self] = newValue }
    }
}

/// Текст карточки наводится на резкость, пока карточка всплывает.
struct Sharpen: ViewModifier {
    @Environment(\.sproutSharp) private var sharp
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.blur(radius: sharp || reduceMotion ? 0 : Metrics.textBlur)
    }
}
