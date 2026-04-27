// Wave56StoreTests.swift
//
// Unit tests for PushStore + ProfileStore avatar extension. Live APNs +
// Supabase write paths are integration-only — these tests cover the
// state transitions reachable via the DEBUG seam.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("PushStore")
struct PushStoreTests {

    @Test("Fresh store is notDetermined with no token")
    func freshDefaults() {
        let store = PushStore()
        #expect(store.authorization == .notDetermined)
        #expect(store.lastRegisteredToken == nil)
    }

    @Test("_testSet sets both authorization and token")
    func seedState() {
        let store = PushStore()
        store._testSet(authorization: .authorized, token: "deadbeef")
        #expect(store.authorization == .authorized)
        #expect(store.lastRegisteredToken == "deadbeef")
    }

    @Test("register(rawTokenData:) hex-encodes the bytes into lastRegisteredToken")
    func hexEncoding() async {
        let store = PushStore()
        let bytes: [UInt8] = [0xde, 0xad, 0xbe, 0xef, 0x00, 0xff]
        await store.register(rawTokenData: Data(bytes), for: UUID())
        #expect(store.lastRegisteredToken == "deadbeef00ff")
    }

    @Test("tokenReceivedNotification name stays stable across releases")
    func notificationNameStable() {
        // Downstream AppDelegates post against this literal — it is
        // effectively part of the package's public API.
        #expect(PushStore.tokenReceivedNotification.rawValue == "rostr.push.tokenReceived")
    }
}

@MainActor
@Suite("ProfileStore — avatar")
struct ProfileStoreAvatarTests {

    private func dto(avatar: String? = nil) -> ProfileDTO {
        ProfileDTO(
            id: UUID(),
            email: "alex@example.com",
            displayName: "Alex",
            role: "artist",
            avatarURL: avatar,
            phone: nil,
            company: nil,
            bio: nil,
            city: nil
        )
    }

    // FIXME: same rollback issue as Wave54StoreTests.optimisticBioUpdate.
    // updateAvatarURL flips the optimistic state but rolls back on a
    // failed network call, which is what we get without a live session
    // in tests. Disabled until we inject a mock client.
    @Test("updateAvatarURL optimistically flips the loaded state",
          .disabled("Needs injectable client — currently rolls back on real-network failure"))
    func optimisticAvatarFlip() async {
        let store = ProfileStore()
        let seed = dto(avatar: nil)
        store._testLoad(seed)
        await store.updateAvatarURL("https://cdn.rostrplus.io/avatar.jpg", userID: seed.id)
        #expect(store.current?.avatarURL == "https://cdn.rostrplus.io/avatar.jpg")
    }

    @Test("updateAvatarURL preserves every other column")
    func preservesOtherColumns() async {
        let store = ProfileStore()
        let seed = ProfileDTO(
            id: UUID(),
            email: "alex@example.com",
            displayName: "Alex",
            role: "artist",
            avatarURL: nil,
            phone: "+971",
            company: "Beyond",
            bio: "Big bio",
            city: "Dubai"
        )
        store._testLoad(seed)
        await store.updateAvatarURL("https://new.example.com/a.jpg", userID: seed.id)
        #expect(store.current?.displayName == "Alex")
        #expect(store.current?.phone == "+971")
        #expect(store.current?.company == "Beyond")
        #expect(store.current?.bio == "Big bio")
        #expect(store.current?.city == "Dubai")
    }
}
