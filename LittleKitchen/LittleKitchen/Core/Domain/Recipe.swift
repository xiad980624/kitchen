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
    let stepImageData: [Data?]

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
        steps: [String],
        stepImageData: [Data?] = []
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
        self.stepImageData = stepImageData
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, category, customCategoryName, emoji, imageData, duration, rating, reviewCount, voteCount, availability, ingredients, steps, stepImageData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(RecipeCategory.self, forKey: .category)
        customCategoryName = try container.decodeIfPresent(String.self, forKey: .customCategoryName)
        emoji = try container.decode(String.self, forKey: .emoji)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        duration = try container.decode(Int.self, forKey: .duration)
        rating = try container.decode(Double.self, forKey: .rating)
        reviewCount = try container.decode(Int.self, forKey: .reviewCount)
        voteCount = try container.decode(Int.self, forKey: .voteCount)
        availability = try container.decode(RecipeAvailability.self, forKey: .availability)
        ingredients = try container.decode([RecipeIngredient].self, forKey: .ingredients)
        steps = try container.decode([String].self, forKey: .steps)
        stepImageData = try container.decodeIfPresent([Data?].self, forKey: .stepImageData) ?? []
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
    let automaticQuantity: String?
    let matchStatus: IngredientMatchStatus?
    let sourceRecipeTitles: [String]

    init(
        id: String,
        name: String,
        isManual: Bool,
        isChecked: Bool,
        automaticQuantity: String? = nil,
        matchStatus: IngredientMatchStatus? = nil,
        sourceRecipeTitles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.isManual = isManual
        self.isChecked = isChecked
        self.automaticQuantity = automaticQuantity
        self.matchStatus = matchStatus
        self.sourceRecipeTitles = sourceRecipeTitles
    }
}

enum IngredientMatchStatus: Hashable {
    case ready
    case short
    case missing
    case check
}

struct IngredientStockMatch: Identifiable, Hashable {
    let id: String
    let name: String
    let status: IngredientMatchStatus
    let requiredQuantity: String?
    let availableQuantity: String?
    let shoppingQuantity: String?
    let sourceRecipeTitles: [String]
}

enum IngredientStockMatcher {
    static func matches(recipes: [Recipe], pantryItems: [PantryItem]) -> [IngredientStockMatch] {
        let pantryByName = Dictionary(grouping: pantryItems, by: { normalizedName($0.name) })
            .mapValues { $0[0] }
        let ingredientUses = recipes.flatMap { recipe in
            recipe.ingredients.map { IngredientRecipeUse(recipeTitle: recipe.title, ingredient: $0) }
        }
        let groupedIngredients = Dictionary(grouping: ingredientUses, by: { normalizedName($0.ingredient.name) })

        return groupedIngredients.compactMap { normalizedName, uses in
            guard let name = uses.first?.ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            let ingredients = uses.map(\.ingredient)
            let sourceRecipeTitles = Array(Set(uses.map(\.recipeTitle))).sorted()
            let requirement = aggregatedQuantity(from: ingredients.map(\.quantity))
            let pantryItem = pantryByName[normalizedName]
            let available = pantryItem.flatMap { ParsedIngredientQuantity($0.quantity) }

            if pantryItem == nil {
                return IngredientStockMatch(
                    id: normalizedName,
                    name: name,
                    status: .missing,
                    requiredQuantity: requirement.display,
                    availableQuantity: nil,
                    shoppingQuantity: requirement.display,
                    sourceRecipeTitles: sourceRecipeTitles
                )
            }

            guard let required = requirement.parsed,
                  let available,
                  required.unitKey == available.unitKey else {
                return IngredientStockMatch(
                    id: normalizedName,
                    name: name,
                    status: .check,
                    requiredQuantity: requirement.display,
                    availableQuantity: pantryItem?.quantity,
                    shoppingQuantity: nil,
                    sourceRecipeTitles: sourceRecipeTitles
                )
            }

            if available.value >= required.value {
                return IngredientStockMatch(
                    id: normalizedName,
                    name: name,
                    status: .ready,
                    requiredQuantity: required.display,
                    availableQuantity: available.display,
                    shoppingQuantity: nil,
                    sourceRecipeTitles: sourceRecipeTitles
                )
            }

            let shortage = ParsedIngredientQuantity(value: required.value - available.value, unitKey: required.unitKey)
            return IngredientStockMatch(
                id: normalizedName,
                name: name,
                status: .short,
                requiredQuantity: required.display,
                availableQuantity: available.display,
                shoppingQuantity: shortage.display,
                sourceRecipeTitles: sourceRecipeTitles
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func aggregatedQuantity(from quantities: [String]) -> AggregatedIngredientQuantity {
        let parsed = quantities.compactMap(ParsedIngredientQuantity.init)
        guard parsed.count == quantities.count,
              let first = parsed.first,
              parsed.allSatisfy({ $0.unitKey == first.unitKey }) else {
            let descriptions = quantities
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return AggregatedIngredientQuantity(parsed: nil, display: descriptions.isEmpty ? nil : descriptions.joined(separator: "、"))
        }

        let total = parsed.reduce(0) { $0 + $1.value }
        let totalQuantity = ParsedIngredientQuantity(value: total, unitKey: first.unitKey)
        return AggregatedIngredientQuantity(parsed: totalQuantity, display: totalQuantity.display)
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct IngredientRecipeUse {
    let recipeTitle: String
    let ingredient: RecipeIngredient
}

private struct AggregatedIngredientQuantity {
    let parsed: ParsedIngredientQuantity?
    let display: String?
}

private struct ParsedIngredientQuantity {
    let value: Double
    let unitKey: String

    nonisolated init?( _ rawValue: String) {
        let compact = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        let numberText = String(compact.prefix { $0.isNumber || $0 == "." })
        let unitText = String(compact.dropFirst(numberText.count))
        guard let number = Double(numberText), number >= 0, !unitText.isEmpty,
              let unit = Self.normalizedUnit(for: unitText) else { return nil }
        self.init(value: number * unit.multiplier, unitKey: unit.key)
    }

    nonisolated init(value: Double, unitKey: String) {
        self.value = value
        self.unitKey = unitKey
    }

    nonisolated var display: String {
        "\(Self.formatted(value)) \(Self.displayUnit(for: unitKey))"
    }

    nonisolated private static func normalizedUnit(for unit: String) -> (key: String, multiplier: Double)? {
        switch unit {
        case "g", "克": return ("g", 1)
        case "kg", "公斤", "千克": return ("g", 1_000)
        case "斤": return ("g", 500)
        case "ml", "毫升": return ("ml", 1)
        case "l", "升": return ("ml", 1_000)
        case "个", "只", "根", "片", "瓣", "块", "枚", "把", "包", "袋", "份", "汤匙", "勺", "茶匙": return (unit, 1)
        default: return nil
        }
    }

    nonisolated private static func displayUnit(for key: String) -> String {
        switch key {
        case "g": return "g"
        case "ml": return "ml"
        default: return key
        }
    }

    nonisolated private static func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
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
