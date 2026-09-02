import SwiftUI

struct PantryHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @State private var isPresentingAddItem = false
    @State private var newItemName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summary
                    tonightCheck
                    shoppingList
                    inventory
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .background(AppTheme.cream.ignoresSafeArea())
            .navigationTitle("冰箱")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddItem = true
                    } label: {
                        Label("添加", systemImage: "plus")
                    }
                    .accessibilityLabel("添加食材到冰箱")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddItem) {
            NavigationStack {
                Form {
                    TextField("食材名称", text: $newItemName)
                        .accessibilityLabel("食材名称")
                }
                .navigationTitle("添加食材")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { isPresentingAddItem = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("入库") {
                            kitchenStore.addPantryItem(name: newItemName)
                            newItemName = ""
                            isPresentingAddItem = false
                            coordinator.showToast("食材已加入冰箱")
                        }
                    }
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("现有食材")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Text("\(kitchenStore.pantryItems.count)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("已保存到本机")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .background(AppTheme.sage)
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("需要留意")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Text("\(expiryItemCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.tomato)
                Text(expiryItemCount == 0 ? "暂无临期提醒" : "临期食材提醒")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17)
            .appCard()
        }
    }

    private var tonightCheck: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今晚菜单核对")
                .font(.title3.weight(.bold))
            let hasPlannedRecipes = !kitchenStore.recipes(for: .now).isEmpty
            HStack(spacing: 13) {
                RecipeThumbnail(emoji: hasPlannedRecipes ? (kitchenStore.shoppingList.isEmpty ? "✅" : "🛒") : "🍽️", size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(tonightCheckTitle(hasPlannedRecipes: hasPlannedRecipes))
                            .font(.headline)
                        Spacer()
                        AvailabilityPill(availability: hasPlannedRecipes ? (kitchenStore.shoppingList.isEmpty ? .ready : .short) : .check)
                    }
                    Text(tonightCheckMessage(hasPlannedRecipes: hasPlannedRecipes))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .padding(12)
            .appCard()
        }
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("冰箱里的食材")
                .font(.title3.weight(.bold))
            if kitchenStore.pantryItems.isEmpty {
                EmptyStateCard(
                    symbol: "refrigerator",
                    title: "冰箱还是空的",
                    message: "先录入已有食材，菜单核对才能准确提示缺少什么。",
                    actionTitle: "添加食材",
                    action: { isPresentingAddItem = true }
                )
            } else {
                ForEach(kitchenStore.pantryItems) { item in
                    HStack(spacing: 12) {
                        Text(item.emoji)
                            .font(.title2)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.carrotSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.weight(.bold))
                            Text(item.expiryHint ?? item.category)
                                .font(.caption)
                                .foregroundStyle(item.expiryHint == nil ? AppTheme.muted : AppTheme.tomato)
                        }
                        Spacer()
                        Text(item.quantity)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .appCard()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.name)，\(item.quantity)，\(item.expiryHint ?? item.category)")
                }
            }
        }
    }

    private var shoppingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("待购清单")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("根据今天已安排菜单")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            if kitchenStore.shoppingList.isEmpty {
                Label("食材齐全", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.sage)
            } else {
                ForEach(kitchenStore.shoppingList, id: \.self) { item in
                    HStack {
                        Image(systemName: "circle")
                            .foregroundStyle(AppTheme.carrot)
                        Text(item)
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.carrotSoft)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var expiryItemCount: Int {
        kitchenStore.pantryItems.filter { $0.expiryHint != nil }.count
    }

    private func tonightCheckTitle(hasPlannedRecipes: Bool) -> String {
        guard hasPlannedRecipes else { return "还没有安排菜单" }
        return kitchenStore.shoppingList.isEmpty ? "今天的菜谱都可以做" : "还差 \(kitchenStore.shoppingList.count) 样食材"
    }

    private func tonightCheckMessage(hasPlannedRecipes: Bool) -> String {
        guard hasPlannedRecipes else { return "在日历安排菜谱后，这里会自动核对冰箱库存。" }
        return kitchenStore.shoppingList.isEmpty ? "冰箱库存已满足今天菜单。" : "缺少食材已自动汇总到下方待购清单。"
    }
}
