import Foundation
import SwiftData

struct KitchenSnapshot: Codable {
    let recipes: [Recipe]
    let votedRecipeIDs: [UUID]
    let reviews: [RecipeReview]
    let pantryItems: [PantryItem]
    let scheduledRecipeIDsByDate: [String: [UUID]]
    let revisions: [RecipeRevision]

    init(
        recipes: [Recipe],
        votedRecipeIDs: [UUID],
        reviews: [RecipeReview],
        pantryItems: [PantryItem],
        scheduledRecipeIDsByDate: [String: [UUID]],
        revisions: [RecipeRevision] = []
    ) {
        self.recipes = recipes
        self.votedRecipeIDs = votedRecipeIDs
        self.reviews = reviews
        self.pantryItems = pantryItems
        self.scheduledRecipeIDsByDate = scheduledRecipeIDsByDate
        self.revisions = revisions
    }

    private enum CodingKeys: String, CodingKey {
        case recipes
        case votedRecipeIDs
        case reviews
        case pantryItems
        case scheduledRecipeIDsByDate
        case revisions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipes = try container.decode([Recipe].self, forKey: .recipes)
        votedRecipeIDs = try container.decode([UUID].self, forKey: .votedRecipeIDs)
        reviews = try container.decode([RecipeReview].self, forKey: .reviews)
        pantryItems = try container.decode([PantryItem].self, forKey: .pantryItems)
        scheduledRecipeIDsByDate = try container.decode([String: [UUID]].self, forKey: .scheduledRecipeIDsByDate)
        revisions = try container.decodeIfPresent([RecipeRevision].self, forKey: .revisions) ?? []
    }
}

@MainActor
protocol KitchenSnapshotPersisting {
    func load() -> KitchenSnapshot?
    func save(_ snapshot: KitchenSnapshot)
}

@Model
final class KitchenSnapshotRecord {
    @Attribute(.unique) var identifier: String
    var payload: Data
    var updatedAt: Date

    init(identifier: String = "current", payload: Data, updatedAt: Date = .now) {
        self.identifier = identifier
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@MainActor
final class SwiftDataKitchenSnapshotPersistence: KitchenSnapshotPersisting {
    private let container: ModelContainer
    private let context: ModelContext

    init(isStoredInMemoryOnly: Bool = false) throws {
        let configuration = ModelConfiguration("LittleKitchen", isStoredInMemoryOnly: isStoredInMemoryOnly)
        container = try ModelContainer(for: KitchenSnapshotRecord.self, configurations: configuration)
        context = ModelContext(container)
    }

    func load() -> KitchenSnapshot? {
        let descriptor = FetchDescriptor<KitchenSnapshotRecord>()
        guard let record = try? context.fetch(descriptor).first else { return nil }
        return try? JSONDecoder().decode(KitchenSnapshot.self, from: record.payload)
    }

    func save(_ snapshot: KitchenSnapshot) {
        guard let payload = try? JSONEncoder().encode(snapshot) else { return }

        let descriptor = FetchDescriptor<KitchenSnapshotRecord>()
        if let record = try? context.fetch(descriptor).first {
            record.payload = payload
            record.updatedAt = .now
        } else {
            context.insert(KitchenSnapshotRecord(payload: payload))
        }
        try? context.save()
    }
}

@MainActor
final class InMemoryKitchenSnapshotPersistence: KitchenSnapshotPersisting {
    private var snapshot: KitchenSnapshot?

    func load() -> KitchenSnapshot? {
        snapshot
    }

    func save(_ snapshot: KitchenSnapshot) {
        self.snapshot = snapshot
    }
}

@MainActor
final class UserDefaultsKitchenSnapshotPersistence: KitchenSnapshotPersisting {
    private let defaults: UserDefaults
    private let key = "littleKitchen.swiftDataFallbackSnapshot"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> KitchenSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(KitchenSnapshot.self, from: data)
    }

    func save(_ snapshot: KitchenSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}

enum KitchenSnapshotStorage {
    @MainActor
    static func live() -> any KitchenSnapshotPersisting {
        if let persistence = try? SwiftDataKitchenSnapshotPersistence() {
            return persistence
        }
        return UserDefaultsKitchenSnapshotPersistence()
    }

    @MainActor
    static func inMemory() -> any KitchenSnapshotPersisting {
        if let persistence = try? SwiftDataKitchenSnapshotPersistence(isStoredInMemoryOnly: true) {
            return persistence
        }
        return InMemoryKitchenSnapshotPersistence()
    }
}

enum LegacyKitchenSnapshotLoader {
    private static let recipesKey = "littleKitchen.localRecipes"
    private static let votesKey = "littleKitchen.votedRecipeIDs"
    private static let reviewsKey = "littleKitchen.recipeReviews"
    private static let pantryKey = "littleKitchen.pantryItems"
    private static let mealPlanKey = "littleKitchen.mealPlan"

    static func load(from defaults: UserDefaults?) -> KitchenSnapshot? {
        guard let defaults, hasLegacyData(in: defaults) else { return nil }

        return KitchenSnapshot(
            recipes: decode([Recipe].self, key: recipesKey, defaults: defaults) ?? SampleData.recipes,
            votedRecipeIDs: decode([UUID].self, key: votesKey, defaults: defaults) ?? [],
            reviews: decode([RecipeReview].self, key: reviewsKey, defaults: defaults) ?? [],
            pantryItems: decode([PantryItem].self, key: pantryKey, defaults: defaults) ?? SampleData.pantryItems,
            scheduledRecipeIDsByDate: decode([String: [UUID]].self, key: mealPlanKey, defaults: defaults) ?? defaultSchedule,
            revisions: []
        )
    }

    private static var defaultSchedule: [String: [UUID]] {
        [Date.now.formatted(.iso8601.year().month().day()): Array(SampleData.recipes.prefix(2).map(\.id))]
    }

    private static func hasLegacyData(in defaults: UserDefaults) -> Bool {
        [recipesKey, votesKey, reviewsKey, pantryKey, mealPlanKey].contains { defaults.data(forKey: $0) != nil }
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
