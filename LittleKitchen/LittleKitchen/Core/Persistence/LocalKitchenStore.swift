import Combine
import Foundation

@MainActor
final class LocalKitchenStore: ObservableObject {
    @Published private(set) var recipes: [Recipe]
    @Published private(set) var votedRecipeIDs: Set<UUID>
    @Published private(set) var reviews: [UUID: RecipeReview]

    private let defaults: UserDefaults
    private let recipesKey = "littleKitchen.localRecipes"
    private let votesKey = "littleKitchen.votedRecipeIDs"
    private let reviewsKey = "littleKitchen.recipeReviews"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recipes = Self.decode([Recipe].self, key: recipesKey, defaults: defaults) ?? SampleData.recipes
        votedRecipeIDs = Set(Self.decode([UUID].self, key: votesKey, defaults: defaults) ?? [])
        reviews = Dictionary(uniqueKeysWithValues: (Self.decode([RecipeReview].self, key: reviewsKey, defaults: defaults) ?? []).map { ($0.recipeID, $0) })
        if defaults.data(forKey: recipesKey) == nil { persistRecipes() }
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
}
