// InvitationsStoreTests.swift
//
// Local-only validation of InvitationsStore — the live INSERT into
// public.invitations + send-email RPC are exercised by integration
// suites. Here we cover the input-validation guards.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("InvitationsStore")
struct InvitationsStoreTests {

    @Test("Fresh store is idle")
    func freshDefaults() {
        let store = InvitationsStore()
        #expect(store.sendResult == .idle)
        #expect(store.recent.isEmpty)
    }

    @Test("Email without @ surfaces a validation error")
    func emailValidation() async {
        let store = InvitationsStore()
        await store.send(
            email: "not-an-email",
            name: "X",
            role: "artist",
            message: "",
            invitedBy: UUID(),
            inviterName: "Me"
        )
        if case .failed(let m) = store.sendResult {
            #expect(m.contains("valid email"))
        } else {
            Issue.record("expected failed result")
        }
    }

    @Test("Role outside artist|promoter is rejected")
    func roleValidation() async {
        let store = InvitationsStore()
        await store.send(
            email: "a@b.com",
            name: "X",
            role: "junk",
            message: "",
            invitedBy: UUID(),
            inviterName: "Me"
        )
        if case .failed(let m) = store.sendResult {
            #expect(m.contains("artist or promoter"))
        } else {
            Issue.record("expected failed result")
        }
    }

    @Test("reset() returns sendResult to idle")
    func resetClearsState() {
        let store = InvitationsStore()
        store._testSet(result: .sent(email: "x@y.com"))
        store.reset()
        #expect(store.sendResult == .idle)
    }
}
