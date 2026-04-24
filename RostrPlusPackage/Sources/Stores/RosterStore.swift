// RosterStore.swift
//
// Fetches the public artist directory from Supabase. Respects the RLS
// policy that lets anon read every active, non-hidden artist.
//
// The store surfaces a simple state enum (loading / loaded / failed)
// plus filters (search + genre) that the RosterView binds to. Refresh
// is idempotent — calling it while a fetch is in flight no-ops.

import Foundation
import Observation
import Supabase

/// Local, display-friendly shape. DTOs live in SupabaseClient/DTO/.
/// This struct is what RosterView renders; MockArtist is the legacy
/// preview-only shape the view falls back to before the store loads.
public struct RosterArtist: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let stage: String
    public let genre: String
    public let city: String
    public let rating: Double
    public let verified: Bool
}

@Observable
@MainActor
public final class RosterStore {

    public enum State {
        case idle
        case loading
        case loaded([RosterArtist])
        case failed(String)
    }

    public private(set) var state: State = .idle

    public var search: String = ""
    public var genreFilter: String = "All"

    private let client = RostrSupabase.shared
    private var inFlight: Task<Void, Never>?

    public init() {}

    // MARK: — Fetch

    public func refresh() {
        // No double-fetches — the store is single-consumer.
        if inFlight != nil { return }

        inFlight = Task { [weak self] in
            guard let self else { return }
            self.state = .loading
            do {
                let rows: [ArtistDTO] = try await client
                    .from("artists")
                    .select(ArtistDTO.selectFields)
                    .eq("status", value: "active")
                    .order("stage_name", ascending: true)
                    .execute()
                    .value

                let artists: [RosterArtist] = rows.map { dto in
                    RosterArtist(
                        id: dto.id,
                        stage: dto.stageName ?? "—",
                        genre: (dto.genre ?? []).first ?? "Artist",
                        city: (dto.citiesActive ?? []).first ?? "—",
                        rating: dto.rating ?? 0,
                        verified: dto.verified ?? false
                    )
                }
                self.state = .loaded(artists)
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.inFlight = nil
        }
    }

    // MARK: — Derived

    /// Artists matching the current search + genre filter. Uses the
    /// loaded array when present; otherwise empty.
    public var visible: [RosterArtist] {
        guard case .loaded(let all) = state else { return [] }
        return all.filter { a in
            (genreFilter == "All" || a.genre == genreFilter) &&
            (search.isEmpty ||
             a.stage.localizedCaseInsensitiveContains(search) ||
             a.genre.localizedCaseInsensitiveContains(search) ||
             a.city.localizedCaseInsensitiveContains(search))
        }
    }

    /// Full genre list for the filter-chip row. Always prefixed with "All".
    public var genres: [String] {
        guard case .loaded(let all) = state else { return ["All"] }
        let s = Set(all.map(\.genre))
        return ["All"] + Array(s).sorted()
    }

    #if DEBUG
    /// Test seam — injects a loaded state directly so filter logic can
    /// be unit-tested without hitting Supabase. DEBUG-only.
    public func _testLoad(_ artists: [RosterArtist]) {
        state = .loaded(artists)
    }
    #endif
}
