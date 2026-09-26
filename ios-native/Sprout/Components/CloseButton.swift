import SwiftUI

/// Крестик полноэкранных экранов — AR и скана: стеклянный кружок размером
/// с шестерёнку настроек.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(Typography.navTitle)
                .frame(width: Metrics.gearBox, height: Metrics.gearBox)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Закрыть")
    }
}

/// Крестик листа — в панели навигации: стекло кладёт сама панель, своего у
/// кнопки нет. Лист и так смахивается вниз, крестик — для тех, кто не знает.
struct SheetClose: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("Закрыть")
    }
}
