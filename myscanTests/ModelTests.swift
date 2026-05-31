//
//  ModelTests.swift
//  myscanTests
//
//  Created by Esma El Hajoui on 31/05/2026.
//

import XCTest
@testable import myscan

@MainActor
final class ModelTests: XCTestCase {
    func testScanConfigurationDefaultsAreUsable() {
        let config = ScanConfiguration()

        XCTAssertEqual(config.targetPorts, [80, 443, 22])
        XCTAssertEqual(config.timeoutSeconds, 0.5)
        XCTAssertEqual(config.maxConcurrency, 32)
        XCTAssertTrue(config.filterOpenOnly)
        XCTAssertEqual(config.startHost, 1)
        XCTAssertEqual(config.endHost, 254)
        XCTAssertEqual(config.saveBehavior, .auto)
        XCTAssertTrue(config.enableRetry)
        XCTAssertFalse(config.scanUIBottom)
    }

    func testAppStateDefaultsToHomeAndCanSelectScan() {
        let appState = AppState()

        XCTAssertEqual(appState.selectedTab, .home)

        appState.selectedTab = .scan

        XCTAssertEqual(appState.selectedTab, .scan)
    }
}
