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

    /// Правка порядка; на поиске её нет.
    var editing = false
    var dragged: Binding<Plant.ID?> = .constant(nil)
    var move: (Plant.ID, Plant.ID) -> Void = { _, _ in }
    var drop: () -> Void = {}

    var body: some View {
        // В правке нажатие — начало перетаскивания, а не переход.
        Button { if !editing { open(plant.id) } } label: {
            label
        }
        .buttonStyle(.plain)
        .modifier(PlantMenu(id: plant.id, enabled: !editing))
        .modifier(Arrange(id: plant.id, look: look, on: editing,
                          dragged: dragged, move: move, drop: drop))
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

    /// Качается только карточка: у строки есть ручка, как в списках iOS.
    @ViewBuilder
    private var label: some View {
        switch look {
        case .grid:
            PlantCard(plant: plant)
                .modifier(Jiggle(on: editing, index: index,
                                 phase: plant.pulsePhase))
        case .list:
            PlantRow(plant: plant, editing: editing)
        }
    }
}
