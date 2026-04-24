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
    /// startOfDay-normalized dates the artist has blocked off.
    public let blockedDates: Set<Date>

    public init(
        id: UUID,
        stageName: String,
        genres: [String],
        citiesActive: [String],
        baseFee: Double?,
        currency: String,
        rating: Double,
        totalBookings: Int,
        verified: Bool,
        epkURL: String?,
        pressQuotes: [ArtistDTO.PressQuote],
        pastPerformances: [ArtistDTO.PastPerformance],
        social: ArtistDTO.SocialLinks?,
        blockedDates: Set<Date> = []
    ) {
        self.id = id
        self.stageName = stageName
        self.genres = genres
        self.citiesActive = citiesActive
        self.baseFee = baseFee
        self.currency = currency
        self.rating = rating
        self.totalBookings = totalBookings
        self.verified = verified
        self.epkURL = epkURL
        self.pressQuotes = pressQuotes
        self.pastPerformances = pastPerformances
        self.social = social
        self.blockedDates = blockedDates
    }
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

    /// The current signed-in user's artist id, resolved on demand.
    /// Profile -> artist lookup keys on public.artists.profile_id.
    public private(set) var myArtistID: UUID?

    /// Last save error from any mutation on this store. Forms surface
    /// it inline; nil after a successful save.
    public private(set) var lastError: String?

    private let client = RostrSupabase.shared
    private var inFlight: Set<UUID> = []

    public init() {}

    // MARK: — My artist id

    /// Resolve the artist row owned by the signed-in user. Call once
    /// per session from whichever view needs to mutate availability /
    /// profile data. Idempotent — cached after the first hit.
    public func resolveMyArtistID(userID: UUID) async {
        if myArtistID != nil { return }
        struct Row: Decodable { let id: UUID }
        do {
            let rows: [Row] = try await client
                .from("artists")
                .select("id")
                .eq("profile_id", value: userID)
                .limit(1)
                .execute()
                .value
            myArtistID = rows.first?.id
            // Warm the detail cache for the artist's own view.
            if let id = myArtistID {
                fetch(id: id)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

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
        let cal = Calendar.current
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone(identifier: "UTC")
        let blocked: Set<Date> = Set(
            (dto.blockedDates ?? []).compactMap { raw in
                parser.date(from: raw).map { cal.startOfDay(for: $0) }
            }
        )
        return ArtistDetail(
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
            social: dto.socialLinks,
            blockedDates: blocked
        )
    }

    // MARK: — Mutations

    /// Persist the given blocked-date set to public.artists. Encodes
    /// as date strings (yyyy-MM-dd) — PostgREST casts them into the
    /// date[] column server-side.
    public func updateBlockedDates(_ dates: Set<Date>, for artistID: UUID) async {
        lastError = nil
        // Optimistic local flip.
        if let existing = cache[artistID] {
            let merged = Self.withBlockedDates(existing, dates: dates)
            cache[artistID] = merged
            if case .loaded(let shown) = state, shown.id == artistID {
                state = .loaded(merged)
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let sorted = dates.sorted()
        let payload = sorted.map { formatter.string(from: $0) }

        struct Patch: Encodable { let blocked_dates: [String] }
        do {
            _ = try await client
                .from("artists")
                .update(Patch(blocked_dates: payload))
                .eq("id", value: artistID)
                .execute()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Persist a new base_fee on public.artists. Caller passes the raw
    /// fee (e.g. 28_000, not 28K).
    public func updateBaseFee(_ fee: Double, for artistID: UUID) async {
        lastError = nil
        if let existing = cache[artistID] {
            let merged = Self.withBaseFee(existing, fee: fee)
            cache[artistID] = merged
            if case .loaded(let shown) = state, shown.id == artistID {
                state = .loaded(merged)
            }
        }
        struct Patch: Encodable { let base_fee: Double }
        do {
            _ = try await client
                .from("artists")
                .update(Patch(base_fee: fee))
                .eq("id", value: artistID)
                .execute()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Persist a subset of the stage_name / genre / social_links fields.
    /// Nil fields are left alone server-side.
    public func updateProfileCore(
        artistID: UUID,
        stageName: String? = nil,
        primaryGenre: String? = nil,
        social: ArtistDTO.SocialLinks? = nil
    ) async {
        lastError = nil
        if let existing = cache[artistID] {
            let merged = Self.withProfileCore(
                existing,
                stageName: stageName,
                primaryGenre: primaryGenre,
                social: social
            )
            cache[artistID] = merged
            if case .loaded(let shown) = state, shown.id == artistID {
                state = .loaded(merged)
            }
        }
        struct Patch: Encodable {
            let stage_name: String?
            let genre: [String]?
            let social_links: ArtistDTO.SocialLinks?
        }
        let genrePatch: [String]? = primaryGenre.map { [$0] }
        let patch = Patch(
            stage_name: stageName,
            genre: genrePatch,
            social_links: social
        )
        do {
            _ = try await client
                .from("artists")
                .update(patch)
                .eq("id", value: artistID)
                .execute()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: — Value-type merges

    private static func withBlockedDates(_ d: ArtistDetail, dates: Set<Date>) -> ArtistDetail {
        ArtistDetail(
            id: d.id, stageName: d.stageName, genres: d.genres,
            citiesActive: d.citiesActive, baseFee: d.baseFee,
            currency: d.currency, rating: d.rating,
            totalBookings: d.totalBookings, verified: d.verified,
            epkURL: d.epkURL, pressQuotes: d.pressQuotes,
            pastPerformances: d.pastPerformances, social: d.social,
            blockedDates: dates
        )
    }

    private static func withBaseFee(_ d: ArtistDetail, fee: Double) -> ArtistDetail {
        ArtistDetail(
            id: d.id, stageName: d.stageName, genres: d.genres,
            citiesActive: d.citiesActive, baseFee: fee,
            currency: d.currency, rating: d.rating,
            totalBookings: d.totalBookings, verified: d.verified,
            epkURL: d.epkURL, pressQuotes: d.pressQuotes,
            pastPerformances: d.pastPerformances, social: d.social,
            blockedDates: d.blockedDates
        )
    }

    private static func withProfileCore(
        _ d: ArtistDetail,
        stageName: String?,
        primaryGenre: String?,
        social: ArtistDTO.SocialLinks?
    ) -> ArtistDetail {
        let nextGenres: [String] = {
            guard let g = primaryGenre else { return d.genres }
            var base = d.genres
            if base.isEmpty {
                return [g]
            }
            base[0] = g
            return base
        }()
        return ArtistDetail(
            id: d.id,
            stageName: stageName ?? d.stageName,
            genres: nextGenres,
            citiesActive: d.citiesActive,
            baseFee: d.baseFee,
            currency: d.currency,
            rating: d.rating,
            totalBookings: d.totalBookings,
            verified: d.verified,
            epkURL: d.epkURL,
            pressQuotes: d.pressQuotes,
            pastPerformances: d.pastPerformances,
            social: social ?? d.social,
            blockedDates: d.blockedDates
        )
    }

    #if DEBUG
    public func _testLoad(_ detail: ArtistDetail) {
        cache[detail.id] = detail
        state = .loaded(detail)
    }
    #endif
}
