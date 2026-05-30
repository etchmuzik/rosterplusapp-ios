// NotificationPrefsTests.swift
//
// Pins the cross-client parity contract for profiles.notification_prefs:
//   1. Decoder is lenient — full / partial / null JSONB all decode, and
//      a missing key defaults to `true` (matches web settings.html:409).
//   2. ProfileStore.updateNotificationPrefs flips state optimistically
//      and rolls back to server truth when the writer throws.
//
// The decoder is the subtle part: a synthesised Codable init would THROW
// on a missing key and fail the whole ProfileDTO decode, blacking out
// the Settings screen for legacy rows. These tests guard that.

import Testing
import Foundation
@testable import RostrPlusFeature

@Suite("NotificationPrefs — decode parity")
struct NotificationPrefsDecodeTests {

    private func decode(_ json: String) throws -> NotificationPrefs {
        try JSONDecoder().decode(NotificationPrefs.self, from: Data(json.utf8))
    }

    @Test("Full object round-trips every key verbatim")
    func fullObject() throws {
        let p = try decode("""
        {"email":true,"bookings":false,"messages":true,"contracts":false,"payouts":true}
        """)
        #expect(p.email == true)
        #expect(p.bookings == false)
        #expect(p.messages == true)
        #expect(p.contracts == false)
        #expect(p.payouts == true)
    }

    @Test("Missing keys default to true (opt-out parity with web)")
    func partialObjectDefaultsTrue() throws {
        // Only `bookings` is present and false — every other key absent.
        let p = try decode(#"{"bookings":false}"#)
        #expect(p.bookings == false)
        #expect(p.email == true)
        #expect(p.messages == true)
        #expect(p.contracts == true)
        #expect(p.payouts == true)
    }

    @Test("Explicit JSON null on a key reads as true, not a decode error")
    func nullKeyDefaultsTrue() throws {
        let p = try decode(#"{"email":null,"bookings":false}"#)
        #expect(p.email == true)
        #expect(p.bookings == false)
    }

    @Test("Empty object decodes to all-on")
    func emptyObject() throws {
        let p = try decode("{}")
        #expect(p == .defaultAllOn)
    }

    @Test("Encode emits all five keys for the dispatch side to read")
    func encodeAllFiveKeys() throws {
        let data = try JSONEncoder().encode(NotificationPrefs.defaultAllOn)
        let obj = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(Set(obj.keys) == ["email", "bookings", "messages", "contracts", "payouts"])
    }
}

@Suite("ProfileDTO — notification_prefs column")
struct ProfileDTONotificationPrefsTests {

    @Test("Null column decodes to nil, prefs accessor falls back to all-on")
    func nullColumnFallsBack() throws {
        let json = """
        {"id":"\(UUID().uuidString)","email":"a@b.com","display_name":"A","role":"artist",
         "avatar_url":null,"phone":null,"company":null,"bio":null,"city":null,
         "notification_prefs":null}
        """
        let dto = try JSONDecoder().decode(ProfileDTO.self, from: Data(json.utf8))
        #expect(dto.notificationPrefs == nil)
        #expect(dto.prefs == .defaultAllOn)
    }

    @Test("Absent column (legacy select) decodes to nil, prefs is all-on")
    func absentColumnFallsBack() throws {
        let json = """
        {"id":"\(UUID().uuidString)","email":"a@b.com","display_name":"A","role":"artist",
         "avatar_url":null,"phone":null,"company":null,"bio":null,"city":null}
        """
        let dto = try JSONDecoder().decode(ProfileDTO.self, from: Data(json.utf8))
        #expect(dto.notificationPrefs == nil)
        #expect(dto.prefs.email == true)
    }
}

@MainActor
@Suite("ProfileStore — updateNotificationPrefs")
struct ProfileStoreNotificationPrefsTests {

    private func seed(_ prefs: NotificationPrefs? = nil) -> ProfileDTO {
        ProfileDTO(
            id: UUID(),
            email: "alex@example.com",
            displayName: "Alex",
            role: "artist",
            avatarURL: nil,
            phone: nil,
            company: nil,
            bio: nil,
            city: nil,
            notificationPrefs: prefs
        )
    }

    @Test("Optimistically flips the loaded prefs on success")
    func optimisticFlip() async {
        let store = ProfileStore(writer: NoopProfileWriter())
        let dto = seed(.defaultAllOn)
        store._testLoad(dto)

        var next = NotificationPrefs.defaultAllOn
        next.email = false
        await store.updateNotificationPrefs(next, userID: dto.id)

        #expect(store.current?.prefs.email == false)
        #expect(store.current?.prefs.bookings == true)
        #expect(store.lastError == nil)
    }

    @Test("Rolls back to server truth when the writer throws")
    func rollbackOnFailure() async {
        let store = ProfileStore(writer: FailingProfileWriter())
        let dto = seed(.defaultAllOn)
        store._testLoad(dto)

        var next = NotificationPrefs.defaultAllOn
        next.bookings = false
        await store.updateNotificationPrefs(next, userID: dto.id)

        // Optimistic flip undone — back to the all-on seed.
        #expect(store.current?.prefs.bookings == true)
        #expect(store.lastError != nil)
    }

    @Test("Preserves every other profile column while patching prefs")
    func preservesOtherColumns() async {
        let store = ProfileStore(writer: NoopProfileWriter())
        let dto = ProfileDTO(
            id: UUID(),
            email: "alex@example.com",
            displayName: "Alex",
            role: "artist",
            avatarURL: nil,
            phone: "+971",
            company: "Beyond",
            bio: "Big bio",
            city: "Dubai",
            notificationPrefs: .defaultAllOn
        )
        store._testLoad(dto)

        var next = NotificationPrefs.defaultAllOn
        next.payouts = false
        await store.updateNotificationPrefs(next, userID: dto.id)

        #expect(store.current?.phone == "+971")
        #expect(store.current?.company == "Beyond")
        #expect(store.current?.bio == "Big bio")
        #expect(store.current?.city == "Dubai")
        #expect(store.current?.prefs.payouts == false)
    }

    @Test("No-op when profile isn't loaded yet")
    func guardsUnloaded() async {
        let store = ProfileStore(writer: NoopProfileWriter())
        await store.updateNotificationPrefs(.defaultAllOn, userID: UUID())
        #expect(store.current == nil)
        #expect(store.lastError != nil)
    }
}
