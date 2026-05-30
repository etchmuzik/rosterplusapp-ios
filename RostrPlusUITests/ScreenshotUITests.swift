// ScreenshotUITests.swift
//
// Captures App Store marketing screenshots from the real, running app
// using curated demo data (see ScreenshotSeed in the package). No live
// Supabase, no real users' data — the app is launched with
// `-RostrScreenshotMode 1`, which forces a fake signed-in session and
// seeds every store with Gulf-authentic demo content.
//
// Each screen gets its own fresh launch (optionally deep-linked via
// `-RostrScreenshotRoute <path>`) so captures are independent and a
// failure on one doesn't lose the rest. Screenshots are attached to the
// test result bundle (.keepAlways) AND copied to /tmp/rostr-shots for
// easy collection.
//
// Run:
//   xcodebuild test -project RostrPlus.xcodeproj -scheme RostrPlus \
//     -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
//     -only-testing:RostrPlusUITests/ScreenshotUITests
//
// Then collect the PNGs from /tmp/rostr-shots (or from the .xcresult).

import XCTest

@MainActor
final class ScreenshotUITests: XCTestCase {

    // Stable IDs mirrored from ScreenshotSeed (kept in sync by hand —
    // the test target can't import the package's internal constants).
    private let artistNovak = "A0000001-0000-4000-8000-000000000001"
    private let contractID  = "C0000001-0000-4000-8000-000000000001"
    private let bookingID   = "B0000001-0000-4000-8000-000000000001"

    private let shotsDir = "/tmp/rostr-shots"

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(
            atPath: shotsDir, withIntermediateDirectories: true
        )
    }

    /// Launch the app in screenshot mode, optionally deep-linked to a
    /// specific route path (Route.parse format, e.g. "contracts/<id>").
    private func launch(route: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var args = [
            "-rostr.onboardCompleted", "YES",
            "-RostrScreenshotMode", "1",
        ]
        if let route {
            args += ["-RostrScreenshotRoute", route]
        }
        app.launchArguments = args
        app.launch()
        return app
    }

    /// Capture, attach to the result bundle, and copy to /tmp/rostr-shots.
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also persist the PNG to disk for easy collection.
        let url = URL(fileURLWithPath: shotsDir).appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
    }

    /// Wait for any text to appear (the screen has composed), then a beat
    /// for glass/animation to settle before the capture.
    private func settle(_ app: XCUIApplication, timeout: TimeInterval = 20) {
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: timeout)
        // Small settle for the liquid-glass blur + any entrance animation.
        Thread.sleep(forTimeInterval: 1.2)
    }

    /// Switch tabs reliably: wait for the tab button to be hittable
    /// (the tab bar composes a frame after first render), then tap. A
    /// bare .tap() on a not-yet-hittable element silently no-ops, which
    /// is why an early tap can leave you on Home.
    private func tapTab(_ app: XCUIApplication, _ label: String) {
        let tab = app.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 25), "\(label) tab should exist")
        // Poll for hittability rather than tapping immediately.
        let deadline = Date().addingTimeInterval(8)
        while !tab.isHittable && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
        }
        tab.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: — The six App Store frames

    func test01Directory() {
        let app = launch()
        // Promoter lands on Home; switch to the Roster (directory) tab.
        tapTab(app, "Roster")
        // Confirm we actually left Home: the roster grid shows artist
        // names that aren't on Home's "up next" (e.g. SIRENE / SAMI ROUX).
        _ = app.staticTexts["SIRENE"].waitForExistence(timeout: 8)
        settle(app)
        capture(app, "01-directory")
    }

    func test02Home() {
        let app = launch()
        settle(app)
        capture(app, "02-home")
    }

    func test03ArtistDetail() {
        // Deep-link straight to DJ NOVAK's artist page.
        let app = launch(route: "artists/\(artistNovak)")
        settle(app)
        capture(app, "03-artist-detail")
    }

    func test04EPK() {
        // DJ NOVAK's press kit / EPK.
        let app = launch(route: "epks/\(artistNovak)")
        settle(app)
        capture(app, "04-epk")
    }

    func test05Bookings() {
        let app = launch()
        tapTab(app, "Bookings")
        settle(app)
        capture(app, "05-bookings")
    }

    func test06Contract() {
        // Deep-link to the signed Cavalli Club contract. NB: the
        // .contract route param is treated as a BOOKING id by
        // ContractView (it fetches forBookingID), so pass the booking id.
        let app = launch(route: "contracts/\(bookingID)")
        settle(app)
        capture(app, "06-contract")
    }

    func test07Inbox() {
        let app = launch()
        tapTab(app, "Inbox")
        settle(app)
        capture(app, "07-inbox")
    }

    func test08Thread() {
        // Open the booking detail (which surfaces the thread) for the
        // seeded booking, then the message thread.
        let app = launch(route: "threads/\(bookingID)")
        settle(app)
        capture(app, "08-thread")
    }

    func test09Notifications() {
        let app = launch(route: "notifications")
        settle(app)
        capture(app, "09-notifications")
    }
}
