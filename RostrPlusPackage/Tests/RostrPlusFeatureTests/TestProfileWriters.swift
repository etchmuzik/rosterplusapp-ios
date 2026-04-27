// TestProfileWriters.swift
//
// Two trivial ProfileWriter impls for store unit tests:
//   • NoopProfileWriter    — simulates a 200 OK; the optimistic-update
//                            branch survives.
//   • FailingProfileWriter — throws every time, exercising the rollback
//                            + lastError path.
//
// Real network calls would land in a 401 (no session) which the catch
// block treats as a hard failure and rolls back. Injecting these
// writers lets us cover both branches deterministically.

import Foundation
@testable import RostrPlusFeature

struct NoopProfileWriter: ProfileWriter {
    func patchProfile<Patch: Encodable & Sendable>(
        _ patch: Patch, userID: UUID
    ) async throws {
        // Simulate the round-trip without doing anything.
    }
}

struct FailingProfileWriter: ProfileWriter {
    struct StubError: Error, LocalizedError {
        var errorDescription: String? { "Stubbed write failure" }
    }

    func patchProfile<Patch: Encodable & Sendable>(
        _ patch: Patch, userID: UUID
    ) async throws {
        throw StubError()
    }
}
