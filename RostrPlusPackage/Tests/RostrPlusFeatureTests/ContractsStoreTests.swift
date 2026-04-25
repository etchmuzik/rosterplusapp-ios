// ContractsStoreTests.swift
//
// Unit tests for the optimistic state transitions on ContractsStore.
// The live PostgREST PATCH path is integration-only — we exercise the
// merge/value-type logic via the DEBUG _testLoad seam.

import Testing
import Foundation
@testable import RostrPlusFeature

@MainActor
@Suite("ContractsStore — sign + send")
struct ContractsStoreTests {

    private func row(
        promoterSigned: Bool = false,
        artistSigned: Bool = false,
        status: ContractRow.Status = .sent
    ) -> ContractRow {
        ContractRow(
            id: UUID(),
            bookingID: UUID(),
            title: "Performance Contract",
            content: "",
            status: status,
            promoterSigned: promoterSigned,
            artistSigned: artistSigned,
            promoterSignedAt: nil,
            artistSignedAt: nil,
            signedAt: nil,
            createdAt: Date()
        )
    }

    @Test("Fresh store is idle")
    func freshDefaults() {
        let store = ContractsStore()
        if case .idle = store.state {
            // pass
        } else {
            Issue.record("expected idle, got \(store.state)")
        }
    }

    @Test("Promoter signing flips promoterSigned + stamps timestamp")
    func promoterSign() async {
        let store = ContractsStore()
        let r = row()
        store._testLoad(r)
        await store.sign(contractID: r.id, as: .promoter)
        let cached = store.cache[r.id]
        #expect(cached?.promoterSigned == true)
        #expect(cached?.artistSigned == false)
        #expect(cached?.promoterSignedAt != nil)
        #expect(cached?.status == .sent)  // status stays since artist not yet signed
    }

    @Test("Artist signing flips artistSigned + stamps timestamp")
    func artistSign() async {
        let store = ContractsStore()
        let r = row()
        store._testLoad(r)
        await store.sign(contractID: r.id, as: .artist)
        let cached = store.cache[r.id]
        #expect(cached?.artistSigned == true)
        #expect(cached?.promoterSigned == false)
        #expect(cached?.artistSignedAt != nil)
    }

    @Test("Counterparty signing flips status to .signed + stamps signed_at")
    func bothSignedTransition() async {
        let store = ContractsStore()
        let r = row(promoterSigned: true)  // promoter already signed
        store._testLoad(r)
        await store.sign(contractID: r.id, as: .artist)
        let cached = store.cache[r.id]
        #expect(cached?.promoterSigned == true)
        #expect(cached?.artistSigned == true)
        #expect(cached?.status == .signed)
        #expect(cached?.signedAt != nil)
    }

    @Test("Promoter sending a draft contract flips status to sent")
    func sendDraft() async {
        let store = ContractsStore()
        let r = row(status: .draft)
        store._testLoad(r)
        await store.send(contractID: r.id)
        let cached = store.cache[r.id]
        #expect(cached?.status == .sent)
    }

    @Test("Sending a non-draft contract is a no-op")
    func sendNonDraftNoop() async {
        let store = ContractsStore()
        let r = row(status: .signed)
        store._testLoad(r)
        await store.send(contractID: r.id)
        let cached = store.cache[r.id]
        #expect(cached?.status == .signed)
    }

    @Test("Sign with no cached contract surfaces an error")
    func signMissingContract() async {
        let store = ContractsStore()
        await store.sign(contractID: UUID(), as: .promoter)
        #expect(store.lastError != nil)
    }
}
