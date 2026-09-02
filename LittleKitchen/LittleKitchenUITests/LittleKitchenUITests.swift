//
//  LittleKitchenUITests.swift
//  LittleKitchenUITests
//
//  Created by 夏冬 on 2026/9/2.
//

import XCTest

final class LittleKitchenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesOnMenu() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["今天吃什么？"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["菜单"].exists)
    }
}
