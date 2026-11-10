import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @EnvironmentObject private var accountSession: AccountSession
    @EnvironmentObject private var syncController: KitchenSyncController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            PantryHomeView()
                .tabItem { Label("冰箱", systemImage: "refrigerator") }
                .tag(AppTab.pantry)

            NavigationStack {
                MenuHomeView()
                    .navigationDestination(for: Recipe.self) { recipe in
                        RecipeDetailView(recipe: recipe)
                    }
            }
            .tabItem { Label("菜谱", systemImage: "fork.knife") }
            .tag(AppTab.menu)

            CalendarHomeView()
                .tabItem { Label("日历", systemImage: "calendar") }
                .tag(AppTab.calendar)

            ProfileHomeView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .sheet(isPresented: $coordinator.isPresentingRecipeEditor) {
            NavigationStack {
                RecipeEditorView(recipe: coordinator.editingRecipe)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = coordinator.toastMessage {
                ToastView(message: message)
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                coordinator.toastMessage = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.toastMessage)
        .task {
            await accountSession.refreshHouseholds()
            if accountSession.activeHousehold != nil {
                await syncController.syncNow(store: kitchenStore, session: accountSession)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await syncController.syncNow(store: kitchenStore, session: accountSession) }
        }
        .onChange(of: kitchenStore.persistenceVersion) { _, _ in
            guard accountSession.activeHousehold != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(1))
                await syncController.syncNow(store: kitchenStore, session: accountSession)
            }
        }
    }
}
