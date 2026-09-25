import SwiftUI

/// Подменю «Переехать» — одно на меню карточки и экрана растения.
struct MoveMenu: View {
    let current: String?
    let rooms: [String]

    let move: (String) -> Void

    let ask: () -> Void

    var body: some View {
        Menu {
            ForEach(rooms.filter { $0 != current }, id: \.self) { name in
                Button(name) { move(name) }
            }
            Divider()
            Button { ask() } label: {
                Label("Новая комната…", systemImage: "plus")
            }
        } label: {
            Label("Переехать", systemImage: "door.left.hand.open")
        }
    }
}
