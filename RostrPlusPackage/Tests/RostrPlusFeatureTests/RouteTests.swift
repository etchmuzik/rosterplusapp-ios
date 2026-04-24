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
}
