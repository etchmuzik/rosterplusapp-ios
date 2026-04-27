// Wave51StoreTests.swift
//
// Unit tests for the stores added in Wave 5.1 (InboxStore, NotificationsStore,
// PaymentsStore, AnalyticsStore). Each exercises the client-side derivation
// logic via the DEBUG-only `_testLoad` seams — the live network paths are
// covered by integration tests.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("InboxStore")
struct InboxStoreTests {

    @Test("Fresh store starts empty")
    func freshDefaults() {
        let store = InboxStore()
        #expect(store.threads.isEmpty)
        #expect(store.unreadCount == 0)
    }

    @Test("Threads group messages by (booking_id, counterparty)")
    func threadsGrouping() {
        let store = InboxStore()
        let me = UUID()
        let mirela = UUID()
        let novak = UUID()
        let booking1 = UUID()
        let booking2 = UUID()

        let msgs: [MessageDTO] = [
            .init(id: UUID(), senderID: mirela, receiverID: me, bookingID: booking1,
                  content: "Sending the set list.", read: false,
                  createdAt: Date().addingTimeInterval(-60)),
            .init(id: UUID(), senderID: me, receiverID: mirela, bookingID: booking1,
                  content: "Thanks.", read: true,
                  createdAt: Date().addingTimeInterval(-120)),
            .init(id: UUID(), senderID: novak, receiverID: me, bookingID: booking2,
                  content: "Push soundcheck?", read: false,
                  createdAt: Date().addingTimeInterval(-30))
        ]
        store._testLoad(
            userID: me,
            messages: msgs,
            names: [mirela: "MIRELA", novak: "DJ NOVAK"]
        )

        #expect(store.threads.count == 2)
        // Most-recent first.
        #expect(store.threads.first?.counterpartyName == "DJ NOVAK")
    }

    @Test("unreadCount counts only messages addressed to me")
    func unreadScoping() {
        let store = InboxStore()
        let me = UUID()
        let other = UUID()
        let booking = UUID()

        store._testLoad(
            userID: me,
            messages: [
                // Unread, to me — counts.
                .init(id: UUID(), senderID: other, receiverID: me, bookingID: booking,
                      content: "Hi", read: false, createdAt: Date()),
                // Unread, from me — does NOT count.
                .init(id: UUID(), senderID: me, receiverID: other, bookingID: booking,
                      content: "Draft", read: false, createdAt: Date())
            ],
            names: [other: "Other"]
        )
        #expect(store.unreadCount == 1)
    }
}

@MainActor
@Suite("NotificationsStore")
struct NotificationsStoreTests {

    @Test("Fresh store yields empty unread + read partitions")
    func freshDefaults() {
        let store = NotificationsStore()
        #expect(store.unread.isEmpty)
        #expect(store.read.isEmpty)
        #expect(store.unreadCount == 0)
    }

    @Test("Partition splits by `read` flag")
    func partition() {
        let store = NotificationsStore()
        store._testLoad([
            NotificationRow(id: UUID(), kind: .booking, title: "A", body: "",
                            createdAt: Date(), read: false, href: nil),
            NotificationRow(id: UUID(), kind: .message, title: "B", body: "",
                            createdAt: Date(), read: true,  href: nil),
            NotificationRow(id: UUID(), kind: .review,  title: "C", body: "",
                            createdAt: Date(), read: false, href: nil)
        ])
        #expect(store.unread.count == 2)
        #expect(store.read.count == 1)
        #expect(store.unreadCount == 2)
    }

    @Test("markRead flips the in-memory row immediately")
    func optimisticMarkRead() {
        let store = NotificationsStore()
        let id = UUID()
        store._testLoad([
            NotificationRow(id: id, kind: .booking, title: "A", body: "",
                            createdAt: Date(), read: false, href: nil)
        ])
        #expect(store.unreadCount == 1)
        store.markRead(id)
        #expect(store.unreadCount == 0)
        #expect(store.read.count == 1)
    }
}

@MainActor
@Suite("PaymentsStore")
struct PaymentsStoreTests {

