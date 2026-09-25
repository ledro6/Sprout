import SwiftUI
import UIKit

@main
struct SproutApp: App {
    /// Кнопка «Полил» в уведомлении должна быть известна системе до того,
    /// как придёт первое.
    init() {
        Settings.shared.launched()
        Notifier.register()
        // Записали сад — виджету пора перерисоваться.
        Garden.saved = { Task { @MainActor in Widgets.nudge() } }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
