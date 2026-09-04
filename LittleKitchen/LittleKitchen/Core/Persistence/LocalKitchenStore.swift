import Combine
import Foundation

@MainActor
final class LocalKitchenStore: ObservableObject {
    @Published private(set) var recipes: [Recipe]
    @Published private(set) var votedRecipeIDs: Set<UUID>
    @Published private(set) var reviews: [UUID: RecipeReview]
    @Published private(set) var pantryItems: [PantryItem]
    @Published private(set) var scheduledMealsByDate: [String: [ScheduledMeal]]
    @Published private(set) var completedRecipeIDsByDate: [String: [UUID]]
    @Published private(set) var manualShoppingItems: [ShoppingItem]
    @Published private(set) var checkedAutomaticShoppingItemNames: Set<String>
    @Published private(set) var revisions: [RecipeRevision]

    private let persistence: any KitchenSnapshotPersisting

    convenience init() {
        self.init(persistence: KitchenSnapshotStorage.live(), legacyDefaults: .standard)
    }

    init(persistence: any KitchenSnapshotPersisting, legacyDefaults: UserDefaults?) {
        self.persistence = persistence

        let persistedSnapshot = persistence.load()
        let snapshot = persistedSnapshot ?? LegacyKitchenSnapshotLoader.load(from: legacyDefaults) ?? Self.sampleSnapshot
        let needsMealMigration = snapshot.scheduledMealsByDate.isEmpty && !snapshot.scheduledRecipeIDsByDate.isEmpty
        recipes = snapshot.recipes
        votedRecipeIDs = Set(snapshot.votedRecipeIDs)
        reviews = Dictionary(uniqueKeysWithValues: snapshot.reviews.map { ($0.recipeID, $0) })
        pantryItems = snapshot.pantryItems
        scheduledMealsByDate = snapshot.scheduledMealsByDate.isEmpty
            ? Self.migrateScheduledMeals(from: snapshot.scheduledRecipeIDsByDate)
            : snapshot.scheduledMealsByDate
        completedRecipeIDsByDate = snapshot.completedRecipeIDsByDate
        manualShoppingItems = snapshot.manualShoppingItems
        checkedAutomaticShoppingItemNames = Set(snapshot.checkedAutomaticShoppingItemNames)
        revisions = snapshot.revisions

        if persistedSnapshot == nil || needsMealMigration {
            persistSnapshot()
        }
    }

    func recipe(id: UUID) -> Recipe? {
        recipes.first { $0.id == id }
    }

    func isVoted(_ recipe: Recipe) -> Bool {
        votedRecipeIDs.contains(recipe.id)
    }

    func toggleVote(for recipe: Recipe) {
        if votedRecipeIDs.contains(recipe.id) {
            votedRecipeIDs.remove(recipe.id)
        } else {
            votedRecipeIDs.insert(recipe.id)
        }
        persistSnapshot()
    }

