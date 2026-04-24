// MockDataTests.swift
//
// Keeps the mock arrays sane while Wave 2 runs off them. Once Supabase
// DTOs replace the mock source in later waves, these become snapshot
// tests rather than shape guards.

import Testing
@testable import RostrPlusFeature

@Suite("MockData")
struct MockDataTests {

    @Test("Every artist has a unique id")
    func uniqueArtistIDs() {
        let ids = MockData.artists.map(\.id)
        #expect(ids.count == Set(ids).count, "Duplicate artist ids")
    }

    @Test("Bookings have non-empty venue + artist + fee")
    func bookingsWellFormed() {
        for b in MockData.upcoming + MockData.past {
            #expect(!b.venue.isEmpty)
            #expect(!b.artist.isEmpty)
            #expect(!b.fee.isEmpty)
        }
    }

    @Test("Payments total 4 rows with mixed statuses")
    func paymentsShape() {
        #expect(MockData.payments.count == 4)
        let statuses = Set(MockData.payments.map(\.status))
        #expect(statuses.contains(.paid))
        #expect(statuses.contains(.pending))
        #expect(statuses.contains(.scheduled))
    }

    @Test("Thread messages alternate sides")
    func threadAlternates() {
        let messages = MockData.threadMessages
        #expect(messages.count >= 4, "Preview needs enough messages to show both sides")
        #expect(messages.contains(where: \.isMine))
        #expect(messages.contains(where: { !$0.isMine }))
    }

    @Test("Exactly one timeline event is active at a time")
    func timelineActiveCount() {
        let actives = MockData.bookingTimeline.filter(\.isActive)
        #expect(actives.count == 1, "Timeline should highlight one current step")
    }

    @Test("Incoming artist requests have fees + dates populated")
    func incomingShape() {
        #expect(!MockData.incomingRequests.isEmpty)
        for r in MockData.incomingRequests {
            #expect(!r.fee.isEmpty)
            #expect(!r.date.isEmpty)
        }
    }

    @Test("Past performances cover multiple cities")
    func pastPerfCities() {
        let cities = Set(MockData.pastPerformances.map(\.city))
        #expect(cities.count >= 2, "EPK should demonstrate multi-city touring")
    }

    @Test("Press quotes are non-empty + attributed")
    func pressQuotesShape() {
        for q in MockData.pressQuotes {
            #expect(!q.quote.isEmpty)
            #expect(!q.outlet.isEmpty)
        }
    }
}
