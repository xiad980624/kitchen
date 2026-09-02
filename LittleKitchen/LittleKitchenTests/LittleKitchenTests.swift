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
}
