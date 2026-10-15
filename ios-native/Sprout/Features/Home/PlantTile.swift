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

    /// Пространство перетекания между плиткой и списком. Растение с одним
    /// id в обоих видах сходится в одну геометрию; на поиске его нет.
    var morph: Namespace.ID?

    let open: (Plant.ID) -> Void

    /// Появление в сетке; на поиске его нет.
    var index = 0
    var room = 0
    var appears = false
    var onShown: () -> Void = {}

    /// Перестановка; на поиске её нет.
    var arranges = false
    /// Идёт правка: нажатие ничего не открывает.
    var editing = false
    var menus = true
    var held: Binding<Plant.ID?> = .constant(nil)
    var dragged: Plant.ID?
    var move: (Plant.ID, Plant.ID) -> Void = { _, _ in }
    var drop: () -> Void = {}
    /// Карточку подняли — открылось меню, см. `Arrange`.
    var lift: (Plant.ID) -> Void = { _ in }
    /// Карточку повели — начинается правка.
    var fly: () -> Void = {}
    /// Капля «Полить» — на главной; в правке её нет, как нет кнопок у
    /// значков «Домой», пока их переставляют.
    var waters = false

    var body: some View {
        // В правке нажатие ничего не открывает, как значок на «Домой».
        Button { if !editing { open(plant.id) } } label: {
            label
        }
        .buttonStyle(PlantPress())
        .modifier(PlantMenu(id: plant.id, look: look, enabled: menus))
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
        .modifier(Morph(id: plant.id, space: morph))
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
        // Источник перехода — последним: замер снимается с готовой геометрии.
        .matchedTransitionSource(id: plant.id, in: zoom)
    }

    /// Перетекание включаем только тогда, когда есть пространство: без него
    /// модификатор не применяется вовсе.
    private struct Morph: ViewModifier {
        let id: Plant.ID
        let space: Namespace.ID?

        @ViewBuilder
        func body(content: Content) -> some View {
            if let space {
                content.matchedGeometryEffect(id: id, in: space)
            } else {
                content
            }
        }
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

/// Проседание плашки по нажатию: масштаб `SproutPress` плюс потемнение, чтобы
/// нажатие читалось и на непрозрачной карточке, и на крупной. Срабатывает
/// только по `isPressed`, то есть не на касании, с которого начинается
/// прокрутка.
private struct PlantPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Motion.pressScale : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
