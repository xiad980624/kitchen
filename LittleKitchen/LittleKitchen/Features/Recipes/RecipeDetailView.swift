import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRating = 5
    @State private var reviewText = ""
    @State private var isPresentingSchedulePicker = false
    @State private var scheduledDate = Date.now
    @State private var scheduledMealPeriod: MealPeriod = .dinner
    @State private var scheduledMealTime = Date.now
    @State private var isConfirmingRecipeDeletion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                actionRow
                availabilityCard
                ingredients
                steps
                reviews
                revisionHistory
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .background(AppTheme.cream.ignoresSafeArea())
        .navigationTitle(recipe.title)
        .toolbar {
            Menu {
                Button("编辑", systemImage: "pencil") {
                    coordinator.editingRecipe = recipe
                    coordinator.isPresentingRecipeEditor = true
                }
                Button("复制菜谱", systemImage: "doc.on.doc") {
                    let copy = kitchenStore.duplicate(recipe)
                    coordinator.showToast("已复制为“\(copy.title)”")
                }
                Button("删除菜谱", systemImage: "trash", role: .destructive) {
                    isConfirmingRecipeDeletion = true
                }
            } label: {
                Label("管理菜谱", systemImage: "ellipsis.circle")
            }
        }
        .confirmationDialog("删除“\(recipe.title)”？", isPresented: $isConfirmingRecipeDeletion, titleVisibility: .visible) {
            Button("删除菜谱", role: .destructive) {
                kitchenStore.delete(recipe)
                dismiss()
                coordinator.showToast("已删除“\(recipe.title)”")
            }
        } message: {
            Text("这会移除这道菜的日历安排、点评和修改记录，无法恢复。")
        }
        .onAppear {
            if let review = kitchenStore.review(for: recipe) {
                selectedRating = review.rating
                reviewText = review.comment
            }
        }
        .sheet(isPresented: $isPresentingSchedulePicker) {
            NavigationStack {
                Form {
                    DatePicker("安排日期", selection: $scheduledDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    Picker("用餐时段", selection: $scheduledMealPeriod) {
                        ForEach(MealPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    DatePicker("时间", selection: $scheduledMealTime, displayedComponents: .hourAndMinute)
                }
                .navigationTitle("安排\(recipe.title)")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { isPresentingSchedulePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("安排") {
                            if kitchenStore.schedule(
                                recipe,
                                for: scheduledDate,
                                period: scheduledMealPeriod,
                                timeMinutes: minutes(in: scheduledMealTime)
                            ) {
                                coordinator.showToast("已安排到\(scheduledDate.formatted(.dateTime.month().day())) \(scheduledMealPeriod.rawValue)")
                                isPresentingSchedulePicker = false
                            } else {
                                coordinator.showToast("这道菜已安排在当天菜单")
                            }
                        }
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecipeThumbnail(emoji: recipe.emoji, imageData: recipe.imageData, size: 136)
            Text(recipe.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            HStack(spacing: 12) {
                Label(recipe.categoryName, systemImage: "tag")
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
                kitchenStore.toggleVote(for: recipe)
                coordinator.showToast(kitchenStore.isVoted(recipe) ? "已加入想吃清单" : "已取消点菜")
            } label: {
                Label(kitchenStore.isVoted(recipe) ? "已点菜" : "我想吃", systemImage: kitchenStore.isVoted(recipe) ? "heart.fill" : "heart")
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                scheduledDate = .now
                scheduledMealPeriod = .dinner
                scheduledMealTime = time(for: .dinner)
                isPresentingSchedulePicker = true
            } label: {
                Label("安排日期", systemImage: "calendar.badge.plus")
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
            Picker("我的评分", selection: $selectedRating) {
                ForEach(1...5, id: \.self) { rating in
                    Text("\(rating) 星").tag(rating)
                }
            }
            .pickerStyle(.segmented)
            TextField("写下这次的感受（可选）", text: $reviewText, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .appCard()
            Button("保存我的评分") {
                kitchenStore.saveReview(recipeID: recipe.id, rating: selectedRating, comment: reviewText)
                coordinator.showToast("评分已保存")
            }
            .buttonStyle(PrimaryButtonStyle())
            if let review = kitchenStore.review(for: recipe) {
                Text("你给了 \(review.rating) 星\(review.comment.isEmpty ? "" : "：\(review.comment)")")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var revisionHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("修改记录")
                .font(.title3.weight(.bold))

            let history = kitchenStore.revisions(for: recipe)
            if history.isEmpty {
                Text("保存菜谱后的修改会显示在这里")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }

            ForEach(history) { revision in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        if let previousRecipe = revision.previousRecipe {
                            snapshotSummary(previousRecipe, title: "修改前")
                        }
                        snapshotSummary(revision.recipe, title: "保存后")
                    }
                    .padding(.top, 8)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("版本 \(revision.version) · \(revision.summary)")
                            .font(.subheadline.weight(.semibold))
                        Text(revision.editedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .tint(AppTheme.sage)
                .padding(14)
                .appCard()
            }
        }
    }

    private func snapshotSummary(_ snapshot: Recipe, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            Text("\(snapshot.title) · \(snapshot.categoryName) · \(snapshot.duration) 分钟")
                .font(.subheadline)
            Text(snapshot.ingredients.map(\.name).joined(separator: "、"))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func minutes(in date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func time(for period: MealPeriod) -> Date {
        Calendar.current.date(
            bySettingHour: period.defaultTimeMinutes / 60,
            minute: period.defaultTimeMinutes % 60,
            second: 0,
            of: .now
        ) ?? .now
    }
}
