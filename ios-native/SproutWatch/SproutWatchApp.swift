import SwiftUI

/// Sprout на часах: кого полить — от самого сухого, и полив с запястья.
/// Сада своего у часов нет: его присылает телефон (`Wristband`).
@main
struct SproutWatchApp: App {
    var body: some Scene {
        WindowGroup {
            GardenList()
        }
    }
}
