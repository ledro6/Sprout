import SwiftUI
import UIKit

@main
struct SproutApp: App {
    /// Приглашения в общий сад приходят сцене — см. `FamilyDoor`.
    @UIApplicationDelegateAdaptor(FamilyDoor.self) private var door

    /// Кнопка «Полил» в уведомлении должна быть известна системе до того,
    /// как придёт первое.
    init() {
        Settings.shared.launched()
        Notifier.register()
        // Записали сад — виджету пора перерисоваться, живым действиям —
        // отметить политых, часам — получить новый сад, общему саду —
        // отправить правку.
        Garden.saved = {
            Task { @MainActor in
                Widgets.nudge()
                WatchLink.shared.send()
                Kinship.shared.nudge()
                await Live.shared.sync()
            }
        }
        // Общий сад — до первого окна: система могла разбудить приложение
        // пушем о чужом поливе. Без iCloud в сборке ничего не делает.
        Kinship.shared.launch()
        // Кнопки в живых действиях система выполняет здесь, в приложении.
        LiveHook.act = { await Live.shared.handle($0) }
        WatchLink.shared.start()
        // До первого окна: тема встаёт раньше первого кадра.
        WindowTheme.watch()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Тема из настроек — окнам, а не `preferredColorScheme` в корне SwiftUI:
/// с заданной там схемой корень сам ведёт строку состояния всего окна, и
/// экран не может сделать её своей — ночной планетарий (`sproutNight`) в
/// «Светлой» оставался с тёмными знаками. Окно красит всё, что в нём:
/// экраны, листы, алерты, заставку. «Как в системе» — без подмены.
@MainActor
enum WindowTheme {
    /// Окно, которое показалось или стало ключевым, получает тему сразу:
    /// без очереди уведомление приходит синхронно, до того как первый кадр
    /// окна уйдёт на экран, — на запуске ничего не мигает. Само окно, а не
    /// обход сцен: сцена, которая ещё подключается, может быть не в списке.
    static func watch() {
        let center = NotificationCenter.default
        for name in [UIWindow.didBecomeVisibleNotification,
                     UIWindow.didBecomeKeyNotification] {
            _ = center.addObserver(forName: name, object: nil,
                                   queue: nil) { note in
                MainActor.assumeIsolated {
                    if let window = note.object as? UIWindow {
                        WindowTheme.dress(window)
                    }
                }
            }
        }
    }

    /// Всем окнам всех сцен — при смене в настройках.
    static func apply() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows { dress(window) }
    }

    private static func dress(_ window: UIWindow) {
        let wanted = style
        guard window.overrideUserInterfaceStyle != wanted else { return }
        window.overrideUserInterfaceStyle = wanted
        window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
    }

    private static var style: UIUserInterfaceStyle {
        switch Settings.shared.theme {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}
