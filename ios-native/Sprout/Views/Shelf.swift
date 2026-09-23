import SwiftUI
import UniformTypeIdentifiers

/// Полка с растениями: плиткой в две колонки или списком в одну.
///
/// Одна на главную и поиск. Растения в обоих местах одни и те же, и
/// лежать они должны одинаково — вид выбирают один раз, а не на каждом
/// экране.
///
/// Без общего стеклянного контейнера — по той же причине, что и прежде
/// у сетки: он склеивает содержимое в один слой, и карточке нечем
/// разворачиваться в экран растения.
struct Shelf<Content: View>: View {
    let look: Settings.Look
    let content: Content

    init(_ look: Settings.Look, @ViewBuilder content: () -> Content) {
        self.look = look
        self.content = content()
    }

    var body: some View {
        switch look {
        case .grid:
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Metrics.gutterH),
                    GridItem(.flexible(), spacing: Metrics.gutterH),
                ],
                spacing: Metrics.gutterV
            ) {
                content
            }
        case .list:
            LazyVStack(spacing: Metrics.listGap) {
                content
            }
        }
    }
}

/// Строка растения в списке: всё, что есть на карточке, в одну полосу.
///
/// Картинка слева, кличка и срок полива посередине, влажность справа —
/// крупно, как и на карточке: это то, ради чего на растение смотрят.
/// Материал и тревожная тень те же, что у карточки, — это та же плашка,
/// только положенная боком.
struct PlantRow: View {
    let plant: Plant

    /// Правят ли сейчас порядок: тогда справа ручка.
    var editing = false

    var body: some View {
        HStack(spacing: 12) {
            PlantPhoto(plant: plant)
                .frame(width: Metrics.rowPhoto, height: Metrics.rowPhoto)

            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(Typography.cardTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())
                Text(plant.wateringLabel)
                    .font(Typography.cardCaption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .animation(Motion.number, value: plant.daysUntilWatering)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Sharpen())

            // Тот же числовой переход, что на карточке: пролистываются
            // только цифры, знак процента стоит на месте.
            Text(plant.moistureLabel)
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .animation(Motion.number, value: plant.moisture)
                .modifier(Sharpen())

            if editing {
                // Ручка — знак, а не сама хватка: тащить можно за всю
                // строку. Без неё строка в правке ничем не отличалась бы
                // от строки в покое, а в списках iOS «можно двигать»
                // говорит именно она.
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: Metrics.gripGlyph, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .transition(.opacity.combined(with: .scale))
                    .accessibilityHidden(true)
            }
        }
        .padding([.leading, .vertical], Metrics.rowPadding)
        .padding(.trailing, Metrics.rowTrail)
        .sproutPlate(in: shape, interactive: true)
        .modifier(PlantGlow(plant: plant, shape: shape))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }
}

/// Перетаскивание карточки, пока правят порядок.
///
/// Системное, через `onDrag` и `onDrop`, а не своим жестом. Свой жест в
/// прокрутке отнимает у неё палец: карточки занимают почти весь экран, и
/// листать его в правке стало бы нечем. Системное перетаскивание
/// начинается с удержания, а быстрый мазок оставляет прокрутке — так же
/// ведут себя списки и сетки самой iOS.
///
/// Соседи расступаются прямо под пальцем, а не когда карточку отпустят:
/// каждый раз, как она заходит на чужое место, сад переставляет
/// растения, и сетка перекладывается пружиной. Отпустить — значит просто
/// оставить её там, где она уже стоит.
struct Arrange: ViewModifier {
    let id: Plant.ID
    let look: Settings.Look

    /// Правят ли сейчас порядок. Вне правки карточку не тащат: долгое
    /// нажатие занято меню растения.
    let on: Bool

    /// Кого тащат. Живёт у экрана: он один на всю полку.
    let dragged: Binding<Plant.ID?>

    /// Переставить: кого и на чьё место.
    let move: (Plant.ID, Plant.ID) -> Void

    /// Карточку отпустили.
    let drop: () -> Void

    @Environment(Garden.self) private var garden

    /// Кто в этой ячейке сейчас — по той же причине, что и у меню.
    ///
    /// Перетаскивание, как и контекстное меню, живёт в UIKit, и его
    /// замыкание запечатано тогда, когда оно ставилось. Ленивая сетка
    /// переиспользует ячейку под другое растение, и без жильца потащилось
    /// бы то, что стояло здесь до прокрутки. См. `Tenant`.
    @State private var tenant = Tenant()

