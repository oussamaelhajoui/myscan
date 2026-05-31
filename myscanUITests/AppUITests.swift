//
//  AppUITests.swift
//  myscanUITests
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import XCTest

final class AppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsDashboardAndTabs() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Scan"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    func testScanTabControlsAreReachableWithoutLayoutSquish() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Scan"].tap()

        XCTAssertTrue(app.navigationBars["Scan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start Scan"].exists)
        XCTAssertTrue(app.buttons["Clear"].exists)
        XCTAssertTrue(app.buttons["Save As"].exists)
        XCTAssertTrue(app.staticTexts["Live Output"].exists)
        XCTAssertTrue(app.staticTexts["Found Hosts"].exists)
    }

    func testSettingsTabShowsPersistenceControls() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Place Scan UI at bottom"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Retry once"].exists)
        XCTAssertTrue(app.staticTexts["Saving"].exists)
    }
}
