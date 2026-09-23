import SwiftUI

/// Растение на полке — карточкой в сетке или строкой в списке, со всем,
/// что к нему прилагается.
///
/// Отдельный тип, а не цепочка модификаторов прямо в `ForEach`, и это
/// починка, а не наведение порядка.
///
/// Цепочка висела на безымянном узле внутри ленивой сетки. Сетка создаёт и
/// выбрасывает карточки на ходу, а контекстное меню живёт не в SwiftUI, а
/// в UIKit: система ставит на вью распознаватель долгого нажатия и держит
/// при нём замыкание с номером растения. Пока сетка не пересобралась,
/// распознаватель оставался от прежней карточки — и «полить» поливало не
/// то растение, на которое нажали. Стоило прокрутить экран, и всё
/// налаживалось: прокрутка пересобирает карточки.
///
/// Свой тип с явным `id` даёт каждой карточке опознаваемую личность: сетка
/// больше не может подсунуть чужой узел, потому что узлы различимы.
struct PlantTile: View {
    let plant: Plant

    /// Карточкой в сетке или строкой в списке.
    var look: Settings.Look = .grid

    /// Что сейчас разворачивается в экран — у этой карточки гасится ореол.
    let opening: Plant.ID?

    /// Пространство перехода: отсюда карточка разворачивается в экран.
    let zoom: Namespace.ID

    /// Открыть растение.
    let open: (Plant.ID) -> Void

    /// Появление в сетке. На поиске его нет: там карточки не всплывают.
    var index = 0
    var room = 0
    var appears = false
    var onShown: () -> Void = {}

    /// Правка порядка. На поиске её нет: там растения лежат по находкам,
    /// и переставлять там нечего.
    var editing = false
    var dragged: Binding<Plant.ID?> = .constant(nil)
    var move: (Plant.ID, Plant.ID) -> Void = { _, _ in }
    var drop: () -> Void = {}

    var body: some View {
        // В правке нажатие не открывает растение: оно там — начало
        // перетаскивания, и уехать с экрана посреди него было бы
        // обидно.
        Button { if !editing { open(plant.id) } } label: {
            label
        }
        .buttonStyle(.plain)
        // Долгое нажатие — системное меню растения, а в правке —
        // перетаскивание.
        .modifier(PlantMenu(id: plant.id, enabled: !editing))
        .modifier(Arrange(id: plant.id, look: look, on: editing,
                          dragged: dragged, move: move, drop: drop))
        // Ореолы гасит только у той карточки, что открывается.
        .environment(\.sproutHalos, opening != plant.id)
        // Появление ведёт сама карточка — от номера комнаты, а не от
        // появления вью: вернувшись в уже открытую комнату, SwiftUI
        // переиспользует карточку вместе с состоянием. Играет один раз:
        // кто показался, тот при обратной прокрутке стоит на месте.
        .modifier(CardAppear(index: index, room: room, animates: appears,
                             onShown: onShown))
        // На гребне волны полива карточка подпрыгивает вместе со всем
        // остальным, что лежит поверх узора.
        .sproutRide()
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
        // Отсюда карточка разворачивается в экран растения. Замер
        // снимается с готовой геометрии, поэтому источник навешен
        // последним.
        .matchedTransitionSource(id: plant.id, in: zoom)
    }

    /// Сама карточка или строка. Качается только карточка: у строки в
    /// правке есть ручка, как в списках iOS, а качание — язык сетки
    /// значков.
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