    func body(content: Content) -> some View {
        drag(content
            .onChange(of: id, initial: true) { _, now in tenant.id = now })
            .opacity(on && dragged.wrappedValue == id ? Metrics.ghost : 1)
    }

    @ViewBuilder
    private func drag(_ base: some View) -> some View {
        if on {
            base
                .onDrag {
                    let who = tenant.id
                    dragged.wrappedValue = who
                    return NSItemProvider(object: who as NSString)
                } preview: {
                    lifted
                }
                .onDrop(of: [.text], delegate: Slot(
                    tenant: tenant, dragged: dragged, move: move, drop: drop))
        } else {
            base
        }
    }

    /// Что едет под пальцем — сама карточка, без тревожной тени и без
    /// бледности.
    ///
    /// Своё, а не снимок с сетки: снимок снимается в тот же миг, когда
    /// карточку на месте делают бледной, и мог унести бледность с собой,
    /// а заодно и покачивание — поднятая карточка ехала бы кривой.
    ///
    /// Ширина с экрана — ровно та, что у карточки в сетке: предпросмотру
    /// размера не предлагают, и без числа карточка свернулась бы.
    @ViewBuilder
    private var lifted: some View {
        if let plant = garden.plant(id: id) {
            let width = Cards.shared.rect(id).width
            Group {
                switch look {
                case .grid: PlantCard(plant: plant)
                case .list: PlantRow(plant: plant, editing: true)
                }
            }
            .frame(width: width > 0 ? width : Metrics.previewCard)
            .environment(\.sproutHalos, false)
        }
    }
}

/// Чужое место на полке, над которым держат карточку.
///
/// Всё живое берёт в момент вызова, а не при постройке: у кого тащат —
/// из привязки к экрану, на чьём месте — у жильца ячейки. Постройка
/// могла быть сколько угодно давно.
private struct Slot: DropDelegate {
    let tenant: Tenant
    let dragged: Binding<Plant.ID?>
    let move: (Plant.ID, Plant.ID) -> Void
    let drop: () -> Void

    /// Чужого не принимаем: лечь сюда может только растение с этой же
    /// полки. Текст, притащенный из другого приложения, мимо.
    func validateDrop(info: DropInfo) -> Bool {
        dragged.wrappedValue != nil
    }

    func dropEntered(info: DropInfo) {
        guard let who = dragged.wrappedValue, who != tenant.id else { return }
        move(who, tenant.id)
    }

    /// Перенос, а не копия: без этого система рисует у карточки зелёный
    /// плюс, будто её размножают.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard dragged.wrappedValue != nil else { return false }
        drop()
        return true
    }
}

/// Весь экран — чтобы карточку можно было отпустить и между карточками, и
/// над строкой комнаты.
///
/// Без этого отпущенная мимо карточки считалась бы брошенной: перестановка
/// уже случилась, а бледность так бы и осталась — снять её было бы некому.
/// Над самими карточками отвечают они: вложенное место для броска главнее
/// того, в которое оно вложено.
struct Rest: DropDelegate {
    let dragged: Binding<Plant.ID?>
    let drop: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        dragged.wrappedValue != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard dragged.wrappedValue != nil else { return false }
        drop()
        return true
    }
}

/// Покачивание карточки, пока правят порядок.
///
/// Соседние качаются в разные стороны, и у каждой свой период — сетка не
/// ходит строем, а живёт, как значки на экране «Домой». При включённом
/// «Уменьшении движения» не качается вовсе: правка видна и так — по
/// кнопке «Готово».
struct Jiggle: ViewModifier {
    let on: Bool

    /// Номер на полке: от чётности — в какую сторону начинать.
    let index: Int

    /// Доля разброса периода, 0…1. Своя у каждого растения.
    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var period: Double {
        Motion.jigglePeriod * (1 + Motion.jiggleSpread * (phase - 0.5))
    }

    private var angle: Double {
        index.isMultiple(of: 2) ? Motion.jiggleAngle : -Motion.jiggleAngle
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0,
                                 repeating: on && !reduceMotion) { view, turn in
            view.rotationEffect(.degrees(turn))
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(angle, duration: period / 4)
                CubicKeyframe(-angle, duration: period / 2)
                CubicKeyframe(0, duration: period / 4)
            }
        }
    }
}
