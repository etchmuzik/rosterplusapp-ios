// RostrPlusUITests.swift
//
// Smoke-only placeholder. Rich E2E journeys live here once the app
// has a stable UI footprint — for now we just verify launch.

import XCTest

final class RostrPlusUITests: XCTestCase {

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)
    }
}
