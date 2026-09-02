import SwiftUI

@main
struct LittleKitchenApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var kitchenStore = LocalKitchenStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(coordinator)
                .environmentObject(kitchenStore)
                .tint(AppTheme.sage)
        }
    }
}
