import SwiftUI

struct MenuHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selectedSection = "今天"

    private let sections = ["今天", "我想吃", "家庭常点", "全部菜谱"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                TodayMenuCard()
                sectionPicker
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
                Text("周二 · 9 月 2 日")
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
                Button("搜索") {
                    coordinator.showToast("搜索将在下一轮接入")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.sage)
            }

            ForEach(SampleData.recipes) { recipe in
                NavigationLink(value: recipe) {
                    RecipeRow(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TodayMenuCard: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("阿远刚刚确认", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.72))
                .clipShape(Capsule())

            Text("今晚的家庭菜单")
                .font(.title3.weight(.bold))
            Text("两道菜已安排。根据冰箱库存，还需要买 1 样食材。")
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink.opacity(0.72))

            MenuDishLine(emoji: "🍗", title: "宫保鸡丁", availability: .ready)
            MenuDishLine(emoji: "🥬", title: "清炒时蔬", availability: .short)

            Button("查看今天菜单") {
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
        .accessibilityLabel("今晚的家庭菜单，两道菜已安排，还需要买一项食材")
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

    var body: some View {
        HStack(spacing: 13) {
            RecipeThumbnail(emoji: recipe.emoji, size: 82)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    Text(recipe.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer(minLength: 8)
                    if recipe.voteCount > 0 {
                        Text("\(recipe.voteCount) 人想吃")
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
