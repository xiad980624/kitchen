import Foundation

enum RecipeCategory: String, CaseIterable, Identifiable, Hashable, Codable {
    case homestyle = "家常菜"
    case quick = "快手菜"
    case soup = "汤羹"
    case staple = "主食"

    var id: String { rawValue }
}

enum IngredientKind: String, CaseIterable, Hashable, Codable {
    case main = "主菜"
    case side = "辅材"
    case seasoning = "调味料"
}

struct RecipeIngredient: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let quantity: String
    let kind: IngredientKind

    init(id: UUID = UUID(), name: String, quantity: String, kind: IngredientKind) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.kind = kind
    }
}

enum RecipeAvailability: String, Hashable, Codable {
    case ready = "食材齐全"
    case short = "缺少食材"
    case check = "待确认"
}

struct Recipe: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let category: RecipeCategory
    let customCategoryName: String?
    let emoji: String
    let imageData: Data?
    let duration: Int
    let rating: Double
    let reviewCount: Int
    let voteCount: Int
    let availability: RecipeAvailability
    let ingredients: [RecipeIngredient]
    let steps: [String]

    init(
        id: UUID = UUID(),
        title: String,
        category: RecipeCategory,
        customCategoryName: String? = nil,
        emoji: String,
        imageData: Data? = nil,
        duration: Int,
        rating: Double,
        reviewCount: Int,
        voteCount: Int,
        availability: RecipeAvailability,
        ingredients: [RecipeIngredient],
        steps: [String]
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.customCategoryName = customCategoryName
        self.emoji = emoji
        self.imageData = imageData
        self.duration = duration
        self.rating = rating
        self.reviewCount = reviewCount
        self.voteCount = voteCount
        self.availability = availability
        self.ingredients = ingredients
        self.steps = steps
    }

    func ingredients(for kind: IngredientKind) -> [RecipeIngredient] {
        ingredients.filter { $0.kind == kind }
    }

    var categoryName: String {
        customCategoryName ?? category.rawValue
    }
}

struct PantryItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let emoji: String
    let category: String
    let quantity: String
    let expiryHint: String?

    init(id: UUID = UUID(), name: String, emoji: String, category: String, quantity: String, expiryHint: String? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.quantity = quantity
        self.expiryHint = expiryHint
    }
}

struct ShoppingItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    var isChecked: Bool

    init(id: UUID = UUID(), name: String, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
    }
}

struct ShoppingListEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let isManual: Bool
    let isChecked: Bool
}

enum MealPeriod: String, CaseIterable, Identifiable, Hashable, Codable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"

    var id: String { rawValue }

    var defaultTimeMinutes: Int {
        switch self {
        case .breakfast: 8 * 60
        case .lunch: 12 * 60
        case .dinner: 18 * 60
        }
    }
}

struct ScheduledMeal: Identifiable, Hashable, Codable {
    let id: UUID
    let recipeID: UUID
    var period: MealPeriod
    var timeMinutes: Int
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        recipeID: UUID,
        period: MealPeriod,
        timeMinutes: Int? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.recipeID = recipeID
        self.period = period
        self.timeMinutes = timeMinutes ?? period.defaultTimeMinutes
        self.sortOrder = sortOrder
    }

    var timeLabel: String {
        String(format: "%02d:%02d", timeMinutes / 60, timeMinutes % 60)
    }
}

struct RecipeReview: Identifiable, Hashable, Codable {
    let id: UUID
    let recipeID: UUID
    let rating: Int
    let comment: String
    let updatedAt: Date

    init(id: UUID = UUID(), recipeID: UUID, rating: Int, comment: String, updatedAt: Date = .now) {
        self.id = id
        self.recipeID = recipeID
        self.rating = rating
        self.comment = comment
        self.updatedAt = updatedAt
    }
}

struct RecipeRevision: Identifiable, Hashable, Codable {
    let id: UUID
    let recipeID: UUID
    let version: Int
    let summary: String
    let previousRecipe: Recipe?
    let recipe: Recipe
    let editedAt: Date

    init(
        id: UUID = UUID(),
        recipeID: UUID,
        version: Int,
        summary: String,
        previousRecipe: Recipe?,
        recipe: Recipe,
        editedAt: Date = .now
    ) {
        self.id = id
        self.recipeID = recipeID
        self.version = version
        self.summary = summary
        self.previousRecipe = previousRecipe
        self.recipe = recipe
        self.editedAt = editedAt
    }
}
