import SwiftUI

@main
struct LittleKitchenApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(coordinator)
                .tint(AppTheme.sage)
        }
    }
}
