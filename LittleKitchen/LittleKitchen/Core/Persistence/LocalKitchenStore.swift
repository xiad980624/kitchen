import Combine
import Foundation

@MainActor
final class LocalKitchenStore: ObservableObject {
    @Published private(set) var recipes: [Recipe]
    @Published private(set) var votedRecipeIDs: Set<UUID>
    @Published private(set) var reviews: [UUID: RecipeReview]
    @Published private(set) var pantryItems: [PantryItem]
    @Published private(set) var scheduledRecipeIDsByDate: [String: [UUID]]

    private let persistence: any KitchenSnapshotPersisting

    convenience init() {
        self.init(persistence: KitchenSnapshotStorage.live(), legacyDefaults: .standard)
    }

    init(persistence: any KitchenSnapshotPersisting, legacyDefaults: UserDefaults?) {
        self.persistence = persistence

        let persistedSnapshot = persistence.load()
        let snapshot = persistedSnapshot ?? LegacyKitchenSnapshotLoader.load(from: legacyDefaults) ?? Self.sampleSnapshot
        recipes = snapshot.recipes
        votedRecipeIDs = Set(snapshot.votedRecipeIDs)
        reviews = Dictionary(uniqueKeysWithValues: snapshot.reviews.map { ($0.recipeID, $0) })
        pantryItems = snapshot.pantryItems
        scheduledRecipeIDsByDate = snapshot.scheduledRecipeIDsByDate

        if persistedSnapshot == nil {
            persistence.save(snapshot)
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
            recipes[index] = recipe
        } else {
            recipes.insert(recipe, at: 0)
        }
        persistSnapshot()
    }

    func saveReview(recipeID: UUID, rating: Int, comment: String) {
        reviews[recipeID] = RecipeReview(recipeID: recipeID, rating: rating, comment: comment)
        persistSnapshot()
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
        persistSnapshot()
    }

    func removeFromSchedule(_ recipe: Recipe, for date: Date = .now) {
        let key = Self.dateKey(for: date)
        scheduledRecipeIDsByDate[key]?.removeAll { $0 == recipe.id }
        persistSnapshot()
    }

    func addPantryItem(name: String, category: String = "其他") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !pantryItems.contains(where: { $0.name == trimmed }) else { return }
        pantryItems.insert(PantryItem(name: trimmed, emoji: "🛒", category: category, quantity: "待填写"), at: 0)
        persistSnapshot()
    }

    var shoppingList: [String] {
        let stocked = Set(pantryItems.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) })
        return Array(Set(recipes(for: .now).flatMap(\.ingredients).map(\.name).filter { !stocked.contains($0) })).sorted()
    }

    private func persistSnapshot() {
        persistence.save(
            KitchenSnapshot(
                recipes: recipes,
                votedRecipeIDs: votedRecipeIDs.sorted { $0.uuidString < $1.uuidString },
                reviews: reviews.values.sorted { $0.recipeID.uuidString < $1.recipeID.uuidString },
                pantryItems: pantryItems,
                scheduledRecipeIDsByDate: scheduledRecipeIDsByDate
            )
        )
    }

    private static var sampleSnapshot: KitchenSnapshot {
        KitchenSnapshot(
            recipes: SampleData.recipes,
            votedRecipeIDs: [],
            reviews: [],
            pantryItems: SampleData.pantryItems,
            scheduledRecipeIDsByDate: [dateKey(for: .now): Array(SampleData.recipes.prefix(2).map(\.id))]
        )
    }

    private static func dateKey(for date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}
