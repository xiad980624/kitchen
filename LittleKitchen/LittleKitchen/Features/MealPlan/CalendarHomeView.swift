import SwiftUI

struct CalendarHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    private var currentDay: Int {
        Calendar.current.component(.day, from: .now)
    }

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private var days: [Int] {
        let range = Calendar.current.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        return Array(range)
    }

    private var firstWeekdayOffset: Int {
        let weekday = Calendar.current.component(.weekday, from: monthStart)
        return (weekday - Calendar.current.firstWeekday + 7) % 7
    }

    private var todayRecipes: [Recipe] {
        kitchenStore.recipes(for: .now)
    }

    private var isTodayMenuCompleted: Bool {
        kitchenStore.isMenuCompleted()
    }

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
            .navigationTitle("\(Date.now.formatted(.dateTime.month(.wide)))菜单")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        scheduleNextRecipe()
                    } label: {
                        Label("安排", systemImage: "plus")
                    }
                    .accessibilityLabel("安排一道菜到今天菜单")
                }
            }
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(Date.now.formatted(.dateTime.year().month(.wide)))
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
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear
                        .frame(height: 40)
                        .accessibilityHidden(true)
                }
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 3) {
                        Text("\(day)")
                            .font(.caption.weight(day == currentDay ? .bold : .regular))
                            .frame(width: 28, height: 28)
                            .background(day == currentDay ? AppTheme.sage : .clear)
                            .foregroundStyle(day == currentDay ? .white : AppTheme.ink)
                            .clipShape(Circle())
                        if day == currentDay, !todayRecipes.isEmpty {
                            Image(systemName: isTodayMenuCompleted ? "checkmark.circle.fill" : "fork.knife.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(isTodayMenuCompleted ? AppTheme.sage : AppTheme.carrot)
                        } else {
                            Color.clear.frame(height: 12)
                        }
                    }
                    .accessibilityLabel(date(for: day).formatted(.dateTime.month().day().weekday(.wide)))
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
                    Text("今天 · \(Date.now.formatted(.dateTime.month().day()))")
                        .font(.title3.weight(.bold))
                    Text(todayRecipes.isEmpty ? "等待安排" : (isTodayMenuCompleted ? "今日菜单已完成" : "今日菜单"))
                        .font(.subheadline)
                        .foregroundStyle(todayRecipes.isEmpty ? AppTheme.muted : (isTodayMenuCompleted ? AppTheme.sage : AppTheme.carrot))
                }
                Spacer()
                Button(isTodayMenuCompleted ? "撤销完成" : "完成") {
                    if isTodayMenuCompleted {
                        kitchenStore.reopenMenu()
                        coordinator.showToast("已恢复今天菜单")
                    } else {
                        kitchenStore.completeMenu()
                        coordinator.showToast("今晚菜单已标为完成")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(todayRecipes.isEmpty)
            }
            if todayRecipes.isEmpty {
                EmptyStateCard(
                    symbol: "calendar.badge.plus",
                    title: "还没有安排菜谱",
                    message: "从已有菜谱中安排一道菜，系统就会开始核对冰箱库存。",
                    actionTitle: "安排一道菜",
                    action: scheduleNextRecipe
                )
            } else {
                ForEach(todayRecipes) { recipe in
                    HStack {
                        Text(recipe.emoji)
                            .font(.title2)
                        Text(recipe.title)
                            .font(.subheadline.weight(.bold))
                        if isTodayMenuCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.sage)
                                .accessibilityLabel("已完成")
                        }
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
        }
        .padding(17)
        .background(AppTheme.carrotSoft)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func scheduleNextRecipe() {
        guard let recipe = kitchenStore.recipes.first(where: { candidate in
            !todayRecipes.contains(candidate)
        }) else {
            coordinator.showToast("今天的菜谱已全部安排")
            return
        }
        kitchenStore.schedule(recipe)
        coordinator.showToast("已将\(recipe.title)安排到今天")
    }

    private func date(for day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
    }
}
