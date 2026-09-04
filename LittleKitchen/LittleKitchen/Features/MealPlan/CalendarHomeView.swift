import SwiftUI

struct CalendarHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var selectedDate = Date.now
    @State private var isPresentingMealScheduler = false
    @State private var selectedRecipeID: UUID?
    @State private var selectedMealPeriod: MealPeriod = .dinner
    @State private var selectedMealTime = Date.now

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

    private var availableRecipes: [Recipe] {
        kitchenStore.recipes
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
        }
        .sheet(isPresented: $isPresentingMealScheduler) {
            mealScheduler
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                Spacer()
                Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("上个月")
                Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
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
                    Color.clear.frame(height: 44).accessibilityHidden(true)
                }
                ForEach(days, id: \.self) { day in
                    let cellDate = date(for: day)
                    let meals = kitchenStore.scheduledMeals(for: cellDate)
                    let isSelected = Calendar.current.isDate(cellDate, inSameDayAs: selectedDate)
                    let isToday = Calendar.current.isDateInToday(cellDate)
                    let isCompleted = kitchenStore.isMenuCompleted(for: cellDate)
                    Button { selectedDate = cellDate } label: {
                        VStack(spacing: 3) {
                            Text("\(day)")
                                .font(.caption.weight(isToday || isSelected ? .bold : .regular))
                                .frame(width: 29, height: 29)
                                .background(isSelected ? AppTheme.carrot : (isToday ? AppTheme.sage : .clear))
                                .foregroundStyle((isSelected || isToday) ? .white : AppTheme.ink)
                                .clipShape(Circle())
                            if !meals.isEmpty {
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
                    .accessibilityLabel("\(cellDate.formatted(.dateTime.month().day().weekday(.wide)))\(meals.isEmpty ? "，没有安排" : "，已安排\(meals.count)道菜")")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(16)
        .appCard()
    }

    private var dayMenu: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedDate.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.title3.weight(.bold))
                Text(selectedRecipes.isEmpty ? "选择下方餐次安排菜谱" : (isSelectedMenuCompleted ? "菜单已完成" : "待完成菜单"))
                    .font(.subheadline)
                    .foregroundStyle(selectedRecipes.isEmpty ? AppTheme.muted : (isSelectedMenuCompleted ? AppTheme.sage : AppTheme.carrot))
            }

            ForEach(MealPeriod.allCases) { period in
                mealSection(period)
            }
            if !selectedRecipes.isEmpty {
                Button(isSelectedMenuCompleted ? "撤销完成" : "完成当天菜单") {
                    if isSelectedMenuCompleted {
                        kitchenStore.reopenMenu(for: selectedDate)
                        coordinator.showToast("已恢复当天菜单")
                    } else {
                        kitchenStore.completeMenu(for: selectedDate)
                        coordinator.showToast("菜单已标为完成")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(17)
        .background(AppTheme.carrotSoft)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func mealSection(_ period: MealPeriod) -> some View {
        let meals = kitchenStore.scheduledMeals(for: selectedDate, period: period)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(period.rawValue)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Button {
                    presentMealScheduler(defaultingTo: period)
                } label: {
                    Label("安排", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                }
                .disabled(availableRecipes.isEmpty)
                .accessibilityLabel("安排\(period.rawValue)")
            }
            if meals.isEmpty {
                Text("暂未安排")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(meals) { meal in
                    if let recipe = kitchenStore.recipe(id: meal.recipeID) {
                        HStack(spacing: 10) {
                            Text(meal.timeLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.sage)
                                .frame(width: 40, alignment: .leading)
                            Text(recipe.emoji).font(.title3)
                            Text(recipe.title).font(.subheadline.weight(.bold))
                            if isSelectedMenuCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.sage)
                                    .accessibilityLabel("已完成")
                            }
                            Spacer()
                            Button {
                                kitchenStore.removeScheduledMeal(meal, for: selectedDate)
                                coordinator.showToast("已从当天菜单移除")
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(AppTheme.tomato)
                            }
                            .accessibilityLabel("移除\(recipe.title)")
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var mealScheduler: some View {
        NavigationStack {
            Group {
                if availableRecipes.isEmpty {
                    ContentUnavailableView("还没有菜谱", systemImage: "fork.knife", description: Text("先在菜单中新建一道菜谱。"))
                } else {
                    Form {
                        Picker("选择菜谱", selection: $selectedRecipeID) {
                            ForEach(availableRecipes) { recipe in
                                Text("\(recipe.emoji) \(recipe.title)").tag(Optional(recipe.id))
                            }
                        }
                        DatePicker("时间", selection: $selectedMealTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle(selectedMealPeriod.rawValue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresentingMealScheduler = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("安排") { saveScheduledMeal() }
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.sage)
                        .disabled(selectedRecipeID == nil)
                }
            }
        }
    }

    private func presentMealScheduler(defaultingTo period: MealPeriod = .dinner) {
        selectedRecipeID = availableRecipes.first?.id
        selectedMealPeriod = period
        selectedMealTime = time(for: period.defaultTimeMinutes)
        isPresentingMealScheduler = true
    }

    private func saveScheduledMeal() {
        guard let selectedRecipeID, let recipe = kitchenStore.recipe(id: selectedRecipeID) else { return }
        kitchenStore.schedule(recipe, for: selectedDate, period: selectedMealPeriod, timeMinutes: minutes(in: selectedMealTime))
        coordinator.showToast("已安排\(recipe.title)到\(selectedMealPeriod.rawValue) \(ScheduledMeal(recipeID: recipe.id, period: selectedMealPeriod, timeMinutes: minutes(in: selectedMealTime)).timeLabel)")
        isPresentingMealScheduler = false
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

    private func minutes(in date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func time(for minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }
}
