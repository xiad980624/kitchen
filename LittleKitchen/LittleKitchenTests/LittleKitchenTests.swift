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
    func testCompletingMenuPersistsAndCanBeReopened() {
        let persistence = KitchenSnapshotStorage.inMemory()
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)
        let recipe = store.recipes[2]
        store.schedule(recipe)

        store.completeMenu()

        XCTAssertTrue(store.isMenuCompleted())
        XCTAssertTrue(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).isMenuCompleted())

        store.reopenMenu()

        XCTAssertFalse(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).isMenuCompleted())
    }

    @MainActor
    func testSchedulingNewRecipeReopensCompletedMenu() {
        let store = LocalKitchenStore(persistence: KitchenSnapshotStorage.inMemory(), legacyDefaults: nil)
        store.completeMenu()
        XCTAssertTrue(store.isMenuCompleted())

        let recipe = try! XCTUnwrap(store.recipes.first { !store.recipes(for: .now).contains($0) })
        store.schedule(recipe)

        XCTAssertFalse(store.isMenuCompleted())
    }

    @MainActor
    func testAddingMissingIngredientUpdatesShoppingList() {
        let store = LocalKitchenStore(persistence: KitchenSnapshotStorage.inMemory(), legacyDefaults: nil)
        let missingIngredient = try! XCTUnwrap(store.shoppingList.first)

        store.addPantryItem(name: missingIngredient)

        XCTAssertFalse(store.shoppingList.contains(missingIngredient))
    }

    @MainActor
    func testEditingAndRemovingPantryItemPersists() throws {
        let persistence = KitchenSnapshotStorage.inMemory()
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)
        let item = try XCTUnwrap(store.pantryItems.first)

        XCTAssertTrue(
            store.updatePantryItem(
                item,
                name: "新鲜鸡蛋",
                category: "肉蛋奶",
                quantity: "6 个",
                expiryHint: "本周吃完"
            )
        )

        let updatedItem = try XCTUnwrap(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).pantryItems.first)
        XCTAssertEqual(updatedItem.name, "新鲜鸡蛋")
        XCTAssertEqual(updatedItem.quantity, "6 个")
        XCTAssertEqual(updatedItem.expiryHint, "本周吃完")

        store.removePantryItem(updatedItem)

        XCTAssertFalse(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).pantryItems.contains(where: { $0.id == item.id }))
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

    @MainActor
    func testEditingRecipeCreatesPersistedRevisionWithBothSnapshots() throws {
        let persistence = KitchenSnapshotStorage.inMemory()
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)
        let originalRecipe = try XCTUnwrap(store.recipes.first)
        let updatedRecipe = Recipe(
            id: originalRecipe.id,
            title: originalRecipe.title,
            category: originalRecipe.category,
            emoji: originalRecipe.emoji,
            duration: originalRecipe.duration + 5,
            rating: originalRecipe.rating,
            reviewCount: originalRecipe.reviewCount,
            voteCount: originalRecipe.voteCount,
            availability: originalRecipe.availability,
            ingredients: originalRecipe.ingredients,
            steps: originalRecipe.steps
        )

        store.save(recipe: updatedRecipe)

        let revision = try XCTUnwrap(store.revisions(for: updatedRecipe).first)
        XCTAssertEqual(revision.version, 1)
        XCTAssertEqual(revision.summary, "修改了烹饪时长")
        XCTAssertEqual(revision.previousRecipe, originalRecipe)
        XCTAssertEqual(revision.recipe, updatedRecipe)
        XCTAssertEqual(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).revisions(for: updatedRecipe).first, revision)
    }

    @MainActor
    func testOlderSnapshotWithoutRevisionsCanStillDecode() throws {
        let snapshot = KitchenSnapshot(
            recipes: SampleData.recipes,
            votedRecipeIDs: [],
            reviews: [],
            pantryItems: SampleData.pantryItems,
            scheduledRecipeIDsByDate: [:]
        )
        let encodedSnapshot = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedSnapshot) as? [String: Any])
        object.removeValue(forKey: "revisions")
        object.removeValue(forKey: "completedRecipeIDsByDate")
        let olderSnapshot = try JSONSerialization.data(withJSONObject: object)

        let decodedSnapshot = try JSONDecoder().decode(KitchenSnapshot.self, from: olderSnapshot)
        XCTAssertTrue(decodedSnapshot.revisions.isEmpty)
        XCTAssertTrue(decodedSnapshot.completedRecipeIDsByDate.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LittleKitchenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
