import SwiftUI

@main
struct LittleKitchenApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var kitchenStore = LocalKitchenStore()
    @StateObject private var accountSession = AccountSession()
    @StateObject private var syncController = KitchenSyncController()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(coordinator)
                .environmentObject(kitchenStore)
                .environmentObject(accountSession)
                .environmentObject(syncController)
                .tint(AppTheme.sage)
        }
    }
}
