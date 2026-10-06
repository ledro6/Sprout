import CloudKit
import UIKit

/// Вход приглашений в общий сад. Приглашение открывают ссылкой из Сообщений
/// или почты — система запускает приложение и отдаёт приглашение сцене:
/// `UIWindowSceneDelegate.windowScene(_:userDidAcceptCloudKitShareWith:)`,
/// а при запуске с нуля — в `connectionOptions`. У SwiftUI такого входа
/// нет, поэтому делегат сцены свой; окна по-прежнему ведёт SwiftUI.
///
/// Пока общий сад выключен (`Kinship.enabled`), делегат приложения говорит
/// системе, что настройки сцен у него нет, — всё как без этого файла.
final class FamilyDoor: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil, sessionRole: connectingSceneSession.role)
        if Kinship.enabled { configuration.delegateClass = FamilyScene.self }
        return configuration
    }

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(UIApplicationDelegate.application(
            _:configurationForConnecting:options:)) {
            return Kinship.enabled
        }
        return super.responds(to: aSelector)
    }
}

/// Делегат сцены — только ради приглашений; всё остальное делает SwiftUI.
final class FamilyScene: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else {
            return
        }
        Task { @MainActor in Kinship.shared.accept(metadata) }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in Kinship.shared.accept(cloudKitShareMetadata) }
    }
}
