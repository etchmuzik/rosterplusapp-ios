// BookingsStoreTests.swift
//
// Unit tests for the derived accessors on BookingsStore (upNext, stats,
// upcoming/past partitioning). The live network path is exercised by
// integration tests against the real Supabase project — here we test
// client-side logic in isolation via the DEBUG-only _testLoad seam.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("BookingsStore")
struct BookingsStoreTests {

    // MARK: — Fixtures

    private func row(
        id: UUID = UUID(),
        event: String = "Event",
        artist: String = "Artist",
        venue: String = "Venue",
        date: Date,
        status: String = "confirmed",
        fee: Decimal? = 10_000,
        currency: String = "AED"
    ) -> BookingRow {
        BookingRow(
            id: id,
            eventName: event,
            artistName: artist,
            venueName: venue,
            eventDate: date,
            status: status,
            feeFormatted: "\(currency) \(NSDecimalNumber(decimal: fee ?? 0).intValue)",
            currency: currency,
            fee: fee
        )
    }

    // MARK: — Defaults

    @Test("Fresh store exposes empty upcoming + past + upNext")
    func freshDefaults() {
        let store = BookingsStore()
        #expect(store.upcoming.isEmpty)
        #expect(store.past.isEmpty)
        #expect(store.upNext.isEmpty)
    }

    // MARK: — Partition + upNext

    @Test("upNext returns at most the first three upcoming bookings")
    func upNextCap() {
        let store = BookingsStore()
        let now = Date()
        let future = (1...5).map { i in
            row(date: now.addingTimeInterval(Double(i) * 86_400))
        }
        store._testLoad(upcoming: future, past: [])
        #expect(store.upcoming.count == 5)
        #expect(store.upNext.count == 3)
        // Keeps incoming order (server already orders ascending).
        #expect(store.upNext == Array(future.prefix(3)))
    }

    @Test("Past bookings flow through unchanged")
    func pastPassthrough() {
        let store = BookingsStore()
        let past = [
            row(date: Date().addingTimeInterval(-10 * 86_400), status: "completed"),
            row(date: Date().addingTimeInterval(-20 * 86_400), status: "completed")
        ]
        store._testLoad(upcoming: [], past: past)
        #expect(store.past.count == 2)
        #expect(store.upcoming.isEmpty)
    }

    // MARK: — Detail cache

    @Test("_testLoad warms the detail cache for every row")
    func detailCacheWarmed() {
        let store = BookingsStore()
        let a = row(id: UUID(), date: Date().addingTimeInterval(86_400))
        let b = row(id: UUID(), date: Date().addingTimeInterval(-86_400), status: "completed")
        store._testLoad(upcoming: [a], past: [b])

        #expect(store.detailCache[a.id]?.eventName == a.eventName)
        #expect(store.detailCache[b.id]?.status == "completed")
    }

    // MARK: — Stats

    @Test("stats.upcomingCount reflects upcoming list size")
    func statsUpcomingCount() {
        let store = BookingsStore()
        let future = (1...4).map { i in
            row(date: Date().addingTimeInterval(Double(i) * 86_400))
        }
        store._testLoad(upcoming: future, past: [])
        #expect(store.stats.upcomingCount == 4)
    }

    @Test("stats.pendingCount only counts pending upcoming bookings")
    func statsPendingCount() {
        let store = BookingsStore()
        let now = Date()
        let upcoming = [
            row(date: now.addingTimeInterval(1 * 86_400), status: "confirmed"),
            row(date: now.addingTimeInterval(2 * 86_400), status: "pending"),
            row(date: now.addingTimeInterval(3 * 86_400), status: "pending"),
            row(date: now.addingTimeInterval(4 * 86_400), status: "contracted")
        ]
        store._testLoad(upcoming: upcoming, past: [])
        #expect(store.stats.pendingCount == 2)
    }

    @Test("stats.monthTotal formats using the first row's currency")
    func statsMonthTotalCurrency() {
        let store = BookingsStore()
        let soon = Date().addingTimeInterval(86_400)
        store._testLoad(
            upcoming: [row(date: soon, fee: 28_000, currency: "USD")],
            past: []
        )
        // The format is "<CCY> <value>"; exact K-formatting is internal.
        #expect(store.stats.monthTotal.hasPrefix("USD "))
    }

    @Test("Empty state yields zeros and a fallback currency in stats")
    func statsEmpty() {
        let store = BookingsStore()
        store._testLoad(upcoming: [], past: [])
        #expect(store.stats.upcomingCount == 0)
        #expect(store.stats.pendingCount == 0)
        // Fallback currency is AED when nothing is loaded.
        #expect(store.stats.monthTotal.hasPrefix("AED "))
    }
}
