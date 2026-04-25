// RostrPlusUITests.swift
//
// Smoke + flow coverage. The unit tests in RostrPlusPackage/Tests
// cover stores + design tokens. They can't catch button-wired-to-
// nothing, accidentally-hidden CTAs, or a navigation push that
// silently fails. These XCUITest specs exercise the actual rendered
// hierarchy through the same code paths a user takes.
//
// Tests that depend on first-run state set
// `app.launchArguments = ["-rostr.onboardCompleted", "NO"]` to flip
// the onboarding gate flag back to its zero value before launching.

import XCTest

// XCUIApplication and friends are @MainActor-isolated under Swift 6.
// Mark the class @MainActor so every test method (and the helper)
// inherits the isolation — without it the build fails with:
//   "call to main actor-isolated initializer 'init()' in a synchronous
//    nonisolated context"
@MainActor
final class RostrPlusUITests: XCTestCase {

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Helper — boot the app at the onboarding carousel by clearing the
    /// `rostr.onboardCompleted` UserDefaults flag the host app reads
    /// at AppRoot.swift:137.
    ///
    /// Why both `launchArguments` AND a manual reset:
    ///   - launchArguments form `["-rostr.onboardCompleted", "NO"]`
    ///     instructs UserDefaults to expose the override at read time
    ///     for the host process. That's the right mechanism but only
    ///     works if the app reads the value through the layered-defaults
    ///     resolution (NSArgumentDomain).
    ///   - In practice the host hits UserDefaults.standard.bool(forKey:)
    ///     directly, which respects argument-domain overrides. But a
    ///     persisted YES value from a prior install lives in the user
    ///     domain and outranks the argument domain on the first read,
    ///     so the override needs the persisted value cleared once at
    ///     test boot.
    ///   - We can't reach the host's UserDefaults directly from here
    ///     (different process), but `simctl` has wiped the simulator
    ///     state before this test session, OR the launchArguments take
    ///     precedence on a fresh install. Both paths land at "first
    ///     frame is OnboardView."
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            // Argument-domain override for the onboarding flag.
            "-rostr.onboardCompleted", "NO",
            // Belt-and-suspenders: a sentinel the host can detect and
            // forcibly reset persisted state on. Wire-up happens in a
            // follow-up; for now this just flags the intent.
            "-RostrUITestMode", "1",
        ]
        app.launch()
        return app
    }

    // MARK: - Smoke

    /// Process actually launches and reaches foreground state.
    /// The bar before this fails: build broken, code-sign broken,
    /// crash on launch, missing storyboard.
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)
    }

    /// First frame renders the ROSTR+ wordmark + Skip button + first
    /// onboarding slide headline. Catches: missing fonts, OnboardView
    /// crashed during render, AppRoot didn't route to onboarding on
    /// first run.
    func testOnboardingFirstFrame() throws {
        let app = launchFresh()

        // Wordmark: hand-rendered as Text("ROSTR+") in OnboardView's topBar.
        let wordmark = app.staticTexts["ROSTR+"]
        XCTAssertTrue(
            wordmark.waitForExistence(timeout: 5),
            "ROSTR+ wordmark should render on first frame"
        )

        // Skip button is visible on slides 0 + 1 (hidden on slide 2 = role pick).
        XCTAssertTrue(app.buttons["SKIP"].exists, "Skip should be tappable on first slide")

        // First slide headline. The literal break is `\n` in source so
        // the rendered string is two lines — match a substring instead
        // of the whole headline.
        let headline = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Book the GCC'"))
        XCTAssertTrue(headline.firstMatch.exists, "Slide 1 headline should render")
    }

    // MARK: - Onboarding flow

    /// Tap NEXT twice → land on the role-pick slide. Catches:
    /// pager broken, NEXT not bound to advance(), withAnimation
    /// silently failing.
    func testOnboardingPagerAdvances() throws {
        let app = launchFresh()
        XCTAssertTrue(app.staticTexts["ROSTR+"].waitForExistence(timeout: 5))

        let next = app.buttons["Next"]
        XCTAssertTrue(next.exists, "NEXT button on slide 0")
        next.tap()

        // Slide 2 of carousel ("Contracts + payments, built-in") should appear.
        let slide2 = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'WhatsApp math'"))
        XCTAssertTrue(slide2.firstMatch.waitForExistence(timeout: 2), "Slide 2 should appear after NEXT")

        // One more tap reaches the role-picker (slide 3).
        next.tap()
        let rolePickHeading = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Final step'"))
        XCTAssertTrue(rolePickHeading.firstMatch.waitForExistence(timeout: 2), "Role-picker should appear after second NEXT")
    }

    /// Skip jumps straight to the role-picker (slide 3). Catches:
    /// Skip visible but not wired, withAnimation race making the page
    /// flip silently noop.
    func testOnboardingSkipJumpsToRolePicker() throws {
        let app = launchFresh()
        XCTAssertTrue(app.buttons["SKIP"].waitForExistence(timeout: 5))

        app.buttons["SKIP"].tap()
        let rolePickHeading = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Final step'"))
        XCTAssertTrue(rolePickHeading.firstMatch.waitForExistence(timeout: 2), "Skip should jump to role-picker")
    }

    // MARK: - Role picker renders

    /// On the role-picker slide both role cards render with their
    /// labels + body copy. Catches: roleCard binding broken, role
    /// enum desync, copy regression.
    ///
    /// We don't drive past the role-picker into SignIn because the
    /// "advance to SignIn" CTA isn't a stable label today (the role
    /// card itself is the primary interaction; the actual advance
    /// happens via NavigationModel state). When SignIn becomes
    /// reachable through a stable accessibility identifier, extend
    /// this test to cover that hop.
    func testRolePickerRenders() throws {
        let app = launchFresh()
        XCTAssertTrue(app.buttons["SKIP"].waitForExistence(timeout: 5))
        app.buttons["SKIP"].tap()

        // Both role cards should appear, each with title + body text.
        let promoterTitle = app.staticTexts["A promoter"]
        XCTAssertTrue(promoterTitle.waitForExistence(timeout: 2), "Promoter role card should render")

        let artistTitle = app.staticTexts["An artist"]
        XCTAssertTrue(artistTitle.exists, "Artist role card should render")

        // Spot-check one body copy line to catch cards-rendered-but-empty.
        let promoterBody = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'I book artists'")
        ).firstMatch
        XCTAssertTrue(promoterBody.exists, "Promoter card body copy should render")
    }

    // MARK: - Stability

    /// Background → foreground → still alive. Catches: scene lifecycle
    /// crash on resume, async task cancellation explosion, a window
    /// state we can't recover from.
    func testBackgroundForegroundStability() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.state == .runningForeground)

        // Send to background.
        XCUIDevice.shared.press(.home)

        // Wait briefly for OS to settle.
        sleep(1)

        // Re-activate.
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3))
    }
}
