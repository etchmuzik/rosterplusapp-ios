// BookingsStore.swift
//
// Fetches + caches the current user's bookings. Split into upcoming
// (event_date >= today) and past (event_date < today) so Home can
// read `upNext` without re-filtering every frame.
//
// Reads public.bookings filtered to the signed-in user — promoter_id
// when role == promoter, or the promoter-side of artist_id lookups
// when role == artist. RLS on the table enforces the same rule
// server-side, so even a client-side filter bug can't leak data.

import Foundation
import Observation
import Supabase

/// Display shape. RosterArtist-style local type so views don't have
/// to deal with DTO optionals at render time.
public struct BookingRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let eventName: String
    public let artistName: String
    public let venueName: String
    public let eventDate: Date
    public let status: String
    public let feeFormatted: String
    public let currency: String
    public let fee: Double?

    /// Status mapping to the view enum. Keeps MockBooking.Status's
    /// three-case simplicity while the DTO supports the full five.
    public var displayStatus: String { status }
}

@Observable
@MainActor
public final class BookingsStore {

    public enum State {
        case idle
        case loading
        case loaded(upcoming: [BookingRow], past: [BookingRow])
        case failed(String)
    }

    public private(set) var state: State = .idle

    /// Cache of single-booking detail fetches. Keyed by booking id so
    /// BookingDetailView can read synchronously once it's prefetched.
    public private(set) var detailCache: [UUID: BookingRow] = [:]

    private let client = RostrSupabase.shared
    private var inFlight: Task<Void, Never>?
    private var detailInFlight: Set<UUID> = []

    public init() {}

    // MARK: — List

    /// Fetch every booking the current user is a party to. Splits the
    /// response client-side into upcoming + past.
    public func refresh(for userID: UUID, role: Role) {
        if inFlight != nil { return }

        inFlight = Task { [weak self] in
            guard let self else { return }
            self.state = .loading
            do {
                let rows: [BookingDTO]
                switch role {
                case .promoter:
                    rows = try await client
                        .from("bookings")
                        .select(BookingDTO.selectFields)
                        .eq("promoter_id", value: userID)
                        .order("event_date", ascending: true)
                        .execute()
                        .value
                case .artist:
                    // An artist's bookings are on artist_id, which
                    // points to public.artists.id, not auth.uid(). We
                    // resolve my artist.id first, then filter.
                    let myArtistID = try await fetchMyArtistID(userID: userID)
                    guard let myArtistID else {
                        self.state = .loaded(upcoming: [], past: [])
                        return
                    }
                    rows = try await client
                        .from("bookings")
                        .select(BookingDTO.selectFields)
                        .eq("artist_id", value: myArtistID)
                        .order("event_date", ascending: true)
                        .execute()
                        .value
                }

                let mapped = rows.map(Self.rowFromDTO)
                let today = Calendar.current.startOfDay(for: Date())
                let upcoming = mapped.filter { $0.eventDate >= today }
                let past = mapped
                    .filter { $0.eventDate < today }
                    .reversed() // most-recent first
                self.state = .loaded(upcoming: upcoming, past: Array(past))

                // Warm the detail cache with everything we just loaded.
                for row in mapped { self.detailCache[row.id] = row }
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.inFlight = nil
        }
    }

    // MARK: — Single detail

    /// Fetch (or return cached) detail for one booking. BookingDetailView
    /// calls this on appear; cache hits are instant.
    public func fetchDetail(id: UUID) {
        if detailCache[id] != nil { return }
        if detailInFlight.contains(id) { return }
        detailInFlight.insert(id)

        Task { [weak self] in
            guard let self else { return }
            defer { self.detailInFlight.remove(id) }
            do {
                let row: BookingDTO = try await client
                    .from("bookings")
                    .select(BookingDTO.selectFields)
                    .eq("id", value: id)
                    .single()
                    .execute()
                    .value
                self.detailCache[id] = Self.rowFromDTO(row)
            } catch {
                // Silent failure — detail view falls through to a
                // "couldn't load" state using state != .loaded.
            }
        }
    }

    // MARK: — Derived

    public var upcoming: [BookingRow] {
        if case .loaded(let up, _) = state { return up }
        return []
    }

    public var past: [BookingRow] {
        if case .loaded(_, let past) = state { return past }
        return []
    }

    /// Next 3 upcoming, for Home's "Up next" section.
    public var upNext: [BookingRow] {
        Array(upcoming.prefix(3))
    }

    /// Compact stats for Home's tile grid.
    public var stats: (upcomingCount: Int, pendingCount: Int, monthTotal: String) {
        let up = upcoming.count
        let pending = upcoming.filter { $0.status == "pending" }.count
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        // Sum fees for bookings in the current calendar month. Mixes
        // currencies naively for now — production gets a converter.
        let monthSum = (upcoming + past)
            .filter { $0.eventDate >= monthStart && $0.eventDate <= now.addingTimeInterval(30 * 86_400) }
            .compactMap(\.fee)
            .reduce(0, +)
        let currency = (upcoming.first?.currency ?? past.first?.currency ?? "AED")
        return (up, pending, "\(currency) \(Self.formatK(monthSum))")
    }

    // MARK: — Helpers

    private func fetchMyArtistID(userID: UUID) async throws -> UUID? {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("artists")
            .select("id")
            .eq("profile_id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }

    /// Translate a DTO into the display-friendly local type. Handles
    /// nil-safety + formats fees up front so views don't need to.
    private static func rowFromDTO(_ dto: BookingDTO) -> BookingRow {
        let fee = dto.fee ?? 0
        let currency = dto.currency ?? "AED"
        let feeStr: String = {
            if fee == 0 { return "—" }
            if fee >= 1000 { return "\(currency) \(formatK(fee))" }
            return "\(currency) \(Int(fee))"
        }()
        return BookingRow(
            id: dto.id,
            eventName: dto.eventName ?? "Event",
            artistName: dto.artist?.stageName ?? "Artist",
            venueName: dto.venueName ?? "—",
            eventDate: dto.eventDate ?? Date.distantPast,
            status: dto.status ?? "pending",
            feeFormatted: feeStr,
            currency: currency,
            fee: dto.fee
        )
    }

    /// AED 28,000 → "28K". AED 184 → "184" (callers also gate on >= 1K).
    private static func formatK(_ amount: Double) -> String {
        let thousands = amount / 1000
        if amount >= 1000 {
            return thousands.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(thousands))K"
                : String(format: "%.1fK", thousands)
        }
        return "\(Int(amount))"
    }

    #if DEBUG
    /// Test seam — injects a loaded state directly.
    public func _testLoad(upcoming: [BookingRow], past: [BookingRow]) {
        self.state = .loaded(upcoming: upcoming, past: past)
        for r in upcoming + past { detailCache[r.id] = r }
    }
    #endif
}