    func save(recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            let previousRecipe = recipes[index]
            guard previousRecipe != recipe else { return }
            recipes[index] = recipe
            revisions.insert(makeRevision(recipe: recipe, previousRecipe: previousRecipe), at: 0)
        } else {
            recipes.insert(recipe, at: 0)
            revisions.insert(makeRevision(recipe: recipe, previousRecipe: nil), at: 0)
        }
        persistSnapshot()
    }

    @discardableResult
    func duplicate(_ recipe: Recipe) -> Recipe {
        let copy = Recipe(
            title: "\(recipe.title) 副本",
            category: recipe.category,
            customCategoryName: recipe.customCategoryName,
            emoji: recipe.emoji,
            imageData: recipe.imageData,
            duration: recipe.duration,
            rating: 0,
            reviewCount: 0,
            voteCount: 0,
            availability: .check,
            ingredients: recipe.ingredients.map {
                RecipeIngredient(name: $0.name, quantity: $0.quantity, kind: $0.kind)
            },
            steps: recipe.steps
        )
        save(recipe: copy)
        return copy
    }

    func delete(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        votedRecipeIDs.remove(recipe.id)
        reviews.removeValue(forKey: recipe.id)
        scheduledMealsByDate = scheduledMealsByDate.mapValues { meals in
            meals.filter { $0.recipeID != recipe.id }
        }
        completedRecipeIDsByDate = completedRecipeIDsByDate.mapValues { recipeIDs in
            recipeIDs.filter { $0 != recipe.id }
        }
        revisions.removeAll { $0.recipeID == recipe.id }
        persistSnapshot()
    }

    func saveReview(recipeID: UUID, rating: Int, comment: String) {
        reviews[recipeID] = RecipeReview(recipeID: recipeID, rating: rating, comment: comment)
        persistSnapshot()
    }

    func review(for recipe: Recipe) -> RecipeReview? {
        reviews[recipe.id]
    }

    func recipes(for date: Date = .now, period: MealPeriod? = nil) -> [Recipe] {
        scheduledMeals(for: date, period: period).compactMap { meal in recipe(id: meal.recipeID) }
    }

    func scheduledMeals(for date: Date = .now, period: MealPeriod? = nil) -> [ScheduledMeal] {
        let meals = scheduledMealsByDate[Self.dateKey(for: date)] ?? []
        return meals
            .filter { period == nil || $0.period == period }
            .sorted {
                if $0.period != $1.period { return MealPeriod.allCases.firstIndex(of: $0.period)! < MealPeriod.allCases.firstIndex(of: $1.period)! }
                if $0.timeMinutes != $1.timeMinutes { return $0.timeMinutes < $1.timeMinutes }
                return $0.sortOrder < $1.sortOrder
            }
    }

    @discardableResult
    func schedule(
        _ recipe: Recipe,
        for date: Date = .now,
        period: MealPeriod = .dinner,
        timeMinutes: Int? = nil
    ) -> Bool {
        let key = Self.dateKey(for: date)
        var meals = scheduledMealsByDate[key, default: []]
        let nextSortOrder = meals.filter { $0.period == period }.map(\.sortOrder).max().map { $0 + 1 } ?? 0
        meals.append(ScheduledMeal(recipeID: recipe.id, period: period, timeMinutes: timeMinutes, sortOrder: nextSortOrder))
        scheduledMealsByDate[key] = meals
        completedRecipeIDsByDate[key] = []
        persistSnapshot()
        return true
    }

    func removeFromSchedule(_ recipe: Recipe, for date: Date = .now) {
        let key = Self.dateKey(for: date)
        scheduledMealsByDate[key]?.removeAll { $0.recipeID == recipe.id }
        completedRecipeIDsByDate[key]?.removeAll { $0 == recipe.id }
        persistSnapshot()
    }

    func removeScheduledMeal(_ meal: ScheduledMeal, for date: Date = .now) {
        let key = Self.dateKey(for: date)
        scheduledMealsByDate[key]?.removeAll { $0.id == meal.id }
        completedRecipeIDsByDate[key]?.removeAll { $0 == meal.recipeID }
        persistSnapshot()
    }

    func moveScheduledRecipe(_ recipe: Recipe, by offset: Int, for date: Date = .now) {
        let key = Self.dateKey(for: date)
        guard var meals = scheduledMealsByDate[key],
              let currentMeal = meals.first(where: { $0.recipeID == recipe.id }) else { return }
        let periodMeals = meals.filter { $0.period == currentMeal.period }.sorted {
            $0.timeMinutes == $1.timeMinutes ? $0.sortOrder < $1.sortOrder : $0.timeMinutes < $1.timeMinutes
        }
        guard let currentIndex = periodMeals.firstIndex(of: currentMeal) else { return }
        let destinationIndex = currentIndex + offset
        guard periodMeals.indices.contains(destinationIndex),
              let firstIndex = meals.firstIndex(of: currentMeal),
              let secondIndex = meals.firstIndex(of: periodMeals[destinationIndex]) else { return }
        let firstOrder = meals[firstIndex].sortOrder
        meals[firstIndex].sortOrder = meals[secondIndex].sortOrder
        meals[secondIndex].sortOrder = firstOrder
        scheduledMealsByDate[key] = meals
        persistSnapshot()
    }

    func isMenuCompleted(for date: Date = .now) -> Bool {
        let scheduledIDs = scheduledMeals(for: date).map(\.recipeID)
        guard !scheduledIDs.isEmpty else { return false }
        let completedIDs = Set(completedRecipeIDsByDate[Self.dateKey(for: date)] ?? [])
        return Set(scheduledIDs).isSubset(of: completedIDs)
    }

    func completeMenu(for date: Date = .now) {
        let key = Self.dateKey(for: date)
        let scheduledIDs = scheduledMeals(for: date).map(\.recipeID)
        guard !scheduledIDs.isEmpty else { return }
        completedRecipeIDsByDate[key] = scheduledIDs
        persistSnapshot()
    }

    func reopenMenu(for date: Date = .now) {
        completedRecipeIDsByDate[Self.dateKey(for: date)] = []
        persistSnapshot()
    }

    @discardableResult
    func addPantryItem(
        name: String,
        category: String = "其他",
        quantity: String = "待填写",
        expiryHint: String? = nil
    ) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !pantryItems.contains(where: { $0.name == trimmed }) else { return false }
        pantryItems.insert(
            PantryItem(
                name: trimmed,
                emoji: "🛒",
                category: normalizedPantryField(category, fallback: "其他"),
                quantity: normalizedPantryField(quantity, fallback: "待填写"),
                expiryHint: normalizedExpiryHint(expiryHint)
            ),
            at: 0
        )
        persistSnapshot()
        return true
    }

    @discardableResult
    func updatePantryItem(
        _ item: PantryItem,
        name: String,
        category: String,
        quantity: String,
        expiryHint: String?
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = pantryItems.firstIndex(where: { $0.id == item.id }),
              !trimmedName.isEmpty,
              !pantryItems.contains(where: { $0.id != item.id && $0.name == trimmedName }) else { return false }

        pantryItems[index] = PantryItem(
            id: item.id,
            name: trimmedName,
            emoji: item.emoji,
            category: normalizedPantryField(category, fallback: "其他"),
            quantity: normalizedPantryField(quantity, fallback: "待填写"),
            expiryHint: normalizedExpiryHint(expiryHint)
        )
        persistSnapshot()
        return true
    }

    func removePantryItem(_ item: PantryItem) {
        pantryItems.removeAll { $0.id == item.id }
        persistSnapshot()
    }

    var shoppingList: [String] {
        shoppingList(for: .now)
    }

    var shoppingItems: [ShoppingListEntry] {
        shoppingItems(for: .now)
    }

    func shoppingList(for date: Date, period: MealPeriod? = nil) -> [String] {
        automaticShoppingMatches(for: date, period: period).map(\.name)
    }

    func shoppingItems(for date: Date, period: MealPeriod? = nil) -> [ShoppingListEntry] {
        let automaticItems = automaticShoppingMatches(for: date, period: period).map { match in
            ShoppingListEntry(
                id: "automatic:\(match.id)",
                name: match.name,
                isManual: false,
                isChecked: checkedAutomaticShoppingItemNames.contains(normalizedShoppingName(match.name)),
                automaticQuantity: match.shoppingQuantity,
                matchStatus: match.status,
                sourceRecipeTitles: match.sourceRecipeTitles
            )
        }
        let manualItems = manualShoppingItems.map { item in
            ShoppingListEntry(id: "manual:\(item.id.uuidString)", name: item.name, isManual: true, isChecked: item.isChecked)
        }
        return automaticItems + manualItems
    }

    @discardableResult
    func addShoppingItem(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !manualShoppingItems.contains(where: { $0.name == trimmed }) else { return false }
        manualShoppingItems.append(ShoppingItem(name: trimmed))
        persistSnapshot()
        return true
    }

    func toggleShoppingItem(_ item: ShoppingListEntry) {
        if item.isManual, let index = manualShoppingItems.firstIndex(where: { "manual:\($0.id.uuidString)" == item.id }) {
            manualShoppingItems[index].isChecked.toggle()
        } else {
            let key = normalizedShoppingName(item.name)
            if checkedAutomaticShoppingItemNames.contains(key) {
                checkedAutomaticShoppingItemNames.remove(key)
            } else {
                checkedAutomaticShoppingItemNames.insert(key)
            }
        }
        persistSnapshot()
    }

    func removeShoppingItem(_ item: ShoppingListEntry) {
        guard item.isManual else { return }
        manualShoppingItems.removeAll { "manual:\($0.id.uuidString)" == item.id }
        persistSnapshot()
    }

    func ingredientMatches(for date: Date = .now, period: MealPeriod? = nil) -> [IngredientStockMatch] {
        IngredientStockMatcher.matches(recipes: recipes(for: date, period: period), pantryItems: pantryItems)
    }

    var quantityNeedsConfirmationCount: Int {
        ingredientMatches().filter { $0.status == .check }.count
    }

    private func automaticShoppingMatches(for date: Date, period: MealPeriod?) -> [IngredientStockMatch] {
        ingredientMatches(for: date, period: period).filter { $0.status == .missing || $0.status == .short }
    }

    func revisions(for recipe: Recipe) -> [RecipeRevision] {
        revisions
            .filter { $0.recipeID == recipe.id }
            .sorted { $0.version > $1.version }
    }

    var customCategoryNames: [String] {
        Array(Set(recipes.compactMap(\.customCategoryName))).sorted()
    }

    private func persistSnapshot() {
        persistence.save(
            KitchenSnapshot(
                recipes: recipes,
                votedRecipeIDs: votedRecipeIDs.sorted { $0.uuidString < $1.uuidString },
                reviews: reviews.values.sorted { $0.recipeID.uuidString < $1.recipeID.uuidString },
                pantryItems: pantryItems,
                scheduledRecipeIDsByDate: scheduledMealsByDate.mapValues { meals in
                    meals.sorted {
                        $0.timeMinutes == $1.timeMinutes ? $0.sortOrder < $1.sortOrder : $0.timeMinutes < $1.timeMinutes
                    }.map(\.recipeID)
                },
                scheduledMealsByDate: scheduledMealsByDate,
                completedRecipeIDsByDate: completedRecipeIDsByDate,
                manualShoppingItems: manualShoppingItems,
                checkedAutomaticShoppingItemNames: checkedAutomaticShoppingItemNames.sorted(),
                revisions: revisions
            )
        )
    }

    private func makeRevision(recipe: Recipe, previousRecipe: Recipe?) -> RecipeRevision {
        let version = revisions.filter { $0.recipeID == recipe.id }.count + 1
        return RecipeRevision(
            recipeID: recipe.id,
            version: version,
            summary: revisionSummary(for: recipe, previousRecipe: previousRecipe),
            previousRecipe: previousRecipe,
            recipe: recipe
        )
    }

    private func revisionSummary(for recipe: Recipe, previousRecipe: Recipe?) -> String {
        guard let previousRecipe else { return "新建了“\(recipe.title)”" }

        var changes: [String] = []
        if previousRecipe.title != recipe.title { changes.append("菜谱名称") }
        if previousRecipe.categoryName != recipe.categoryName { changes.append("分类") }
        if previousRecipe.duration != recipe.duration { changes.append("烹饪时长") }
        if previousRecipe.ingredients != recipe.ingredients { changes.append("食材") }
        if previousRecipe.steps != recipe.steps { changes.append("步骤") }

        return changes.isEmpty ? "更新了“\(recipe.title)”" : "修改了\(changes.joined(separator: "、"))"
    }

    private func normalizedPantryField(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func normalizedExpiryHint(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedShoppingName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static var sampleSnapshot: KitchenSnapshot {
        KitchenSnapshot(
            recipes: SampleData.recipes,
            votedRecipeIDs: [],
            reviews: [],
            pantryItems: SampleData.pantryItems,
            scheduledRecipeIDsByDate: [dateKey(for: .now): Array(SampleData.recipes.prefix(2).map(\.id))],
            completedRecipeIDsByDate: [:],
            manualShoppingItems: [],
            checkedAutomaticShoppingItemNames: [],
            revisions: []
        )
    }

    private static func dateKey(for date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    private static func migrateScheduledMeals(from recipeIDsByDate: [String: [UUID]]) -> [String: [ScheduledMeal]] {
        recipeIDsByDate.mapValues { recipeIDs in
            recipeIDs.enumerated().map { index, recipeID in
                ScheduledMeal(recipeID: recipeID, period: .dinner, sortOrder: index)
            }
        }
    }
}
