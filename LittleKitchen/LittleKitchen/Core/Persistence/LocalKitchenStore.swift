import Combine
import Foundation

@MainActor
final class LocalKitchenStore: ObservableObject {
    @Published private(set) var recipes: [Recipe]
    @Published private(set) var votedRecipeIDs: Set<UUID>
    @Published private(set) var reviews: [UUID: RecipeReview]
    @Published private(set) var pantryItems: [PantryItem]
    @Published private(set) var scheduledRecipeIDsByDate: [String: [UUID]]
    @Published private(set) var revisions: [RecipeRevision]

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
        revisions = snapshot.revisions

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

    func revisions(for recipe: Recipe) -> [RecipeRevision] {
        revisions
            .filter { $0.recipeID == recipe.id }
            .sorted { $0.version > $1.version }
    }

    private func persistSnapshot() {
        persistence.save(
            KitchenSnapshot(
                recipes: recipes,
                votedRecipeIDs: votedRecipeIDs.sorted { $0.uuidString < $1.uuidString },
                reviews: reviews.values.sorted { $0.recipeID.uuidString < $1.recipeID.uuidString },
                pantryItems: pantryItems,
                scheduledRecipeIDsByDate: scheduledRecipeIDsByDate,
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
        if previousRecipe.category != recipe.category { changes.append("分类") }
        if previousRecipe.duration != recipe.duration { changes.append("烹饪时长") }
        if previousRecipe.ingredients != recipe.ingredients { changes.append("食材") }
        if previousRecipe.steps != recipe.steps { changes.append("步骤") }

        return changes.isEmpty ? "更新了“\(recipe.title)”" : "修改了\(changes.joined(separator: "、"))"
    }

    private static var sampleSnapshot: KitchenSnapshot {
        KitchenSnapshot(
            recipes: SampleData.recipes,
            votedRecipeIDs: [],
            reviews: [],
            pantryItems: SampleData.pantryItems,
            scheduledRecipeIDsByDate: [dateKey(for: .now): Array(SampleData.recipes.prefix(2).map(\.id))],
            revisions: []
        )
    }

    private static func dateKey(for date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}
