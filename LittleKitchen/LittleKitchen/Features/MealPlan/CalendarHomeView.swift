import SwiftUI

struct CalendarHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var selectedDate = Date.now

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    private var days: [Int] {
        let range = Calendar.current.range(of: .day, in: .month, for: displayedMonth) ?? 1..<31
        return Array(range)
    }

    private var firstWeekdayOffset: Int {
        let weekday = Calendar.current.component(.weekday, from: displayedMonth)
        return (weekday - Calendar.current.firstWeekday + 7) % 7
    }

    private var selectedRecipes: [Recipe] {
        kitchenStore.recipes(for: selectedDate)
    }

    private var isSelectedMenuCompleted: Bool {
        kitchenStore.isMenuCompleted(for: selectedDate)
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
            .navigationTitle("菜单日历")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        scheduleNextRecipe()
                    } label: {
                        Label("安排", systemImage: "plus")
                    }
                    .accessibilityLabel("安排一道菜到\(selectedDate.formatted(.dateTime.month().day()))")
                }
            }
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                Spacer()
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("上个月")
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("下个月")
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
                        .frame(height: 44)
                        .accessibilityHidden(true)
                }
                ForEach(days, id: \.self) { day in
                    let cellDate = date(for: day)
                    let recipes = kitchenStore.recipes(for: cellDate)
                    let isSelected = Calendar.current.isDate(cellDate, inSameDayAs: selectedDate)
                    let isToday = Calendar.current.isDateInToday(cellDate)
                    let isCompleted = kitchenStore.isMenuCompleted(for: cellDate)

                    Button {
                        selectedDate = cellDate
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(day)")
                                .font(.caption.weight(isToday || isSelected ? .bold : .regular))
                                .frame(width: 29, height: 29)
                                .background(isSelected ? AppTheme.carrot : (isToday ? AppTheme.sage : .clear))
                                .foregroundStyle((isSelected || isToday) ? .white : AppTheme.ink)
                                .clipShape(Circle())
                            if !recipes.isEmpty {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "fork.knife.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(isCompleted ? AppTheme.sage : AppTheme.carrot)
                            } else {
                                Color.clear.frame(height: 12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(cellDate.formatted(.dateTime.month().day().weekday(.wide)))\(recipes.isEmpty ? "，没有安排" : "，已安排\(recipes.count)道菜")")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    Text(selectedDate.formatted(.dateTime.month().day().weekday(.wide)))
                        .font(.title3.weight(.bold))
                    Text(selectedRecipes.isEmpty ? "等待安排" : (isSelectedMenuCompleted ? "菜单已完成" : "待完成菜单"))
                        .font(.subheadline)
                        .foregroundStyle(selectedRecipes.isEmpty ? AppTheme.muted : (isSelectedMenuCompleted ? AppTheme.sage : AppTheme.carrot))
                }
                Spacer()
                Button(isSelectedMenuCompleted ? "撤销完成" : "完成") {
                    if isSelectedMenuCompleted {
                        kitchenStore.reopenMenu(for: selectedDate)
                        coordinator.showToast("已恢复当天菜单")
                    } else {
                        kitchenStore.completeMenu(for: selectedDate)
                        coordinator.showToast("菜单已标为完成")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedRecipes.isEmpty)
            }
            if selectedRecipes.isEmpty {
                EmptyStateCard(
                    symbol: "calendar.badge.plus",
                    title: "还没有安排菜谱",
                    message: "把一道现有菜谱安排到这一天，便能提前做好准备。",
                    actionTitle: "安排一道菜",
                    action: scheduleNextRecipe
                )
            } else {
                ForEach(Array(selectedRecipes.enumerated()), id: \.element.id) { index, recipe in
                    HStack(spacing: 10) {
                        Text(recipe.emoji)
                            .font(.title2)
                        Text(recipe.title)
                            .font(.subheadline.weight(.bold))
                        if isSelectedMenuCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.sage)
                                .accessibilityLabel("已完成")
                        }
                        Spacer()
                        VStack(spacing: 3) {
                            Button {
                                kitchenStore.moveScheduledRecipe(recipe, by: -1, for: selectedDate)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .disabled(index == 0)
                            .accessibilityLabel("将\(recipe.title)提前")
                            Button {
                                kitchenStore.moveScheduledRecipe(recipe, by: 1, for: selectedDate)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .disabled(index == selectedRecipes.count - 1)
                            .accessibilityLabel("将\(recipe.title)延后")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.muted)
                        Button {
                            kitchenStore.removeFromSchedule(recipe, for: selectedDate)
                            coordinator.showToast("已从当天菜单移除")
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
            !selectedRecipes.contains(candidate)
        }) else {
            coordinator.showToast("这一天的菜谱已全部安排")
            return
        }
        kitchenStore.schedule(recipe, for: selectedDate)
        coordinator.showToast("已将\(recipe.title)安排到\(selectedDate.formatted(.dateTime.month().day()))")
    }

    private func changeMonth(by offset: Int) {
        guard let month = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = month
        let selectedDay = Calendar.current.component(.day, from: selectedDate)
        let maximumDay = Calendar.current.range(of: .day, in: .month, for: month)?.count ?? selectedDay
        selectedDate = Calendar.current.date(bySetting: .day, value: min(selectedDay, maximumDay), of: month) ?? month
    }

    private func date(for day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: displayedMonth) ?? displayedMonth
    }
}
