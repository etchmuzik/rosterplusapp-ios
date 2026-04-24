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

    /// Raw server status string. Views map this to their local enum
    /// via a `statusTag(for:)` helper — kept as text so the store
    /// doesn't depend on any particular view's enum case set.
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

    // MARK: — Mutations

    /// Response to an inbound booking request. An artist can `.accept`
    /// (status → `confirmed`) or `.decline` (status → `cancelled`).
    /// Both update the row optimistically so the dashboard reacts
    /// instantly; the server write follows and a silent failure leaves
    /// the optimistic row in place (next refresh reconciles).
    public enum RequestResponse: String, Sendable {
        case accept
        case decline

        var targetStatus: String {
            switch self {
            case .accept:  return "confirmed"
            case .decline: return "cancelled"
            }
        }
    }

    /// Patch a single booking's status. The row moves out of
    /// `pendingRequests` immediately; the server roundtrip fires in
    /// the background. RLS enforces that only the booking's artist or
    /// promoter can write this column.
    public func respond(to bookingID: UUID, with response: RequestResponse) {
        // Optimistic local update — find the row in either bucket and
        // replace it with a new copy carrying the new status.
        if case .loaded(var up, let past) = state,
           let idx = up.firstIndex(where: { $0.id == bookingID }) {
            up[idx] = Self.withStatus(up[idx], status: response.targetStatus)
            detailCache[bookingID] = up[idx]
            state = .loaded(upcoming: up, past: past)
        } else if case .loaded(let up, var past) = state,
                  let idx = past.firstIndex(where: { $0.id == bookingID }) {
            past[idx] = Self.withStatus(past[idx], status: response.targetStatus)
            detailCache[bookingID] = past[idx]
            state = .loaded(upcoming: up, past: past)
        }

        Task { [weak self] in
            guard let self else { return }
            struct Patch: Encodable { let status: String }
            do {
                _ = try await client
                    .from("bookings")
                    .update(Patch(status: response.targetStatus))
                    .eq("id", value: bookingID)
                    .execute()
            } catch {
                // Optimistic row stays; next refresh reconciles with
                // server truth. A real app would surface a toast here.
                #if DEBUG
                print("BookingsStore.respond failed:", error)
                #endif
            }
        }
    }

    /// Immutable update helper — the struct is a value type so we
    /// build a new copy rather than mutate (aligned with CLAUDE.md's
    /// immutability principle).
    private static func withStatus(_ row: BookingRow, status: String) -> BookingRow {
        BookingRow(
            id: row.id,
            eventName: row.eventName,
            artistName: row.artistName,
            venueName: row.venueName,
            eventDate: row.eventDate,
            status: status,
            feeFormatted: row.feeFormatted,
            currency: row.currency,
            fee: row.fee
        )
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

    /// Inbound requests for the signed-in artist — any booking where
    /// the server-side status is still in the decision window. The
    /// ArtistDashboard surfaces these with Accept/Decline actions.
    ///
    /// Contract matches the web app: `inquiry` is the first message the
    /// promoter sends; `pending` is after the artist has read it but
    /// not yet decided. Both render as actionable rows until the artist
    /// flips the status to confirmed or cancelled.
    public var pendingRequests: [BookingRow] {
        (upcoming + past).filter { $0.status == "inquiry" || $0.status == "pending" }
            .sorted { $0.eventDate < $1.eventDate }
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
