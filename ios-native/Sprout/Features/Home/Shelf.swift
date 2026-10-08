import SwiftUI
import UniformTypeIdentifiers

/// Полка растений: плиткой в две колонки или списком. Без общего стеклянного
/// контейнера: он склеивает содержимое в один слой, и карточке нечем
/// разворачиваться в экран растения.
struct Shelf<Content: View>: View {
    let look: Settings.Look
    let content: Content

    /// Крупный шрифт — одна колонка: в половине экрана кличка и срок не
    /// помещаются.
    @Environment(\.dynamicTypeSize) private var type

    init(_ look: Settings.Look, @ViewBuilder content: () -> Content) {
        self.look = look
        self.content = content()
    }

    var body: some View {
        switch look {
        case .grid:
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: Metrics.gutterH),
                    count: type.isAccessibilitySize ? 1 : 2),
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

/// Строка списка — та же плашка, что карточка, положенная боком. На главной
/// — с каплей «Полить» в конце; в правке на её месте ручка.
struct PlantRow: View {
    let plant: Plant

    var editing = false

    /// Капля «Полить»; у предпросмотров меню и перетаскивания её нет.
    var drop = false

    /// Крупный шрифт: строка растёт в высоту, а не режет текст — фото, текст
    /// и процент встают друг под другом.
    @Environment(\.dynamicTypeSize) private var type

    private var stacked: Bool { type.isAccessibilitySize }

    var body: some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            PlantPhoto(plant: plant)
                .frame(width: Metrics.rowPhoto, height: Metrics.rowPhoto)
                // Снизу, а не в углу: у маленькой картинки угла не хватает.
                .overlay(alignment: .bottom) {
                    ModelBadge(plant: plant)
                        .padding(.bottom, 2)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(Typography.cardTitle)
                    .lineLimit(stacked ? nil : 2)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())
                // Статус — значком и словом: цвет один не различить.
                StatusLabel(status: plant.status)
                    .font(Typography.cardCaption)
                    .lineLimit(stacked ? nil : 1)
                    .minimumScaleFactor(0.8)
                // Сухому «полить сегодня» уже сказал статус.
                if plant.status != .urgent {
                    Text(plant.wateringLabel)
                        .font(Typography.cardCaption)
                        .lineLimit(stacked ? nil : 2)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                        .animation(Motion.number, value: plant.daysUntilWatering)
                }
                RecentPour(plant: plant)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Sharpen())

            VStack(alignment: stacked ? .leading : .trailing, spacing: 2) {
                Text(plant.moistureLabel)
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .animation(Motion.number, value: plant.moistureLabel)
                SourceBadge(estimated: plant.estimated)
            }
            .modifier(Sharpen())

            if drop, !editing {
                WaterDrop(plant: plant)
                    .transition(.scale.combined(with: .opacity))
            }

            if editing {
                // Ручка — знак, а не хватка: тащить можно за всю строку.
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: Metrics.gripGlyph, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .transition(.opacity.combined(with: .scale))
                    .accessibilityHidden(true)
            }
        }
        .padding([.leading, .vertical], Metrics.rowPadding)
        .padding(.trailing, Metrics.rowTrail)
        .sproutPlate(in: shape)
        .modifier(PlantGlow(plant: plant, shape: shape))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }
}

/// Перетаскивание — системное, через `onDrag`/`onDrop`: свой жест отнял бы
/// палец у прокрутки. Как на экране «Домой»: долгое нажатие поднимает меню,
/// а правка начинается, только когда карточку повели или продержали
/// дольше меню. Соседи расступаются прямо под пальцем, когда карточку
/// задержали над чужим местом, — см. `Hover`.
struct Arrange: ViewModifier {
    let id: Plant.ID
    let look: Settings.Look

    /// Можно ли тащить вообще; на поиске нельзя.
    let on: Bool

    /// Кого подняли. Места на полке читают его в миг вызова.
    let held: Binding<Plant.ID?>

    /// Кого ведут — он бледнеет на своём месте.
    let dragged: Plant.ID?

    let move: (Plant.ID, Plant.ID) -> Void

    let drop: () -> Void

