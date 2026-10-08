import CloudKit
import UIKit

/// Вход приглашений в общий сад. Приглашение открывают ссылкой из Сообщений
/// или почты — система запускает приложение и отдаёт приглашение сцене:
/// `UIWindowSceneDelegate.windowScene(_:userDidAcceptCloudKitShareWith:)`,
/// а при запуске с нуля — в `connectionOptions`. У SwiftUI такого входа
/// нет, поэтому делегат сцены свой; окна по-прежнему ведёт SwiftUI.
///
/// Тот же делегат сцены принимает и быстрые действия иконки, см.
/// `QuickActions`, поэтому он у сцены всегда.
final class FamilyDoor: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = FamilyScene.self
        return configuration
    }
}

/// Делегат сцены — только ради приглашений; всё остальное делает SwiftUI.
final class FamilyScene: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // Запуск нажатием на быстрое действие: корень ещё не слушает —
        // исполнит `QuickActions.run`, когда появится.
        if let shortcut = connectionOptions.shortcutItem {
            QuickActions.pending = shortcut.type
        }
        guard let metadata = connectionOptions.cloudKitShareMetadata else {
            return
        }
        Task { @MainActor in Kinship.shared.accept(metadata) }
    }

    /// Приложение уже запущено — действие исполняется сразу.
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActions.pending = shortcutItem.type
        completionHandler(true)
        Task { @MainActor in QuickActions.run() }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in Kinship.shared.accept(cloudKitShareMetadata) }
    }
}
