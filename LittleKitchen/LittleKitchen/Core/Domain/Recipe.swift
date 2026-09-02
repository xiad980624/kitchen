import Foundation

enum RecipeCategory: String, CaseIterable, Identifiable, Hashable {
    case homestyle = "家常菜"
    case quick = "快手菜"
    case soup = "汤羹"
    case staple = "主食"

    var id: String { rawValue }
}

enum IngredientKind: String, CaseIterable, Hashable {
    case main = "主菜"
    case side = "辅材"
    case seasoning = "调味料"
}

struct RecipeIngredient: Identifiable, Hashable {
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

enum RecipeAvailability: String, Hashable {
    case ready = "食材齐全"
    case short = "缺少食材"
    case check = "待确认"
}

struct Recipe: Identifiable, Hashable {
    let id: UUID
    let title: String
    let category: RecipeCategory
    let emoji: String
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
        emoji: String,
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
        self.emoji = emoji
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
}

struct PantryItem: Identifiable, Hashable {
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
