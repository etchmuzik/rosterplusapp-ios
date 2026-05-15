// TestContractWriters.swift
//
// Two trivial ContractWriter impls for ContractsStore unit tests.
// Same shape as TestProfileWriters / TestArtistWriters.

import Foundation
@testable import RostrPlusFeature

struct NoopContractWriter: ContractWriter {
    func patchContract<Patch: Encodable & Sendable>(
        _ patch: Patch, contractID: UUID
    ) async throws {
        // Simulate the round-trip without doing anything.
    }
}

struct FailingContractWriter: ContractWriter {
    struct StubError: Error, LocalizedError {
        var errorDescription: String? { "Stubbed contract write failure" }
    }

    func patchContract<Patch: Encodable & Sendable>(
        _ patch: Patch, contractID: UUID
    ) async throws {
        throw StubError()
    }
}
