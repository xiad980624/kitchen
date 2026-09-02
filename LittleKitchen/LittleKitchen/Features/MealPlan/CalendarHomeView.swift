import SwiftUI

struct CalendarHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let days = Array(1...30)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    calendarCard
                    dayMenu
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .background(AppTheme.cream.ignoresSafeArea())
            .navigationTitle("九月菜单")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        guard let recipe = kitchenStore.recipes.first(where: { candidate in
                            !kitchenStore.recipes(for: .now).contains(candidate)
                        }) else {
                            coordinator.showToast("今天的菜谱已全部安排")
                            return
                        }
                        kitchenStore.schedule(recipe)
                        coordinator.showToast("已将\(recipe.title)安排到今天")
                    } label: {
                        Label("安排", systemImage: "plus")
                    }
                }
            }
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("2026 年 9 月")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
                    .padding(.leading, 8)
            }
            .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                }
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 3) {
                        Text("\(day)")
                            .font(.caption.weight(day == 2 ? .bold : .regular))
                            .frame(width: 28, height: 28)
                            .background(day == 2 ? AppTheme.sage : .clear)
                            .foregroundStyle(day == 2 ? .white : AppTheme.ink)
                            .clipShape(Circle())
                        if [2, 5, 12, 18].contains(day) {
                            Text(day == 2 ? "🍗" : "•")
                                .font(.caption2)
                        } else {
                            Color.clear.frame(height: 12)
                        }
                    }
                    .accessibilityLabel("9 月 \(day) 日")
                }
            }
        }
        .padding(16)
        .appCard()
    }

    private var dayMenu: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今天 · 9 月 2 日")
                        .font(.title3.weight(.bold))
                    Text("已确认菜单")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.sage)
                }
                Spacer()
                Button("完成") {
                    coordinator.showToast("今晚菜单已标为完成")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            if kitchenStore.recipes(for: .now).isEmpty {
                Text("还没有安排菜谱")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            ForEach(kitchenStore.recipes(for: .now)) { recipe in
                HStack {
                    Text(recipe.emoji)
                        .font(.title2)
                    Text(recipe.title)
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Button {
                        kitchenStore.removeFromSchedule(recipe)
                        coordinator.showToast("已从今天菜单移除")
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(AppTheme.tomato)
                    }
                    .accessibilityLabel("移除\(recipe.title)")
                }
                .padding(.vertical, 7)
            }
        }
        .padding(17)
        .background(AppTheme.carrotSoft)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
