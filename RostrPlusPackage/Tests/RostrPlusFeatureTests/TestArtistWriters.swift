// TestArtistWriters.swift
//
// Two trivial ArtistWriter impls for ArtistDetailStore unit tests.
// Same shape as TestProfileWriters.swift — NoopArtistWriter covers
// the optimistic-success branch, FailingArtistWriter exercises the
// rollback + lastError branch.

import Foundation
@testable import RostrPlusFeature

struct NoopArtistWriter: ArtistWriter {
    func patchArtist<Patch: Encodable & Sendable>(
        _ patch: Patch, artistID: UUID
    ) async throws {
        // Simulate the round-trip without doing anything.
    }
}

struct FailingArtistWriter: ArtistWriter {
    struct StubError: Error, LocalizedError {
        var errorDescription: String? { "Stubbed write failure" }
    }

    func patchArtist<Patch: Encodable & Sendable>(
        _ patch: Patch, artistID: UUID
    ) async throws {
        throw StubError()
    }
}
