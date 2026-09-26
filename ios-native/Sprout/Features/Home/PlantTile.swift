import SwiftUI

/// Растение на полке — карточкой или строкой, со всем, что к нему
/// прилагается.
///
/// Отдельный тип с явным `id`, а не цепочка модификаторов в `ForEach`: на
/// безымянном узле ленивой сетки контекстное меню доставалось чужой карточке.
/// См. также `Tenant`.
struct PlantTile: View {
    let plant: Plant

    var look: Settings.Look = .grid

    let opening: Plant.ID?

    let zoom: Namespace.ID

    let open: (Plant.ID) -> Void

    /// Появление в сетке; на поиске его нет.
    var index = 0
    var room = 0
    var appears = false
    var onShown: () -> Void = {}

    /// Перестановка; на поиске её нет.
    var arranges = false
    /// Полка качается.
    var editing = false
    var menus = true
    var held: Binding<Plant.ID?> = .constant(nil)
    var dragged: Plant.ID?
    var move: (Plant.ID, Plant.ID) -> Void = { _, _ in }
    var drop: () -> Void = {}
    /// Карточку подняли — открылось меню, см. `Arrange`.
    var lift: (Plant.ID) -> Void = { _ in }
    /// Карточку повели — полка начинает качаться.
    var fly: () -> Void = {}
    /// Капля «Полить» — на главной; в правке её нет, как нет кнопок у
    /// качающихся значков.
    var waters = false

    var body: some View {
        // В правке нажатие ничего не открывает, как значок на «Домой».
        Button { if !editing { open(plant.id) } } label: {
            label
        }
        .buttonStyle(.plain)
        .modifier(PlantMenu(id: plant.id, look: look, enabled: menus))
        // Снаружи меню: меню в правке снимается, и качание внутри него
        // начиналось бы заново. Строка не качается — у неё ручка, как в
        // списках iOS. Место тащимой карточки стоит: это метка, куда она
        // ляжет, а качаясь под пальцем, она двоилась с поднятой.
        .modifier(Jiggle(on: editing && look == .grid && dragged != plant.id,
                         phase: plant.pulsePhase))
        .modifier(Arrange(id: plant.id, look: look, on: arranges,
                          held: held, dragged: dragged, move: move,
                          drop: drop, lift: lift, fly: fly))
        .environment(\.sproutHalos, opening != plant.id)
        // Появление ведёт карточка от номера комнаты, а не от появления вью:
        // вернувшись в комнату, SwiftUI переиспользует карточку вместе с
        // состоянием.
        .modifier(CardAppear(index: index, room: room, animates: appears,
                             onShown: onShown))
        .sproutRide()
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
        // Источник перехода — последним: замер снимается с готовой геометрии.
        .matchedTransitionSource(id: plant.id, in: zoom)
    }

    @ViewBuilder
    private var label: some View {
        switch look {
        case .grid:
            PlantCard(plant: plant, drop: waters && !editing)
                .animation(Motion.arrange, value: editing)
        case .list:
            PlantRow(plant: plant, editing: editing, drop: waters)
        }
    }
}
