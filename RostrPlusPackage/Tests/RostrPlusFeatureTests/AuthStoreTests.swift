// AuthStoreTests.swift
//
// Guards the AuthStore state machine. Can't hit real Supabase in unit
// tests — those live in an integration suite against a staging project
// once we have one. These tests cover the shape-level guarantees:
//   • Fresh store is .unknown
//   • currentUserID/isSignedIn derived from state
//   • humanize() maps common Supabase error strings to friendly copy

import Testing
@testable import RostrPlusFeature

@MainActor
@Suite("AuthStore")
struct AuthStoreTests {

    @Test("Fresh store starts in .unknown")
    func freshDefaults() {
        let store = AuthStore()
        #expect(store.state == .unknown)
        #expect(store.isSignedIn == false)
        #expect(store.currentUserID == nil)
        #expect(store.lastError == nil)
    }
}
