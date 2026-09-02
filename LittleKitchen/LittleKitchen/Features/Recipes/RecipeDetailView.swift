import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var hasVoted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                actionRow
                availabilityCard
                ingredients
                steps
                reviews
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .background(AppTheme.cream.ignoresSafeArea())
        .navigationTitle(recipe.title)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecipeThumbnail(emoji: recipe.emoji, size: 136)
            Text(recipe.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 12) {
                Label(recipe.category.rawValue, systemImage: "tag")
                Label("\(recipe.duration) 分钟", systemImage: "clock")
                Label(String(format: "%.1f", recipe.rating), systemImage: "star.fill")
                    .foregroundStyle(Color(red: 0.78, green: 0.49, blue: 0.08))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.muted)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                hasVoted.toggle()
                coordinator.showToast(hasVoted ? "已加入想吃清单" : "已取消点菜")
            } label: {
                Label(hasVoted ? "已点菜" : "我想吃", systemImage: hasVoted ? "heart.fill" : "heart")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                coordinator.selectedTab = .calendar
                coordinator.showToast("请选择日期安排这道菜")
            } label: {
                Label("安排", systemImage: "calendar.badge.plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.sage)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.sage, lineWidth: 1.5))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var availabilityCard: some View {
        HStack(spacing: 12) {
            Image(systemName: recipe.availability == .ready ? "checkmark.circle.fill" : "cart.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(recipe.availability == .ready ? AppTheme.sage : AppTheme.carrot)
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.availability.rawValue)
                    .font(.headline)
                Text(recipe.availability == .ready ? "冰箱现有食材足够做这道菜。" : "缺少的食材将显示在待购清单中。")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
        }
        .padding(16)
        .background(recipe.availability == .ready ? AppTheme.sageSoft : AppTheme.carrotSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("食材")
                .font(.title3.weight(.bold))
            ForEach(IngredientKind.allCases, id: \.self) { kind in
                let items = recipe.ingredients(for: kind)
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kind.rawValue)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.muted)
                        ForEach(items) { ingredient in
                            HStack {
                                Text(ingredient.name)
                                Spacer()
                                Text(ingredient.quantity)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(15)
                    .appCard()
                }
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("操作步骤")
                .font(.title3.weight(.bold))
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 25, height: 25)
                        .background(AppTheme.sage)
                        .clipShape(Circle())
                    Text(step)
                        .font(.body)
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var reviews: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("家庭点评")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("\(recipe.reviewCount) 条")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            Text("“这次的花生炒得特别香，下次少放一点糖。”")
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .padding(15)
                .appCard()
        }
    }
}
