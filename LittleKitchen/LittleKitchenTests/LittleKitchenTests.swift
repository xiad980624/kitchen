//
//  LittleKitchenTests.swift
//  LittleKitchenTests
//
//  Created by 夏冬 on 2026/9/2.
//

import XCTest
@testable import LittleKitchen

final class LittleKitchenTests: XCTestCase {
    func testIngredientsAreGroupedByTheirKind() {
        let recipe = SampleData.recipes[0]

        XCTAssertEqual(recipe.ingredients(for: .main).map(\.name), ["鸡腿肉"])
        XCTAssertEqual(recipe.ingredients(for: .side).map(\.name), ["花生", "黄瓜"])
        XCTAssertEqual(recipe.ingredients(for: .seasoning).map(\.name), ["干辣椒", "生抽"])
    }

    func testSampleRecipesHaveUniqueIDs() {
        let ids = Set(SampleData.recipes.map(\.id))

        XCTAssertEqual(ids.count, SampleData.recipes.count)
    }

    @MainActor
    func testVotePersistsInSwiftDataCache() {
        let persistence = KitchenSnapshotStorage.inMemory()
        XCTAssertTrue(persistence is SwiftDataKitchenSnapshotPersistence)
        let recipe = LocalKitchenStore(persistence: persistence, legacyDefaults: nil).recipes[0]

        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)
        store.toggleVote(for: recipe)

        XCTAssertTrue(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).isVoted(recipe))
    }

    @MainActor
    func testReviewPersistsInSwiftDataCache() {
        let persistence = KitchenSnapshotStorage.inMemory()
        let recipe = LocalKitchenStore(persistence: persistence, legacyDefaults: nil).recipes[0]
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)

        store.saveReview(recipeID: recipe.id, rating: 5, comment: "做得很好吃")

        let savedReview = LocalKitchenStore(persistence: persistence, legacyDefaults: nil).review(for: recipe)
        XCTAssertEqual(savedReview?.rating, 5)
        XCTAssertEqual(savedReview?.comment, "做得很好吃")
    }

    @MainActor
    func testSchedulingRecipePersistsForToday() {
        let persistence = KitchenSnapshotStorage.inMemory()
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)
        let recipe = store.recipes[2]

        store.schedule(recipe)

        XCTAssertTrue(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).recipes(for: .now).contains(recipe))
    }

    @MainActor
    func testAddingMissingIngredientUpdatesShoppingList() {
        let store = LocalKitchenStore(persistence: KitchenSnapshotStorage.inMemory(), legacyDefaults: nil)
        let missingIngredient = try! XCTUnwrap(store.shoppingList.first)

        store.addPantryItem(name: missingIngredient)

        XCTAssertFalse(store.shoppingList.contains(missingIngredient))
    }

    @MainActor
    func testLegacyUserDefaultsDataMigratesIntoLocalStore() throws {
        let defaults = makeDefaults()
        let legacyRecipe = Recipe(
            title: "迁移测试菜谱",
            category: .quick,
            emoji: "🥘",
            duration: 15,
            rating: 0,
            reviewCount: 0,
            voteCount: 0,
            availability: .ready,
            ingredients: [],
            steps: []
        )
        let legacyRecipes = [legacyRecipe]
        defaults.set(try JSONEncoder().encode(legacyRecipes), forKey: "littleKitchen.localRecipes")

        let persistence = KitchenSnapshotStorage.inMemory()
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: defaults)
        let reloadedStore = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)

        XCTAssertEqual(store.recipes, legacyRecipes)
        XCTAssertEqual(reloadedStore.recipes, legacyRecipes)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LittleKitchenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
