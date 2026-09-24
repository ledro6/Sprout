import SwiftUI
import UniformTypeIdentifiers

/// Полка растений: плиткой в две колонки или списком. Без общего стеклянного
/// контейнера: он склеивает содержимое в один слой, и карточке нечем
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

/// Строка списка — та же плашка, что карточка, положенная боком.
struct PlantRow: View {
    let plant: Plant

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

            Text(plant.moistureLabel)
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .animation(Motion.number, value: plant.moisture)
                .modifier(Sharpen())

            if editing {
                // Ручка — знак, а не хватка: тащить можно за всю строку.
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

/// Перетаскивание — системное, через `onDrag`/`onDrop`: свой жест отнял бы
/// палец у прокрутки. Как на экране «Домой»: карточку, поднятую меню,
/// можно сразу повести — тогда полка начинает качаться. Соседи расступаются
/// прямо под пальцем — сад переставляет растения на каждом заходе на чужое
/// место.
struct Arrange: ViewModifier {
    let id: Plant.ID
    let look: Settings.Look

    /// Можно ли тащить вообще; на поиске нельзя.
    let on: Bool

    let dragged: Binding<Plant.ID?>

    let move: (Plant.ID, Plant.ID) -> Void

    let drop: () -> Void

    /// Карточку подняли — полка переходит в правку.
    var begin: () -> Void = {}

    @Environment(Garden.self) private var garden

    /// Номер растения — у жильца ячейки: замыкание перетаскивания живёт в
    /// UIKit и запечатано при установке. См. `Tenant`.
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
                    begin()
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

    /// Свой предпросмотр, а не снимок с сетки: снимок мог унести бледность и
    /// покачивание. Ширина — с экрана: предпросмотру размера не предлагают.
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

/// Чужое место на полке. Всё живое читает в момент вызова, а не при
/// постройке.
private struct Slot: DropDelegate {
    let tenant: Tenant
    let dragged: Binding<Plant.ID?>
    let move: (Plant.ID, Plant.ID) -> Void
    let drop: () -> Void

    /// Принимаем только своё: текст из другого приложения — мимо.
    func validateDrop(info: DropInfo) -> Bool {
        dragged.wrappedValue != nil
    }

    func dropEntered(info: DropInfo) {
        guard let who = dragged.wrappedValue, who != tenant.id else { return }
        move(who, tenant.id)
    }

    /// Перенос, а не копия: иначе система рисует зелёный плюс.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard dragged.wrappedValue != nil else { return false }
        drop()
        return true
    }
}

/// Весь экран — место для броска: иначе отпущенная мимо карточки так и
/// осталась бы бледной. Над карточками отвечают они сами.
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

/// Покачивание полки, как у значков «Домой»: поворот и лёгкий подскок с
/// разными тактами, у каждой карточки свой такт и своя фаза — строем они
/// читались бы механизмом. Время — с часов экрана, а не повтором анимации:
/// повтор начинался с нуля на каждой пересборке и дёргал карточку. Размах
/// набирается и стихает, а не включается щелчком. При «Уменьшении движения»
/// не качается.
struct Jiggle: ViewModifier {
    let on: Bool

    /// Своя у каждого растения, 0…1.
    let phase: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var swing = 0.0

    private var active: Bool { on && !reduceMotion }

    func body(content: Content) -> some View {
        // Стихая, часы стоят: карточка плавно выпрямляется из того наклона,
        // в котором её застали.
        TimelineView(.animation(paused: !active)) { context in
            content.modifier(Wobble(
                swing: swing,
                time: context.date.timeIntervalSinceReferenceDate,
                phase: phase))
        }
        .onChange(of: active, initial: true) { _, now in
            withAnimation(now ? Motion.jiggleIn : Motion.jiggleOut) {
                swing = now ? 1 : 0
            }
        }
    }
}

/// Наклон и подскок в миг `time`. Анимируется только размах: время
/// приходит с часов.
private struct Wobble: GeometryEffect {
    var swing: Double
    let time: Double
    let phase: Double

    var animatableData: Double {
        get { swing }
        set { swing = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard swing > 0 else { return ProjectionTransform() }
        let pace = 1 + Motion.jiggleSpread * (phase - 0.5)
        let rock = sin(2 * .pi * (time / (Motion.jigglePeriod * pace) + phase))
        // Подскок со своей фазой: вместе с поворотом он даёт неровный,
        // живой ход.
        let hop = sin(2 * .pi * (time / (Motion.jiggleLiftPeriod * pace)
                                 + phase * 1.7))
        let angle = CGFloat(Motion.jiggleAngle * .pi / 180 * swing * rock)
        let lift = Motion.jiggleLift * CGFloat(swing * hop)
        let middle = CGAffineTransform(translationX: -size.width / 2,
                                       y: -size.height / 2)
        let back = CGAffineTransform(translationX: size.width / 2,
                                     y: size.height / 2 + lift)
        return ProjectionTransform(middle
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(back))
    }
}
