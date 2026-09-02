import SwiftUI

struct MenuHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @State private var selectedSection = "今天"
    @State private var searchText = ""
    @State private var selectedCategory: RecipeCategory?
    @State private var sortOption: RecipeSortOption = .recommended

    private let sections = ["今天", "我想吃", "家庭常点", "全部菜谱"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                TodayMenuCard()
                sectionPicker
                searchField
                categoryPicker
                recipeSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(AppTheme.cream.ignoresSafeArea())
        .navigationTitle("今天吃什么？")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    coordinator.isPresentingRecipeEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建菜谱")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("林家厨房")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            HStack(spacing: -8) {
                Avatar(emoji: "👩🏻", color: AppTheme.sageSoft)
                Avatar(emoji: "👨🏻", color: AppTheme.carrotSoft)
                Avatar(emoji: "🧒🏻", color: AppTheme.tomatoSoft)
            }
            .accessibilityLabel("家庭成员 3 人")
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sections, id: \.self) { section in
                    Button(section) {
                        selectedSection = section
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selectedSection == section ? .white : AppTheme.muted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(selectedSection == section ? AppTheme.ink : AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.line, lineWidth: selectedSection == section ? 0 : 1)
                    }
                    .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
                }
            }
        }
        .accessibilityLabel("菜谱分类")
    }

    private var recipeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedSection == "今天" ? "大家想吃的菜" : selectedSection)
                    .font(.title3.weight(.bold))
                Spacer()
                Menu {
                    Picker("排序", selection: $sortOption) {
                        ForEach(RecipeSortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label(sortOption.title, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.sage)
                }
                .accessibilityLabel("菜谱排序：\(sortOption.title)")
                Text("\(filteredRecipes.count) 道")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }

            if filteredRecipes.isEmpty {
                EmptyStateCard(
                    symbol: searchText.isEmpty ? "heart" : "magnifyingglass",
                    title: searchText.isEmpty ? "还没有想吃的菜" : "没有找到匹配的菜谱",
                    message: searchText.isEmpty ? "在菜谱详情点“我想吃”，它会显示在这里。" : "换个菜名、食材或分类试试。",
                    actionTitle: searchText.isEmpty ? nil : "清除搜索",
                    action: searchText.isEmpty ? nil : { searchText = "" }
                )
            } else {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeRow(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.muted)
            TextField("搜索菜名、食材或分类", text: $searchText)
        }
        .padding(12)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("搜索菜谱")
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("全部分类") {
                    selectedCategory = nil
                }
                .categoryChip(isSelected: selectedCategory == nil)
                ForEach(RecipeCategory.allCases) { category in
                    Button(category.rawValue) {
                        selectedCategory = category
                    }
                    .categoryChip(isSelected: selectedCategory == category)
                }
            }
        }
        .accessibilityLabel("按菜谱分类筛选")
    }

    private var filteredRecipes: [Recipe] {
        let sectionRecipes: [Recipe]
        switch selectedSection {
        case "我想吃":
            sectionRecipes = kitchenStore.recipes.filter { kitchenStore.isVoted($0) }
        case "家庭常点":
            sectionRecipes = kitchenStore.recipes.sorted { $0.voteCount > $1.voteCount }
        default:
            sectionRecipes = kitchenStore.recipes
        }
        let categoryRecipes = selectedCategory.map { category in
            sectionRecipes.filter { $0.category == category }
        } ?? sectionRecipes
        let searchedRecipes: [Recipe]
        if searchText.isEmpty {
            searchedRecipes = categoryRecipes
        } else {
            searchedRecipes = categoryRecipes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
                || $0.ingredients.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return sortOption.sort(searchedRecipes, kitchenStore: kitchenStore)
    }
}

private enum RecipeSortOption: String, CaseIterable, Identifiable {
    case recommended
    case quick
    case rating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended: "推荐"
        case .quick: "最快做"
        case .rating: "评分高"
        }
    }

    func sort(_ recipes: [Recipe], kitchenStore: LocalKitchenStore) -> [Recipe] {
        switch self {
        case .recommended:
            recipes.sorted {
                let firstVotes = $0.voteCount + (kitchenStore.isVoted($0) ? 1 : 0)
                let secondVotes = $1.voteCount + (kitchenStore.isVoted($1) ? 1 : 0)
                return firstVotes == secondVotes ? $0.rating > $1.rating : firstVotes > secondVotes
            }
        case .quick:
            recipes.sorted { $0.duration < $1.duration }
        case .rating:
            recipes.sorted { $0.rating > $1.rating }
        }
    }
}

