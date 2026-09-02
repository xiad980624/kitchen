import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

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
            .tabItem { Label("菜单", systemImage: "fork.knife") }
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
    }
}