    private func row(
        status: PaymentRow.Status,
        amount: Decimal = 10_000,
        ccy: String = "AED",
        paidAt: Date? = nil
    ) -> PaymentRow {
        PaymentRow(
            id: UUID(), artistName: "A", eventLabel: "E",
            amount: amount, currency: ccy,
            amountFormatted: "\(ccy) \(NSDecimalNumber(decimal: amount).intValue)",
            status: status, eventDate: Date(), paidAt: paidAt
        )
    }

    @Test("Fresh store is empty in every bucket")
    func freshDefaults() {
        let store = PaymentsStore()
        #expect(store.paid.isEmpty)
        #expect(store.pending.isEmpty)
        #expect(store.scheduled.isEmpty)
    }

    @Test("Buckets partition by PaymentRow.Status")
    func partition() {
        let store = PaymentsStore()
        store._testLoad([
            row(status: .paid),
            row(status: .pending),
            row(status: .pending),
            row(status: .scheduled)
        ])
        #expect(store.paid.count == 1)
        #expect(store.pending.count == 2)
        #expect(store.scheduled.count == 1)
    }

    @Test("monthTotal sums only this month's payments")
    func monthTotal() {
        let store = PaymentsStore()
        let now = Date()
        let lastMonth = Calendar.current.date(byAdding: .month, value: -2, to: now)!
        store._testLoad([
            row(status: .paid, amount: 10_000, paidAt: now),
            row(status: .paid, amount: 20_000, paidAt: now),
            row(status: .paid, amount: 50_000, paidAt: lastMonth)
        ])
        #expect(store.monthTotal == 30_000)
    }
}

@MainActor
@Suite("AnalyticsStore")
struct AnalyticsStoreTests {

    private func booking(artist: String, fee: Decimal, offsetDays: Int, ccy: String = "AED") -> BookingRow {
        BookingRow(
            id: UUID(), eventName: "E", artistName: artist, venueName: "V",
            eventDate: Date().addingTimeInterval(Double(offsetDays) * 86_400),
            status: "confirmed",
            feeFormatted: "\(ccy) \(NSDecimalNumber(decimal: fee).intValue)", currency: ccy, fee: fee
        )
    }

    @Test("Empty bookings yield empty derivations")
    func emptyDefaults() {
        let bookings = BookingsStore()
        bookings._testLoad(upcoming: [], past: [])
        let analytics = AnalyticsStore(bookings: bookings)
        #expect(analytics.months.count == 12)         // always 12 slots, all zero
        #expect(analytics.genreShares.isEmpty)
        #expect(analytics.topArtists.isEmpty)
    }

    @Test("topArtists ranks by booking count, ties broken by total fee")
    func topArtistsRanking() {
        let bookings = BookingsStore()
        bookings._testLoad(
            upcoming: [
                booking(artist: "DJ NOVAK", fee: 10_000, offsetDays: 1),
                booking(artist: "MIRELA",  fee: 20_000, offsetDays: 2),
                booking(artist: "DJ NOVAK", fee: 30_000, offsetDays: 3)
            ],
            past: [
                booking(artist: "MIRELA",  fee: 8_000, offsetDays: -30)
            ]
        )
        let analytics = AnalyticsStore(bookings: bookings)
        let top = analytics.topArtists
        #expect(top.count == 2)
        #expect(top.first?.stage == "DJ NOVAK")
        #expect(top.first?.bookings == 2)
    }

    @Test("genreShares sum to approximately 1.0")
    func genreSharesSum() {
        let bookings = BookingsStore()
        bookings._testLoad(
            upcoming: [
                booking(artist: "A", fee: 10_000, offsetDays: 1),
                booking(artist: "B", fee: 10_000, offsetDays: 2),
                booking(artist: "C", fee: 10_000, offsetDays: 3)
            ],
            past: []
        )
        let analytics = AnalyticsStore(bookings: bookings)
        let total = analytics.genreShares.reduce(0) { $0 + $1.share }
        #expect(abs(total - 1.0) < 0.001)
    }

    @Test("months buckets sum into the month of the booking")
    func monthsBucketing() {
        let bookings = BookingsStore()
        bookings._testLoad(
            upcoming: [booking(artist: "A", fee: 42_000, offsetDays: 0)],
            past: []
        )
        let analytics = AnalyticsStore(bookings: bookings)
        // Current month is the last slot in `months`.
        #expect(analytics.months.last?.value == 42.0)
    }
}
