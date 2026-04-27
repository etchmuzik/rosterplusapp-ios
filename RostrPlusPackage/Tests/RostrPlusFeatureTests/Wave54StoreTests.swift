// Wave54StoreTests.swift
//
// Unit tests for ProfileStore + ArtistDetailStore mutation surface.
// Live Supabase writes aren't reached — the test seam lets us seed a
// loaded state, then assert the optimistic local value-type merges
// against the expected new shape.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("ProfileStore")
struct ProfileStoreTests {

    private func dto(
        id: UUID = UUID(),
        displayName: String? = "Alex Doe",
        bio: String? = "DJ + producer",
        role: String = "artist"
    ) -> ProfileDTO {
        ProfileDTO(
            id: id,
            email: "alex@example.com",
            displayName: displayName,
            role: role,
            avatarURL: nil,
            phone: nil,
            company: nil,
            bio: bio,
            city: nil
        )
    }

    @Test("Fresh store is idle with no current profile")
    func freshDefaults() {
        let store = ProfileStore()
        #expect(store.current == nil)
    }

    @Test("_testLoad exposes a current profile")
    func loadSeed() {
        let store = ProfileStore()
        let seed = dto(displayName: "Seed")
        store._testLoad(seed)
        #expect(store.current?.displayName == "Seed")
    }

    // FIXME: these two tests assume the optimistic-update branch survives
    // an awaited round-trip, but ProfileStore.update rolls back to the
    // pre-update state on network failure (which is exactly what happens
    // in the test environment — there's no live Supabase auth). They were
    // green only when the test sim had no network and the call hung.
    // Left disabled until ProfileStore takes an injected client we can mock.
    @Test("update(bio:) optimistically patches state.loaded",
          .disabled("Needs injectable client — currently rolls back on real-network failure"))
    func optimisticBioUpdate() async {
        let store = ProfileStore()
        let id = UUID()
        store._testLoad(dto(id: id, displayName: "A", bio: "old"))
        await store.update(userID: id, bio: "new")
        #expect(store.current?.bio == "new")
    }

    @Test("update() leaves untouched fields alone",
          .disabled("Needs injectable client — currently rolls back on real-network failure"))
    func updateIsPartial() async {
        let store = ProfileStore()
        let id = UUID()
        store._testLoad(dto(id: id, displayName: "Alex", bio: "keep"))
        await store.update(userID: id, displayName: "Alexander")
        #expect(store.current?.displayName == "Alexander")
        #expect(store.current?.bio == "keep")
    }
}

@MainActor
@Suite("ArtistDetailStore — self-service writes")
struct ArtistDetailStoreMutationsTests {

    private func detail(
        id: UUID = UUID(),
        stageName: String = "DJ NOVAK",
        genre: String = "Tech House",
        baseFee: Decimal? = 28_000,
        blocked: Set<Date> = []
    ) -> ArtistDetail {
        ArtistDetail(
            id: id,
            stageName: stageName,
            genres: [genre],
            citiesActive: ["Dubai"],
            baseFee: baseFee,
            currency: "AED",
            rating: 4.9,
            totalBookings: 32,
            verified: true,
            epkURL: nil,
            pressQuotes: [],
            pastPerformances: [],
            social: nil,
            blockedDates: blocked
        )
    }

    @Test("updateBlockedDates optimistically updates cache + state")
    func blockedDatesOptimistic() async {
        let store = ArtistDetailStore()
        let id = UUID()
        store._testLoad(detail(id: id))
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        await store.updateBlockedDates([today, tomorrow], for: id)
        #expect(store.cache[id]?.blockedDates == [today, tomorrow])
    }

    @Test("updateBaseFee optimistically updates cache + state")
    func baseFeeOptimistic() async {
        let store = ArtistDetailStore()
        let id = UUID()
        store._testLoad(detail(id: id, baseFee: 20_000))
        await store.updateBaseFee(45_000, for: id)
        #expect(store.cache[id]?.baseFee == 45_000)
    }

    @Test("updateProfileCore rewrites stage name + primary genre + social")
    func profileCoreOptimistic() async {
        let store = ArtistDetailStore()
        let id = UUID()
        store._testLoad(detail(id: id, stageName: "Old", genre: "Deep House"))
        let social = ArtistDTO.SocialLinks(instagram: "@new", soundcloud: nil, spotify: nil)
        await store.updateProfileCore(
            artistID: id,
            stageName: "NEW",
            primaryGenre: "Tech House",
            social: social
        )
        let cached = store.cache[id]
        #expect(cached?.stageName == "NEW")
        #expect(cached?.genres.first == "Tech House")
        #expect(cached?.social?.instagram == "@new")
    }

    @Test("updateProfileCore with nil fields preserves existing values")
    func profileCorePartial() async {
        let store = ArtistDetailStore()
        let id = UUID()
        store._testLoad(detail(id: id, stageName: "Keep", genre: "Keep"))
        await store.updateProfileCore(artistID: id, stageName: nil, primaryGenre: nil, social: nil)
        #expect(store.cache[id]?.stageName == "Keep")
        #expect(store.cache[id]?.genres.first == "Keep")
    }
}
