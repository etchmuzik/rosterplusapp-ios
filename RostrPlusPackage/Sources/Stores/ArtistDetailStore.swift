// ArtistDetailStore.swift
//
// Fetches the *full* ArtistDTO for a single artist (ArtistView + EPKView).
// RosterStore deliberately selects a lean list of columns for the grid;
// this store pulls everything including the JSONB press/performance
// blobs so the EPK can render without a second round-trip.
//
// Cached by artist UUID — navigating back and forth is instant after
// the first fetch.

import Foundation
import Observation
import Supabase

/// Display-friendly snapshot of one artist with all EPK surface loaded.
public struct ArtistDetail: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let stageName: String
    public let genres: [String]
    public let citiesActive: [String]
    public let baseFee: Double?
    public let currency: String
    public let rating: Double
    public let totalBookings: Int
    public let verified: Bool
    public let epkURL: String?
    public let pressQuotes: [ArtistDTO.PressQuote]
    public let pastPerformances: [ArtistDTO.PastPerformance]
    public let social: ArtistDTO.SocialLinks?
}

@Observable
@MainActor
public final class ArtistDetailStore {

    public enum State {
        case idle
        case loading(UUID)
        case loaded(ArtistDetail)
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var cache: [UUID: ArtistDetail] = [:]

    private let client = RostrSupabase.shared
    private var inFlight: Set<UUID> = []

    public init() {}

    // MARK: — Fetch

    /// Fetch a single artist's full detail. Cache hits set the state
    /// synchronously; misses kick a network request and flip state to
    /// `.loading(id)` until it resolves.
    public func fetch(id: UUID) {
        if let cached = cache[id] {
            state = .loaded(cached)
            return
        }
        if inFlight.contains(id) { return }
        inFlight.insert(id)
        state = .loading(id)

        Task { [weak self] in
            guard let self else { return }
            defer { self.inFlight.remove(id) }
            do {
                let dto: ArtistDTO = try await client
                    .from("artists")
                    .select(ArtistDTO.selectFieldsDetail)
                    .eq("id", value: id)
                    .single()
                    .execute()
                    .value
                let detail = Self.detailFromDTO(dto)
                self.cache[id] = detail
                if case .loading(let pending) = self.state, pending == id {
                    self.state = .loaded(detail)
                }
            } catch {
                if case .loading(let pending) = self.state, pending == id {
                    self.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    // MARK: — Helpers

    private static func detailFromDTO(_ dto: ArtistDTO) -> ArtistDetail {
        ArtistDetail(
            id: dto.id,
            stageName: dto.stageName ?? "Artist",
            genres: dto.genre ?? [],
            citiesActive: dto.citiesActive ?? [],
            baseFee: dto.baseFee,
            currency: dto.currency ?? "AED",
            rating: dto.rating ?? 0,
            totalBookings: dto.totalBookings ?? 0,
            verified: dto.verified ?? false,
            epkURL: dto.epkURL,
            pressQuotes: dto.pressQuotes ?? [],
            pastPerformances: dto.pastPerformances ?? [],
            social: dto.socialLinks
        )
    }

    #if DEBUG
    public func _testLoad(_ detail: ArtistDetail) {
        cache[detail.id] = detail
        state = .loaded(detail)
    }
    #endif
}
