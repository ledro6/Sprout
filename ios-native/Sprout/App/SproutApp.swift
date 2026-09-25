import SwiftUI
import UIKit

@main
struct SproutApp: App {
    /// Кнопка «Полил» в уведомлении должна быть известна системе до того,
    /// как придёт первое.
    init() {
        Settings.shared.launched()
        Notifier.register()
        // Записали сад — виджету пора перерисоваться, а живым действиям —
        // отметить политых.
        Garden.saved = {
            Task { @MainActor in
                Widgets.nudge()
                await Live.shared.sync()
            }
        }
        // Кнопки в живых действиях система выполняет здесь, в приложении.
        LiveHook.act = { await Live.shared.handle($0) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