    /// Карточку подняли долгим нажатием — открылось меню. Правки ещё нет.
    var lift: (Plant.ID) -> Void = { _ in }

    /// Карточку повели — начинается правка.
    var fly: () -> Void = {}

    @Environment(Garden.self) private var garden

    /// Номер растения — у жильца ячейки: замыкание перетаскивания живёт в
    /// UIKit и запечатано при установке. См. `Tenant`.
    @State private var tenant = Tenant()

    func body(content: Content) -> some View {
        drag(content
            .onChange(of: id, initial: true) { _, now in tenant.id = now })
            .opacity(on && dragged == id ? Metrics.ghost : 1)
    }

    @ViewBuilder
    private func drag(_ base: some View) -> some View {
        if on {
            base
                // Зовётся, когда карточку поднимают, — вместе с меню, а не
                // когда её повели. Что повели, скажут места на полке.
                .onDrag {
                    let who = tenant.id
                    lift(who)
                    return NSItemProvider(object: who as NSString)
                } preview: {
                    lifted
                }
                .onDrop(of: [.text], delegate: Slot(
                    tenant: tenant, held: held, fly: fly, move: move,
                    drop: drop))
        } else {
            base
        }
    }

    /// Свой предпросмотр, а не снимок с сетки: снимок мог унести бледность.
    /// Ширина — с экрана: предпросмотру размера не предлагают.
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

/// Место на полке. Всё живое читает в момент вызова, а не при постройке.
/// Соседи расступаются не при заходе, а когда карточку над местом
/// задержали, см. `Hover`.
private struct Slot: DropDelegate {
    let tenant: Tenant
    let held: Binding<Plant.ID?>
    let fly: () -> Void
    let move: (Plant.ID, Plant.ID) -> Void
    let drop: () -> Void

    /// Принимаем только своё: текст из другого приложения — мимо.
    func validateDrop(info: DropInfo) -> Bool {
        held.wrappedValue != nil
    }

    /// Первым о заходе узнаёт своё же место — карточку только что повели.
    func dropEntered(info: DropInfo) {
        fly()
        let spot = tenant.id
        Hover.shared.aim(at: spot) {
            guard let who = held.wrappedValue, who != spot else { return }
            move(who, spot)
        }
    }

    /// Ушли с места раньше срока — соседи стоят.
    func dropExited(info: DropInfo) {
        Hover.shared.leave(tenant.id)
    }

    /// Перенос, а не копия: иначе система рисует зелёный плюс.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    /// Отпустили, не дождавшись, — карточка всё равно ложится сюда.
    func performDrop(info: DropInfo) -> Bool {
        guard let who = held.wrappedValue else { return false }
        Hover.shared.reset()
        if who != tenant.id { move(who, tenant.id) }
        drop()
        return true
    }
}

/// Над каким местом держат тащимую карточку — одно на всю полку. Место
/// переставляется, только если карточку над ним задержали
/// (`Motion.arrangeDwell`): так расступаются значки «Домой». С перестановкой
/// на первом же заходе полка тасовалась под пальцем на каждом пролёте.
final class Hover {
    static let shared = Hover()

    private var spot: Plant.ID?
    private var wait: Task<Void, Never>?

    private init() {}

    /// Навели на место — переставим, если задержат.
    func aim(at spot: Plant.ID, then act: @escaping () -> Void) {
        wait?.cancel()
        self.spot = spot
        wait = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Motion.arrangeDwell)
            guard !Task.isCancelled, self?.spot == spot else { return }
            act()
        }
    }

    func leave(_ spot: Plant.ID) {
        guard self.spot == spot else { return }
        reset()
    }

    func reset() {
        wait?.cancel()
        wait = nil
        spot = nil
    }
}

/// Весь экран — место для броска: иначе отпущенная мимо карточки так и
/// осталась бы бледной. Над карточками отвечают они сами.
struct Rest: DropDelegate {
    let held: Binding<Plant.ID?>
    let fly: () -> Void
    let drop: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        held.wrappedValue != nil
    }

    func dropEntered(info: DropInfo) {
        fly()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard held.wrappedValue != nil else { return false }
        Hover.shared.reset()
        drop()
        return true
    }
}
