// AvailabilityCheckStore.swift
//
// Wraps the public.check_availability RPC. BookingView step 2 calls
// `check(artistID:on:)` whenever the date changes; the store
// debounces in-flight calls by key so rapid date-picker scrubs don't
// fan out a request per tick.
//
// The RPC returns a single row { available: bool, reason: text } —
// we keep the latest result by (artistID + eventDate) key so a
// stale result can't flash in if the user toggles back and forth.

import Foundation
import Observation
import OSLog
import Supabase

private let log = Logger(subsystem: "io.rosterplus.app", category: "AvailabilityCheckStore")

public struct AvailabilityResult: Hashable, Sendable {
    public let available: Bool
    public let reason: String?
}

@Observable
@MainActor
public final class AvailabilityCheckStore {

    /// Latest result keyed by "artistID|yyyy-MM-dd". nil = still
    /// checking (or never checked).
    public private(set) var results: [String: AvailabilityResult] = [:]

    /// True when a check is in flight for the given key. BookingView
    /// uses this to gate the banner + disable Continue.
    public private(set) var inFlightKeys: Set<String> = []

    private let client = RostrSupabase.shared

    public init() {}

    // MARK: — Lookup helpers

    public func result(for artistID: UUID, date: Date) -> AvailabilityResult? {
        results[Self.key(artistID: artistID, date: date)]
    }

    public func isChecking(for artistID: UUID, date: Date) -> Bool {
        inFlightKeys.contains(Self.key(artistID: artistID, date: date))
    }

    // MARK: — RPC call

    /// Kick a check for (artistID, date). Returns immediately — watch
    /// `results` / `isChecking` for the answer. Deduplicates against
    /// an in-flight request with the same key.
    public func check(artistID: UUID, on date: Date) {
        let key = Self.key(artistID: artistID, date: date)
        if inFlightKeys.contains(key) { return }
        inFlightKeys.insert(key)

        Task { [weak self] in
            guard let self else { return }
            defer { self.inFlightKeys.remove(key) }
            do {
                struct Args: Encodable {
                    let p_artist_id: UUID
                    let p_event_date: String
                }
                struct Row: Decodable {
                    let available: Bool
                    let reason: String?
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone(identifier: "UTC")
                let rows: [Row] = try await client
                    .rpc("check_availability",
                         params: Args(
                            p_artist_id: artistID,
                            p_event_date: formatter.string(from: date)
                         ))
                    .execute()
                    .value
                let first = rows.first
                self.results[key] = AvailabilityResult(
                    available: first?.available ?? true,
                    reason: first?.reason
                )
            } catch {
                // Fail open: if the check errors out, we let the user
                // continue and rely on the server-side trigger/RLS to
                // reject a truly conflicting insert.
                self.results[key] = AvailabilityResult(available: true, reason: nil)
                #if DEBUG
                log.error("check failed: \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }
    }

    // MARK: — Reset

    /// Drop every cached availability result. Called on sign-out so the
    /// next signed-in user can't see whether artist X was available on
    /// date Y from the previous user's session — minor info leak, but
    /// no reason to keep it once the user is gone.
    public func reset() {
        results.removeAll()
        inFlightKeys.removeAll()
    }

    // MARK: — Helpers

    private static func key(artistID: UUID, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "\(artistID.uuidString)|\(formatter.string(from: date))"
    }

    #if DEBUG
    /// Test seam — stuff a precomputed result into the cache without
    /// hitting the network.
    public func _testSet(
        artistID: UUID,
        date: Date,
        available: Bool,
        reason: String? = nil
    ) {
        let key = Self.key(artistID: artistID, date: date)
        results[key] = AvailabilityResult(available: available, reason: reason)
    }
    #endif
}
