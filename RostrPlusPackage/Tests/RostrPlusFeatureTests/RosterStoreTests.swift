// RosterStoreTests.swift
//
// Unit tests for the RosterStore filter + derived accessors. Live
// fetch path is exercised by integration tests against the real
// Supabase project — here we test the client-side logic in isolation
// via the DEBUG-only _testLoad seam.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("RosterStore")
struct RosterStoreTests {

    @Test("Fresh store starts idle with an 'All'-only genres list")
    func freshDefaults() {
        let store = RosterStore()
        #expect(store.genres == ["All"])
        #expect(store.visible.isEmpty)
    }

    @Test("Genre filter narrows visible list")
    func filterByGenre() {
        let store = RosterStore()
        store._testLoad([
            .init(id: UUID(), stage: "A", genre: "Tech House",  city: "Dubai", rating: 5, verified: true),
            .init(id: UUID(), stage: "B", genre: "Afro House",  city: "Riyadh", rating: 5, verified: true),
            .init(id: UUID(), stage: "C", genre: "Tech House",  city: "Doha", rating: 5, verified: true)
        ])

        store.genreFilter = "Tech House"
        #expect(store.visible.count == 2)
        #expect(store.visible.allSatisfy { $0.genre == "Tech House" })
    }

    @Test("Search matches stage, genre, and city (case-insensitive)")
    func searchFields() {
        let store = RosterStore()
        store._testLoad([
            .init(id: UUID(), stage: "DJ Novak",   genre: "Tech House", city: "Dubai",  rating: 5, verified: true),
            .init(id: UUID(), stage: "Orion Kai",  genre: "Afro House", city: "RIYADH", rating: 5, verified: true),
            .init(id: UUID(), stage: "Mirela",     genre: "Deep House", city: "Dubai",  rating: 5, verified: true)
        ])

        store.search = "riyadh"
        #expect(store.visible.count == 1)
        #expect(store.visible.first?.stage == "Orion Kai")

        store.search = "AFRO"
        #expect(store.visible.count == 1)
    }

    @Test("Genres list is unique, sorted, and prefixed with 'All'")
    func genresShape() {
        let store = RosterStore()
        store._testLoad([
            .init(id: UUID(), stage: "A", genre: "Tech House", city: "Dubai", rating: 5, verified: true),
            .init(id: UUID(), stage: "B", genre: "Afro House", city: "Dubai", rating: 5, verified: true),
            .init(id: UUID(), stage: "C", genre: "Tech House", city: "Dubai", rating: 5, verified: true)
        ])

        #expect(store.genres == ["All", "Afro House", "Tech House"])
    }

    @Test("Empty search + 'All' filter returns everything")
    func noFilters() {
        let store = RosterStore()
        let items: [RosterArtist] = (0..<4).map { i in
            .init(id: UUID(), stage: "Artist \(i)", genre: "G\(i)", city: "C", rating: 5, verified: true)
        }
        store._testLoad(items)
        #expect(store.visible.count == items.count)
    }
}
