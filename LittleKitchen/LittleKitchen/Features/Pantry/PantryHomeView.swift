import SwiftUI

struct PantryHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var kitchenStore: LocalKitchenStore
    @State private var isPresentingAddItem = false
    @State private var itemBeingEdited: PantryItem?
    @State private var itemPendingRemoval: PantryItem?
    @State private var isPresentingAddShoppingItem = false
    @State private var newItemName = ""
    @State private var newItemCategory = "其他"
    @State private var newItemQuantity = ""
    @State private var isExpiryReminderEnabled = false
    @State private var expiryReminderDate = Date.now
    @State private var newShoppingItemName = ""
    @State private var shoppingDate = Date.now
    @State private var selectedShoppingPeriod: ShoppingPeriodFilter = .all

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
                        presentNewItemEditor()
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
                    Picker("食材分类", selection: $newItemCategory) {
                        ForEach(PantryCategory.allCases) { category in
                            Text(category.rawValue).tag(category.rawValue)
                        }
                        if !PantryCategory.allCases.map(\.rawValue).contains(newItemCategory) {
                            Text(newItemCategory).tag(newItemCategory)
                        }
                    }
                    .accessibilityLabel("食材分类")
                    TextField("数量，例如 2 根", text: $newItemQuantity)
                        .accessibilityLabel("食材数量")
                    Toggle("设置临期提醒", isOn: $isExpiryReminderEnabled)
                        .tint(AppTheme.tomato)
                    if isExpiryReminderEnabled {
                        DatePicker("临期日期", selection: $expiryReminderDate, displayedComponents: .date)
                            .accessibilityLabel("临期日期")
                    }
                }
                .navigationTitle(itemBeingEdited == nil ? "添加食材" : "编辑食材")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismissItemEditor() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(itemBeingEdited == nil ? "入库" : "保存") {
                            saveItemEditor()
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .confirmationDialog(
            "从冰箱移除\(itemPendingRemoval?.name ?? "")？",
            isPresented: Binding(
                get: { itemPendingRemoval != nil },
                set: { if !$0 { itemPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("移除", role: .destructive) {
                guard let itemPendingRemoval else { return }
                kitchenStore.removePantryItem(itemPendingRemoval)
                coordinator.showToast("已从冰箱移除\(itemPendingRemoval.name)")
                self.itemPendingRemoval = nil
            }
        } message: {
            Text("移除后，待购清单会按最新库存重新计算。")
        }
        .sheet(isPresented: $isPresentingAddShoppingItem) {
            NavigationStack {
                Form {
                    Section {
                        TextField("例如：厨房纸", text: $newShoppingItemName)
                            .accessibilityLabel("待购项目名称")
                    } footer: {
                        Text("手动加入的项目会保存在本机，不受菜单和日期筛选影响。")
                    }
                }
                .navigationTitle("补充待购项")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            newShoppingItemName = ""
                            isPresentingAddShoppingItem = false
                        }
                        .foregroundStyle(AppTheme.muted)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("添加") {
                            guard kitchenStore.addShoppingItem(name: newShoppingItemName) else {
                                coordinator.showToast("待购项不能为空，且不能重复")
                                return
                            }
                            newShoppingItemName = ""
                            isPresentingAddShoppingItem = false
                            coordinator.showToast("已加入待购清单")
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.sage)
                        .disabled(newShoppingItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    action: presentNewItemEditor
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
                            Text(item.category)
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                            if let expiryHint = item.expiryHint {
                                Text("临期：\(displayExpiryHint(expiryHint))")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.tomato)
                            }
                        }
                        Spacer()
                        Text(item.quantity)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                        Menu {
                            Button("编辑") {
                                presentItemEditor(for: item)
                            }
                            Button("移除", role: .destructive) {
                                itemPendingRemoval = item
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(AppTheme.muted)
                        }
                        .accessibilityLabel("管理\(item.name)")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .appCard()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.name)，\(item.category)，\(item.quantity)\(item.expiryHint.map { "，临期\(displayExpiryHint($0))" } ?? "")")
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
                Button {
                    newShoppingItemName = ""
                    isPresentingAddShoppingItem = true
                } label: {
                    Label("补充", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .accessibilityLabel("手动添加待购项")
            }
            Text("缺少或不足的食材会自动加入，并显示还需购买的数量。")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            HStack(spacing: 10) {
                DatePicker("菜单日期", selection: $shoppingDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                Picker("餐次", selection: $selectedShoppingPeriod) {
                    ForEach(ShoppingPeriodFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                Spacer(minLength: 0)
                Button {
                    shoppingDate = .now
                } label: {
                    Text("今")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isShoppingDateToday ? AppTheme.muted : .white)
                        .frame(width: 30, height: 30)
                        .background(isShoppingDateToday ? AppTheme.paper : AppTheme.sage)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isShoppingDateToday)
                .accessibilityLabel("回到今天")
            }
            let items = kitchenStore.shoppingItems(for: shoppingDate, period: selectedShoppingPeriod.period)
            if items.isEmpty {
                Label("暂无待购项", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.sage)
            } else {
                ForEach(items) { item in
                    HStack(alignment: .top) {
                        Button {
                            kitchenStore.toggleShoppingItem(item)
                        } label: {
                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isChecked ? AppTheme.sage : AppTheme.carrot)
                        }
                        .accessibilityLabel("\(item.isChecked ? "取消勾选" : "勾选")\(item.name)")
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(item.name)
                                    .font(.subheadline.weight(.medium))
                                    .strikethrough(item.isChecked)
                                    .foregroundStyle(item.isChecked ? AppTheme.muted : AppTheme.ink)
                                if let automaticQuantity = item.automaticQuantity {
                                    Text(item.matchStatus == .short ? "还差 \(automaticQuantity)" : "缺少 \(automaticQuantity)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.tomato)
                                }
                                if item.isManual {
                                    Text("手动")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(AppTheme.sage)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(AppTheme.sageSoft)
                                        .clipShape(Capsule())
                                }
                            }
                            if !item.sourceRecipeTitles.isEmpty {
                                Text("来自：\(item.sourceRecipeTitles.joined(separator: "、"))")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                        Spacer()
                        if item.isManual {
                            Button {
                                kitchenStore.removeShoppingItem(item)
                                coordinator.showToast("已移除\(item.name)")
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(AppTheme.tomato)
                            }
                            .accessibilityLabel("移除待购项\(item.name)")
                        }
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

    private var isShoppingDateToday: Bool {
        Calendar.current.isDateInToday(shoppingDate)
    }

    private func tonightCheckTitle(hasPlannedRecipes: Bool) -> String {
        guard hasPlannedRecipes else { return "还没有安排菜单" }
        if kitchenStore.shoppingList.isEmpty, kitchenStore.quantityNeedsConfirmationCount == 0 {
            return "今天的菜谱都可以做"
        }
        if kitchenStore.shoppingList.isEmpty {
            return "有 \(kitchenStore.quantityNeedsConfirmationCount) 样食材待确认"
        }
        return "还差 \(kitchenStore.shoppingList.count) 样食材"
    }

    private func tonightCheckMessage(hasPlannedRecipes: Bool) -> String {
        guard hasPlannedRecipes else { return "在日历安排菜谱后，这里会自动核对冰箱库存。" }
        if kitchenStore.shoppingList.isEmpty, kitchenStore.quantityNeedsConfirmationCount == 0 {
            return "冰箱库存和数量已满足今天菜单。"
        }
        if kitchenStore.shoppingList.isEmpty {
            return "有食材的数量或单位无法判断，请补充库存数量。"
        }
        return "缺少食材已按实际差额汇总到下方待购清单。"
    }

    private func presentNewItemEditor() {
        itemBeingEdited = nil
        newItemName = ""
        newItemCategory = "其他"
        newItemQuantity = ""
        isExpiryReminderEnabled = false
        expiryReminderDate = .now
        isPresentingAddItem = true
    }

    private func presentItemEditor(for item: PantryItem) {
        itemBeingEdited = item
        newItemName = item.name
        newItemCategory = item.category
        newItemQuantity = item.quantity
        isExpiryReminderEnabled = item.expiryHint != nil
        if let expiryHint = item.expiryHint, let date = Self.expiryDate(from: expiryHint) {
            expiryReminderDate = date
        } else {
            expiryReminderDate = .now
        }
        isPresentingAddItem = true
    }

    private func saveItemEditor() {
        let didSave: Bool
        if let itemBeingEdited {
            didSave = kitchenStore.updatePantryItem(
                itemBeingEdited,
                name: newItemName,
                category: newItemCategory,
                quantity: newItemQuantity,
                expiryHint: isExpiryReminderEnabled ? Self.expiryHint(for: expiryReminderDate) : nil
            )
        } else {
            didSave = kitchenStore.addPantryItem(
                name: newItemName,
                category: newItemCategory,
                quantity: newItemQuantity,
                expiryHint: isExpiryReminderEnabled ? Self.expiryHint(for: expiryReminderDate) : nil
            )
        }

        guard didSave else {
            coordinator.showToast("食材名称不能为空，且不能重复")
            return
        }
        coordinator.showToast(itemBeingEdited == nil ? "食材已加入冰箱" : "食材信息已更新")
        dismissItemEditor()
    }

    private func dismissItemEditor() {
        isPresentingAddItem = false
        itemBeingEdited = nil
    }

    private func displayExpiryHint(_ hint: String) -> String {
        Self.expiryDate(from: hint)?.formatted(.dateTime.month().day()) ?? hint
    }

    private static func expiryHint(for date: Date) -> String {
        expiryDateFormatter.string(from: date)
    }

    private static func expiryDate(from hint: String) -> Date? {
        expiryDateFormatter.date(from: hint)
    }

    private static let expiryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private enum PantryCategory: String, CaseIterable, Identifiable {
    case vegetables = "蔬菜"
    case fruits = "水果"
    case meatAndDairy = "肉蛋奶"
    case seafood = "水产"
    case staple = "主食"
    case seasoning = "调味料"
    case drinks = "饮品"
    case other = "其他"

    var id: String { rawValue }
}

private enum ShoppingPeriodFilter: String, CaseIterable, Identifiable {
    case all
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全天"
        case .breakfast: return "早餐"
        case .lunch: return "午餐"
        case .dinner: return "晚餐"
        }
    }

    var period: MealPeriod? {
        switch self {
        case .all: return nil
        case .breakfast: return .breakfast
        case .lunch: return .lunch
        case .dinner: return .dinner
        }
    }
}
