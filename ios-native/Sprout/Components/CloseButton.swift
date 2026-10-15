import SwiftUI

/// Крестик полноэкранных экранов — AR, скана и просмотра: круглая кнопка-значок
/// по стандарту `CornerCircle`.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .cornerGlyph()
        }
        .cornerButton()
        .accessibilityLabel("Закрыть")
    }
}

/// Крестик листа — в панели навигации: стекло кладёт сама панель, своего у
/// кнопки нет. Лист и так смахивается вниз, крестик — для тех, кто не знает.
struct SheetClose: View {
    let action: () -> Void

    var body: some View {
        Button(role: .close, action: action) {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("Закрыть")
    }
}
