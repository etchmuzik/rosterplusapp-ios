// Wave52StoreTests.swift
//
// Exercises the artist earn-loop additions on BookingsStore:
// the `pendingRequests` derived accessor and the optimistic
// `respond(to:with:)` mutation. Live DB writes are not reached —
// the write happens inside a Task whose failure is silently
// swallowed when no Supabase auth is present, so the test just
// asserts the optimistic local state flip.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("BookingsStore — artist earn loop")
struct BookingsStoreEarnLoopTests {

    private func row(
        status: String,
        offsetDays: Double = 3,
        id: UUID = UUID()
    ) -> BookingRow {
        BookingRow(
            id: id,
            eventName: "Event",
            artistName: "DJ Novak",
            venueName: "WHITE Dubai",
            eventDate: Date().addingTimeInterval(offsetDays * 86_400),
            status: status,
            feeFormatted: "AED 28K",
            currency: "AED",
            fee: 28_000
        )
    }

    // MARK: — pendingRequests

    @Test("pendingRequests surfaces inquiry + pending only")
    func filtersInquiryAndPending() {
        let store = BookingsStore()
        store._testLoad(
            upcoming: [
                row(status: "inquiry", offsetDays: 1),
                row(status: "pending", offsetDays: 2),
                row(status: "confirmed", offsetDays: 3),
                row(status: "contracted", offsetDays: 4)
            ],
            past: [
                row(status: "pending", offsetDays: -10),
                row(status: "completed", offsetDays: -20)
            ]
        )

        let requests = store.pendingRequests
        #expect(requests.count == 3)
        #expect(requests.allSatisfy { $0.status == "inquiry" || $0.status == "pending" })
    }

    @Test("pendingRequests is sorted by eventDate ascending")
    func sortedByDate() {
        let store = BookingsStore()
        store._testLoad(
            upcoming: [
                row(status: "pending", offsetDays: 20),
                row(status: "inquiry", offsetDays: 5),
                row(status: "pending", offsetDays: 10)
            ],
            past: []
        )
        let dates = store.pendingRequests.map(\.eventDate)
        #expect(dates == dates.sorted())
    }

    @Test("Fresh store has no pending requests")
    func emptyDefault() {
        let store = BookingsStore()
        #expect(store.pendingRequests.isEmpty)
    }

    // MARK: — respond()

    @Test("respond(.accept) flips an upcoming row's status to confirmed")
    func acceptAtUpcoming() {
        let store = BookingsStore()
        let id = UUID()
        store._testLoad(
            upcoming: [row(status: "pending", id: id)],
            past: []
        )
        #expect(store.pendingRequests.count == 1)

        store.respond(to: id, with: .accept)

        // Optimistic local flip takes effect immediately.
        #expect(store.pendingRequests.isEmpty)
        #expect(store.upcoming.first?.status == "confirmed")
        #expect(store.detailCache[id]?.status == "confirmed")
    }

    @Test("respond(.decline) flips an upcoming row's status to cancelled")
    func declineAtUpcoming() {
        let store = BookingsStore()
        let id = UUID()
        store._testLoad(
            upcoming: [row(status: "inquiry", id: id)],
            past: []
        )
        store.respond(to: id, with: .decline)
        #expect(store.upcoming.first?.status == "cancelled")
        #expect(store.pendingRequests.isEmpty)
    }

    @Test("respond() leaves unrelated rows untouched")
    func responseIsolation() {
        let store = BookingsStore()
        let targetID = UUID()
        let bystanderID = UUID()
        store._testLoad(
            upcoming: [
                row(status: "pending", id: targetID),
                row(status: "pending", id: bystanderID)
            ],
            past: []
        )

        store.respond(to: targetID, with: .accept)

        let bystander = store.upcoming.first { $0.id == bystanderID }
        #expect(bystander?.status == "pending")
    }

    @Test("respond() on a missing id is a no-op")
    func responseOnMissingID() {
        let store = BookingsStore()
        store._testLoad(
            upcoming: [row(status: "pending")],
            past: []
        )
        let before = store.upcoming.map(\.status)
        store.respond(to: UUID(), with: .accept)
        let after = store.upcoming.map(\.status)
        #expect(before == after)
    }
}
