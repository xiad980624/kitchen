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
    func testVotePersistsInLocalCache() {
        let defaults = makeDefaults()
        let recipe = LocalKitchenStore(defaults: defaults).recipes[0]

        let store = LocalKitchenStore(defaults: defaults)
        store.toggleVote(for: recipe)

        XCTAssertTrue(LocalKitchenStore(defaults: defaults).isVoted(recipe))
    }

    @MainActor
    func testReviewPersistsInLocalCache() {
        let defaults = makeDefaults()
        let recipe = LocalKitchenStore(defaults: defaults).recipes[0]
        let store = LocalKitchenStore(defaults: defaults)

        store.saveReview(recipeID: recipe.id, rating: 5, comment: "做得很好吃")

        let savedReview = LocalKitchenStore(defaults: defaults).review(for: recipe)
        XCTAssertEqual(savedReview?.rating, 5)
        XCTAssertEqual(savedReview?.comment, "做得很好吃")
    }

    @MainActor
    func testSchedulingRecipePersistsForToday() {
        let defaults = makeDefaults()
        let store = LocalKitchenStore(defaults: defaults)
        let recipe = store.recipes[2]

        store.schedule(recipe)

        XCTAssertTrue(LocalKitchenStore(defaults: defaults).recipes(for: .now).contains(recipe))
    }

    @MainActor
    func testAddingMissingIngredientUpdatesShoppingList() {
        let store = LocalKitchenStore(defaults: makeDefaults())
        let missingIngredient = try! XCTUnwrap(store.shoppingList.first)

        store.addPantryItem(name: missingIngredient)

        XCTAssertFalse(store.shoppingList.contains(missingIngredient))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LittleKitchenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
