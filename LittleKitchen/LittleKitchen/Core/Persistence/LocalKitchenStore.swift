import Combine
import Foundation

@MainActor
final class LocalKitchenStore: ObservableObject {
    @Published private(set) var recipes: [Recipe]
    @Published private(set) var votedRecipeIDs: Set<UUID>
    @Published private(set) var reviews: [UUID: RecipeReview]
    @Published private(set) var pantryItems: [PantryItem]
    @Published private(set) var scheduledRecipeIDsByDate: [String: [UUID]]

    private let defaults: UserDefaults
    private let recipesKey = "littleKitchen.localRecipes"
    private let votesKey = "littleKitchen.votedRecipeIDs"
    private let reviewsKey = "littleKitchen.recipeReviews"
    private let pantryKey = "littleKitchen.pantryItems"
    private let mealPlanKey = "littleKitchen.mealPlan"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recipes = Self.decode([Recipe].self, key: recipesKey, defaults: defaults) ?? SampleData.recipes
        votedRecipeIDs = Set(Self.decode([UUID].self, key: votesKey, defaults: defaults) ?? [])
        reviews = Dictionary(uniqueKeysWithValues: (Self.decode([RecipeReview].self, key: reviewsKey, defaults: defaults) ?? []).map { ($0.recipeID, $0) })
        pantryItems = Self.decode([PantryItem].self, key: pantryKey, defaults: defaults) ?? SampleData.pantryItems
        scheduledRecipeIDsByDate = Self.decode([String: [UUID]].self, key: mealPlanKey, defaults: defaults) ?? [Self.dateKey(for: .now): Array(SampleData.recipes.prefix(2).map(\.id))]
        if defaults.data(forKey: recipesKey) == nil { persistRecipes() }
        if defaults.data(forKey: pantryKey) == nil { persist(pantryItems, key: pantryKey) }
        if defaults.data(forKey: mealPlanKey) == nil { persist(scheduledRecipeIDsByDate, key: mealPlanKey) }
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
        persist(votedRecipeIDs.sorted { $0.uuidString < $1.uuidString }, key: votesKey)
    }

    func save(recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
        } else {
            recipes.insert(recipe, at: 0)
        }
        persistRecipes()
    }

    func saveReview(recipeID: UUID, rating: Int, comment: String) {
        reviews[recipeID] = RecipeReview(recipeID: recipeID, rating: rating, comment: comment)
        persist(Array(reviews.values), key: reviewsKey)
    }

    func review(for recipe: Recipe) -> RecipeReview? {
        reviews[recipe.id]
    }

    func recipes(for date: Date = .now) -> [Recipe] {
        let ids = scheduledRecipeIDsByDate[Self.dateKey(for: date)] ?? []
        return ids.compactMap { id in recipes.first { $0.id == id } }
    }

    func schedule(_ recipe: Recipe, for date: Date = .now) {
        let key = Self.dateKey(for: date)
        var ids = scheduledRecipeIDsByDate[key, default: []]
        guard !ids.contains(recipe.id) else { return }
        ids.append(recipe.id)
        scheduledRecipeIDsByDate[key] = ids
        persist(scheduledRecipeIDsByDate, key: mealPlanKey)
    }

    func removeFromSchedule(_ recipe: Recipe, for date: Date = .now) {
        let key = Self.dateKey(for: date)
        scheduledRecipeIDsByDate[key]?.removeAll { $0 == recipe.id }
        persist(scheduledRecipeIDsByDate, key: mealPlanKey)
    }

    func addPantryItem(name: String, category: String = "其他") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !pantryItems.contains(where: { $0.name == trimmed }) else { return }
        pantryItems.insert(PantryItem(name: trimmed, emoji: "🛒", category: category, quantity: "待填写"), at: 0)
        persist(pantryItems, key: pantryKey)
    }

    var shoppingList: [String] {
        let stocked = Set(pantryItems.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) })
        return Array(Set(recipes(for: .now).flatMap(\.ingredients).map(\.name).filter { !stocked.contains($0) })).sorted()
    }

    private func persistRecipes() {
        persist(recipes, key: recipesKey)
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func dateKey(for date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}
