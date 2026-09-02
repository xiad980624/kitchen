import Combine
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .menu
    @Published var isPresentingRecipeEditor = false
    @Published var toastMessage: String?

    func showToast(_ message: String) {
        toastMessage = message
    }
}

enum AppTab: Hashable {
    case pantry
    case menu
    case calendar
    case profile
}
