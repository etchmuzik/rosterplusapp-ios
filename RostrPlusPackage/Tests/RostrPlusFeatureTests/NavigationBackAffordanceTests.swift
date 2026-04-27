// NavigationBackAffordanceTests.swift
//
// Guard against the original "CalendarView has no back button" bug.
// The app uses a custom router (no NavigationStack), so every
// detail-route view must render its own back affordance — either via
// the shared NavHeader or a hand-rolled chevron-tile that calls
// nav.pop().
//
// This test walks every Route in CaseIterable and asserts the matching
// source file on disk contains a back-affordance signal. It's a
// structural lint, not a runtime check, but catches the exact class of
// drift that produced the original report.

import Testing
import Foundation
@testable import RostrPlusFeature

@Suite("Navigation back affordance")
struct NavigationBackAffordanceTests {

    /// Maps every Route case to the view source file expected to render
    /// it, relative to the package's Sources directory. signIn /
    /// onboard are presented as the unauth root surface, not pushed
    /// onto the detail stack — they're allowed to skip the back
    /// affordance and dismiss via state-machine transitions instead.
    private static let routeToSourcePath: [(Route, String)] = [
        (.artist(artistID: "x"),         "Features/Artist/ArtistView.swift"),
        (.booking(artistID: "x"),        "Features/Booking/BookingView.swift"),
        (.bookingDetail(bookingID: "x"), "Features/BookingDetail/BookingDetailView.swift"),
        (.thread(threadID: "x"),         "Features/Thread/ThreadView.swift"),
        (.epk(artistID: "x"),            "Features/EPK/EPKView.swift"),
        (.contract(contractID: "x"),     "Features/Contract/ContractView.swift"),
        (.notifications,                 "Features/Notifications/NotificationsView.swift"),
        (.review(bookingID: "x"),        "Features/Review/ReviewView.swift"),
        (.claim,                         "Features/Claim/ClaimView.swift"),
        (.availability,                  "Features/Availability/AvailabilityView.swift"),
        (.profileEdit,                   "Features/ProfileEdit/ProfileEditView.swift"),
        (.invoice(bookingID: "x"),       "Features/Invoice/InvoiceView.swift"),
        (.calendar,                      "Features/Calendar/CalendarView.swift"),
        (.analytics,                     "Features/Analytics/AnalyticsView.swift")
    ]

    /// Resolve the package's Sources/ directory by walking up from this
    /// test file. `#filePath` is `…/Tests/RostrPlusFeatureTests/<file>`,
    /// so two parents up + `Sources` lands us where we need to be.
    private static func sourcesURL(testFile: String = #filePath) -> URL {
        URL(fileURLWithPath: testFile)
            .deletingLastPathComponent()  // RostrPlusFeatureTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // RostrPlusPackage/
            .appendingPathComponent("Sources")
    }

    @Test("CaseIterable covers every detail Route in the affordance map")
    func mapCoversDetailRoutes() {
        // Compare by case-name (the prefix of `id` before any colon),
        // not the full id, because the affordance map uses placeholder
        // payloads ("x") while Route.allCases uses canonical UUIDs.
        let caseName: (Route) -> String = { $0.id.split(separator: ":").first.map(String.init) ?? $0.id }
        // signIn + onboard are intentionally excluded — they're
        // unauth-root surfaces, not pushed details.
        let mapped = Set(Self.routeToSourcePath.map { caseName($0.0) })
        let expected = Set(Route.allCases
            .filter { $0 != .signIn && $0 != .onboard }
            .map(caseName))
        #expect(mapped == expected,
                "Route.allCases changed without updating routeToSourcePath")
    }

    @Test("Every detail Route's view file contains a back affordance")
    func everyDetailViewHasBackAffordance() throws {
        // Walk the full table inside the test rather than via @Test
        // arguments — the parameterised form requires `Route: Sendable
        // & Hashable & Equatable`, which is fine, but tuple arguments
        // hit a Swift Testing macro limitation around tuple Sendable
        // inference. A single test body iterating gives equally clear
        // failure messages.
        for (route, relativePath) in Self.routeToSourcePath {
            let url = Self.sourcesURL().appendingPathComponent(relativePath)
            let text = try String(contentsOf: url, encoding: .utf8)
            // Acceptable patterns:
            //   1. NavHeader(...) { onBack: { nav.pop() } }
            //   2. Hand-rolled chevron/xmark button that calls nav.pop()
            // Both reduce to "the file contains nav.pop()". CalendarView
            // before its 2026-04-27 fix did not — that's the bug this
            // test guards.
            #expect(text.contains("nav.pop()"),
                    "\(relativePath) is reachable as Route.\(route.id) but renders no back affordance — every detail route must call nav.pop()")
        }
    }
}
