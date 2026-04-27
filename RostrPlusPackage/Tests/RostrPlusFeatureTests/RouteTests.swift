// RouteTests.swift
//
// Guards the Route enum's id stability. Route.id is used as the
// SwiftUI .id() for transitions; if two distinct routes collapse to
// the same string, transitions break silently. Worth pinning.

import Testing
@testable import RostrPlusFeature

@Suite("Route")
struct RouteTests {

    @Test("Payload-carrying routes encode the payload in id")
    func payloadsInID() {
        #expect(Route.artist(artistID: "abc").id == "artist:abc")
        #expect(Route.bookingDetail(bookingID: "xyz").id == "bookingDetail:xyz")
        #expect(Route.invoice(bookingID: "q1").id == "invoice:q1")
    }

    @Test("Payload-less routes keep a stable single-token id")
    func simpleIDs() {
        #expect(Route.notifications.id == "notifications")
        #expect(Route.claim.id == "claim")
        #expect(Route.availability.id == "availability")
        #expect(Route.profileEdit.id == "profileEdit")
        #expect(Route.signIn.id == "signIn")
        #expect(Route.calendar.id == "calendar")
        #expect(Route.analytics.id == "analytics")
        #expect(Route.onboard.id == "onboard")
    }

    @Test("Two routes with different payloads are distinct")
    func distinctPayloads() {
        let a = Route.artist(artistID: "1")
        let b = Route.artist(artistID: "2")
        #expect(a != b)
        #expect(a.id != b.id)
    }

    @Test("Same route pushed twice is hashable-equal")
    func reflexiveEquality() {
        let x = Route.thread(threadID: "t1")
        let y = Route.thread(threadID: "t1")
        #expect(x == y)
        #expect(x.hashValue == y.hashValue)
    }

    @Test("allCases covers every enum case exactly once")
    func allCasesCoversEnum() {
        // If a Route case is added without updating CaseIterable.allCases,
        // tests that depend on it (back-button audit, deep-link parser
        // round-trip) silently miss the new case. Pinning the count
        // forces a manual review on every Route addition.
        #expect(Route.allCases.count == 16)
        let ids = Route.allCases.map(\.id)
        #expect(Set(ids).count == ids.count, "Route.allCases must be unique")
    }
}

// MARK: - Route.parse(href:)

@Suite("Route.parse(href:)")
struct RouteParseTests {

    @Test("Maps server hrefs to bookingDetail / thread / contract / invoice / review")
    func serverHrefShapes() {
        let id = "550e8400-e29b-41d4-a716-446655440000"
        #expect(Route.parse(href: "/bookings/\(id)") == .bookingDetail(bookingID: id))
        #expect(Route.parse(href: "/threads/\(id)") == .thread(threadID: id))
        #expect(Route.parse(href: "/contracts/\(id)") == .contract(contractID: id))
        #expect(Route.parse(href: "/invoices/\(id)") == .invoice(bookingID: id))
        #expect(Route.parse(href: "/reviews/\(id)") == .review(bookingID: id))
    }

    @Test("Tolerates leading slash, full URL, and bare path")
    func toleratesShapes() {
        let id = "abc-123"
        #expect(Route.parse(href: "bookings/\(id)") == .bookingDetail(bookingID: id))
        #expect(Route.parse(href: "/bookings/\(id)") == .bookingDetail(bookingID: id))
        #expect(Route.parse(href: "https://rosterplus.io/bookings/\(id)") == .bookingDetail(bookingID: id))
        #expect(Route.parse(href: "rostr://bookings/\(id)") == .bookingDetail(bookingID: id))
    }

    @Test("Maps artist, EPK, notifications shorthand")
    func artistAndEpkPaths() {
        let id = "x"
        #expect(Route.parse(href: "/artists/\(id)") == .artist(artistID: id))
        #expect(Route.parse(href: "/epks/\(id)") == .epk(artistID: id))
        #expect(Route.parse(href: "/epk/\(id)") == .epk(artistID: id))
        #expect(Route.parse(href: "/notifications") == .notifications)
    }

    @Test("Returns nil for unrecognised paths and missing ids")
    func rejectsBadInput() {
        #expect(Route.parse(href: "") == nil)
        #expect(Route.parse(href: "/") == nil)
        #expect(Route.parse(href: "/unknown/123") == nil)
        #expect(Route.parse(href: "/bookings") == nil) // missing id
        #expect(Route.parse(href: "/bookings/") == nil)
    }
}