private extension View {
    func categoryChip(isSelected: Bool) -> some View {
        font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : AppTheme.muted)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(isSelected ? AppTheme.sage : AppTheme.paper)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(AppTheme.line, lineWidth: isSelected ? 0 : 1)
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TodayMenuCard: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore

    private var plannedRecipes: [Recipe] {
        kitchenStore.recipes(for: .now)
    }

    private var menuSummary: String {
        guard !plannedRecipes.isEmpty else { return "从菜谱列表安排一道菜，开始准备今晚的菜单。" }
        if kitchenStore.shoppingList.isEmpty {
            return "已安排 \(plannedRecipes.count) 道菜，冰箱库存都够用。"
        }
        return "已安排 \(plannedRecipes.count) 道菜，还需要买 \(kitchenStore.shoppingList.count) 样食材。"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(plannedRecipes.isEmpty ? "等待安排" : "今日菜单", systemImage: plannedRecipes.isEmpty ? "calendar.badge.plus" : "checkmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.72))
                .clipShape(Capsule())

            Text(plannedRecipes.isEmpty ? "今晚吃什么？" : "今晚的家庭菜单")
                .font(.title3.weight(.bold))
            Text(menuSummary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink.opacity(0.72))

            ForEach(plannedRecipes) { recipe in
                MenuDishLine(emoji: recipe.emoji, title: recipe.title, availability: recipe.availability)
            }

            Button(plannedRecipes.isEmpty ? "去安排菜谱" : "查看今天菜单") {
                coordinator.selectedTab = .calendar
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.843, green: 0.925, blue: 0.875), Color(red: 0.976, green: 0.894, blue: 0.729)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("今晚菜单，\(menuSummary)")
    }
}

private struct MenuDishLine: View {
    let emoji: String
    let title: String
    let availability: RecipeAvailability

    var body: some View {
        HStack(spacing: 9) {
            Text(emoji)
                .font(.title3)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer()
            AvailabilityPill(availability: availability)
        }
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    @EnvironmentObject private var kitchenStore: LocalKitchenStore

    var body: some View {
        HStack(spacing: 13) {
            RecipeThumbnail(emoji: recipe.emoji, size: 82)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    Text(recipe.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer(minLength: 8)
                    if recipe.voteCount + (kitchenStore.isVoted(recipe) ? 1 : 0) > 0 {
                        Text("\(recipe.voteCount + (kitchenStore.isVoted(recipe) ? 1 : 0)) 人想吃")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.carrot)
                    }
                }
                Text("\(recipe.category.rawValue) · \(recipe.duration) 分钟")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                HStack {
                    Label(String(format: "%.1f · %d 评", recipe.rating, recipe.reviewCount), systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.78, green: 0.49, blue: 0.08))
                    Spacer()
                    AvailabilityPill(availability: recipe.availability)
                }
            }
        }
        .padding(10)
        .appCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.title)，\(recipe.category.rawValue)，\(recipe.duration) 分钟，\(recipe.availability.rawValue)")
    }
}

struct AvailabilityPill: View {
    let availability: RecipeAvailability

    private var foreground: Color {
        switch availability {
        case .ready: AppTheme.sage
        case .short: AppTheme.tomato
        case .check: AppTheme.carrot
        }
    }

    private var background: Color {
        switch availability {
        case .ready: AppTheme.sageSoft
        case .short: AppTheme.tomatoSoft
        case .check: AppTheme.carrotSoft
        }
    }

    var body: some View {
        Text(availability.rawValue)
            .font(.caption2.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(Capsule())
    }
}

struct RecipeThumbnail: View {
    let emoji: String
    var size: CGFloat = 96

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(AppTheme.carrotSoft)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct Avatar: View {
    let emoji: String
    let color: Color

    var body: some View {
        Text(emoji)
            .font(.body)
            .frame(width: 34, height: 34)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.cream, lineWidth: 2))
    }
}
