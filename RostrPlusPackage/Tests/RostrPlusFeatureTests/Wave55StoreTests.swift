// Wave55StoreTests.swift
//
// Unit tests for AvailabilityCheckStore. The live RPC path is
// integration-only — here we exercise the cache + key behaviour via
// the DEBUG test seam.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("AvailabilityCheckStore")
struct AvailabilityCheckStoreTests {

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test("Fresh store returns nil for every key")
    func freshDefaults() {
        let store = AvailabilityCheckStore()
        #expect(store.result(for: UUID(), date: Date()) == nil)
        #expect(store.isChecking(for: UUID(), date: Date()) == false)
    }

    @Test("_testSet seeds a result keyed by (artistID, date)")
    func testSetSeedsCache() {
        let store = AvailabilityCheckStore()
        let id = UUID()
        let day = makeDate(2026, 6, 15)
        store._testSet(artistID: id, date: day, available: false, reason: "Artist blocked this date")
        let result = store.result(for: id, date: day)
        #expect(result?.available == false)
        #expect(result?.reason == "Artist blocked this date")
    }

    @Test("Keys are scoped by (artistID, date) — different days don't collide")
    func keyScoping() {
        let store = AvailabilityCheckStore()
        let id = UUID()
        let jun15 = makeDate(2026, 6, 15)
        let jun16 = makeDate(2026, 6, 16)
        store._testSet(artistID: id, date: jun15, available: false, reason: "Blocked")
        store._testSet(artistID: id, date: jun16, available: true)
        #expect(store.result(for: id, date: jun15)?.available == false)
        #expect(store.result(for: id, date: jun16)?.available == true)
    }

    @Test("Keys are scoped by artistID — different artists don't collide")
    func artistScoping() {
        let store = AvailabilityCheckStore()
        let a = UUID()
        let b = UUID()
        let day = makeDate(2026, 7, 1)
        store._testSet(artistID: a, date: day, available: false, reason: "Booked")
        store._testSet(artistID: b, date: day, available: true)
        #expect(store.result(for: a, date: day)?.available == false)
        #expect(store.result(for: b, date: day)?.available == true)
    }
}
