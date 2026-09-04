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
    func testShoppingItemsCanBeCheckedAndManualItemsPersist() throws {
        let persistence = KitchenSnapshotStorage.inMemory()
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)
        let automaticItem = try XCTUnwrap(store.shoppingItems.first(where: { !$0.isManual }))

        store.toggleShoppingItem(automaticItem)
        XCTAssertTrue(try XCTUnwrap(store.shoppingItems.first(where: { $0.id == automaticItem.id })).isChecked)

        XCTAssertTrue(store.addShoppingItem(name: "厨房纸"))
        let manualItem = try XCTUnwrap(store.shoppingItems.first(where: { $0.name == "厨房纸" }))
        store.toggleShoppingItem(manualItem)

        let reloadedItems = LocalKitchenStore(persistence: persistence, legacyDefaults: nil).shoppingItems
        XCTAssertTrue(try XCTUnwrap(reloadedItems.first(where: { $0.id == automaticItem.id })).isChecked)
        XCTAssertTrue(try XCTUnwrap(reloadedItems.first(where: { $0.name == "厨房纸" })).isChecked)

        store.removeShoppingItem(manualItem)
        XCTAssertFalse(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).shoppingItems.contains(where: { $0.name == "厨房纸" }))
    }

    @MainActor
    func testMealPlanCanBeReorderedForAnyDate() {
        let store = LocalKitchenStore(persistence: KitchenSnapshotStorage.inMemory(), legacyDefaults: nil)
        let date = Calendar.current.date(byAdding: .day, value: 2, to: .now)!
        let firstRecipe = store.recipes[0]
        let secondRecipe = store.recipes[1]

        store.schedule(firstRecipe, for: date)
        store.schedule(secondRecipe, for: date)
        store.moveScheduledRecipe(secondRecipe, by: -1, for: date)

        XCTAssertEqual(store.recipes(for: date), [secondRecipe, firstRecipe])
    }

    @MainActor
    func testScheduledMealsPersistWithMealPeriodAndTime() throws {
        let persistence = KitchenSnapshotStorage.inMemory()
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)
        let date = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        let breakfastRecipe = store.recipes[0]
        let dinnerRecipe = store.recipes[1]

        XCTAssertTrue(store.schedule(breakfastRecipe, for: date, period: .breakfast, timeMinutes: 450))
        XCTAssertTrue(store.schedule(dinnerRecipe, for: date, period: .dinner, timeMinutes: 1_140))

        let meals = LocalKitchenStore(persistence: persistence, legacyDefaults: nil).scheduledMeals(for: date)
        XCTAssertEqual(meals.map(\.recipeID), [breakfastRecipe.id, dinnerRecipe.id])
        XCTAssertEqual(meals.map(\.period), [.breakfast, .dinner])
        XCTAssertEqual(meals.map(\.timeLabel), ["07:30", "19:00"])
    }

    @MainActor
    func testSchedulingExistingRecipeUpdatesItsMealTime() throws {
        let store = LocalKitchenStore(persistence: KitchenSnapshotStorage.inMemory(), legacyDefaults: nil)
        let date = Calendar.current.date(byAdding: .day, value: 4, to: .now)!
        let recipe = store.recipes[0]

        XCTAssertTrue(store.schedule(recipe, for: date, period: .breakfast, timeMinutes: 480))
        XCTAssertTrue(store.schedule(recipe, for: date, period: .dinner, timeMinutes: 1_140))

        let meal = try XCTUnwrap(store.scheduledMeals(for: date).first)
        XCTAssertEqual(store.scheduledMeals(for: date).count, 1)
        XCTAssertEqual(meal.period, .dinner)
        XCTAssertEqual(meal.timeLabel, "19:00")
    }

    @MainActor
    func testCustomRecipeCategoryAndImagePersist() throws {
        let persistence = KitchenSnapshotStorage.inMemory()
        let store = LocalKitchenStore(persistence: persistence, legacyDefaults: nil)
        let imageData = Data([1, 2, 3, 4])
        let recipe = Recipe(
            title: "深夜拌面",
            category: .homestyle,
            customCategoryName: "宵夜",
            emoji: "🍜",
            imageData: imageData,
            duration: 10,
            rating: 0,
            reviewCount: 0,
            voteCount: 0,
            availability: .check,
            ingredients: [],
            steps: []
        )

        store.save(recipe: recipe)

        let reloadedRecipe = try XCTUnwrap(LocalKitchenStore(persistence: persistence, legacyDefaults: nil).recipe(id: recipe.id))
        XCTAssertEqual(reloadedRecipe.categoryName, "宵夜")
        XCTAssertEqual(reloadedRecipe.imageData, imageData)
        XCTAssertTrue(store.customCategoryNames.contains("宵夜"))
    }

    @MainActor
    func testExistingMealPlanMigratesToDinnerAtDefaultTime() {
        let persistence = KitchenSnapshotStorage.inMemory()
        let recipe = SampleData.recipes[0]
        let date = Date.now
        persistence.save(
            KitchenSnapshot(
                recipes: [recipe],
                votedRecipeIDs: [],
                reviews: [],
                pantryItems: [],
                scheduledRecipeIDsByDate: [date.formatted(.iso8601.year().month().day()): [recipe.id]]
            )
        )

        let meal = LocalKitchenStore(persistence: persistence, legacyDefaults: nil).scheduledMeals(for: date).first

        XCTAssertEqual(meal?.recipeID, recipe.id)
        XCTAssertEqual(meal?.period, .dinner)
        XCTAssertEqual(meal?.timeLabel, "18:00")
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
        object.removeValue(forKey: "scheduledMealsByDate")
        object.removeValue(forKey: "completedRecipeIDsByDate")
        object.removeValue(forKey: "manualShoppingItems")
        object.removeValue(forKey: "checkedAutomaticShoppingItemNames")
        let olderSnapshot = try JSONSerialization.data(withJSONObject: object)

        let decodedSnapshot = try JSONDecoder().decode(KitchenSnapshot.self, from: olderSnapshot)
        XCTAssertTrue(decodedSnapshot.revisions.isEmpty)
        XCTAssertTrue(decodedSnapshot.completedRecipeIDsByDate.isEmpty)
        XCTAssertTrue(decodedSnapshot.scheduledMealsByDate.isEmpty)
        XCTAssertTrue(decodedSnapshot.manualShoppingItems.isEmpty)
        XCTAssertTrue(decodedSnapshot.checkedAutomaticShoppingItemNames.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LittleKitchenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
