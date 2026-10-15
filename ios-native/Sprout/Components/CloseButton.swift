import SwiftUI

/// Крестик полноэкранных экранов — AR и скана: стеклянный кружок
/// одного размера с прочими значками шапок.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .cornerCircle()
        }
        .buttonStyle(.plain)
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
