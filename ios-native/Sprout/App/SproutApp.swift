import SwiftUI
import UIKit

@main
struct SproutApp: App {
    /// Кнопка «Полил» в уведомлении должна быть известна системе до того,
    /// как придёт первое.
    init() {
        Settings.shared.launched()
        Notifier.register()
        // Записали сад — виджету пора перерисоваться, живым действиям —
        // отметить политых, часам — получить новый сад.
        Garden.saved = {
            Task { @MainActor in
                Widgets.nudge()
                WatchLink.shared.send()
                await Live.shared.sync()
            }
        }
        // Кнопки в живых действиях система выполняет здесь, в приложении.
        LiveHook.act = { await Live.shared.handle($0) }
        WatchLink.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
