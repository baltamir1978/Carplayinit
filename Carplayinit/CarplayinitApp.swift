import SwiftUI

@main
struct CarplayinitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    // Antes del seed: si hay garaje que rescatar, no se planta nada.
                    LegacyMigration.runIfNeeded()
                    GarageSeed.installIfNeeded()
                    Garage.shared.reload()
                    // Renders the built-in chimes once, then it is a no-op.
                    await SoundLibrary.shared.prepareIfNeeded()
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Start listening for the car right away: the watcher has to be armed
        // before the phone reaches the car, not when the user opens the app.
        MainActor.assumeIsolated { CarConnectionWatcher.shared.start() }
        return true
    }
}
