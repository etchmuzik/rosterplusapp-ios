// PaymentsStore.swift
//
// Fetches the user's payments via the booking relation. For a promoter
// every payment on a booking where promoter_id = me. For an artist
// every payment on a booking where artist_id maps to my artists row.
//
// Because public.payments joins bookings via booking_id, the easiest
// filter path is to let RLS do the work server-side (`payments_read_own`
// policy) and fetch the lot without a .eq. RLS returns only the rows
// the user is a party to; client-side we just render what we get.

import Foundation
import Observation
import Supabase

public struct PaymentRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let artistName: String
    public let eventLabel: String
    public let amount: Decimal
    public let currency: String
    public let amountFormatted: String
    public let status: Status
    public let eventDate: Date?
    public let paidAt: Date?

    public enum Status: String, Sendable {
        case paid, pending, scheduled, failed, refunded
    }
}

@Observable
@MainActor
public final class PaymentsStore {

    public enum State {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var items: [PaymentRow] = []

    private let client = RostrSupabase.shared
    private var inFlight: Task<Void, Never>?

    public init() {}

    /// Drop all cached rows and cancel any in-flight fetch. Called on
    /// sign-out so the next signed-in user starts from a clean slate.
    public func reset() {
        inFlight?.cancel()
        inFlight = nil
        items = []
        state = .idle
    }

    // MARK: — Fetch

    /// Refresh is scoped to the user's own payments via server-side RLS.
    /// The `userID` parameter is kept here for API symmetry and in case
    /// we later want to cross-check client-side (belt-and-braces).
    public func refresh(for userID: UUID) {
        if inFlight != nil { return }
        _ = userID

        inFlight = Task { [weak self] in
            guard let self else { return }
            self.state = .loading
            do {
                let rows: [PaymentDTO] = try await client
                    .from("payments")
                    .select(PaymentDTO.selectFields)
                    .order("created_at", ascending: false)
                    .limit(100)
                    .execute()
                    .value
                self.items = rows.map(Self.rowFromDTO)
                self.state = .loaded
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.inFlight = nil
        }
    }

    // MARK: — Derived

    public var paid: [PaymentRow]      { items.filter { $0.status == .paid      } }
    public var pending: [PaymentRow]   { items.filter { $0.status == .pending   } }
    public var scheduled: [PaymentRow] { items.filter { $0.status == .scheduled } }

    public var monthTotal: Decimal {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return items
            .filter { ($0.paidAt ?? $0.eventDate ?? .distantPast) >= monthStart }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    // MARK: — Helpers

    private static func rowFromDTO(_ dto: PaymentDTO) -> PaymentRow {
        let ccy = dto.currency ?? "AED"
        let amountFormatted = MoneyFormatter.compact(dto.amount, currency: ccy)
        let eventLabel: String = {
            let venue = dto.booking?.venueName ?? dto.booking?.eventName ?? "Event"
            if let d = dto.booking?.eventDate {
                let f = DateFormatter()
                f.dateFormat = "EEE d"
                return "\(venue) · \(f.string(from: d))"
            }
            return venue
        }()
        let statusRaw = dto.status ?? "pending"
        let status: PaymentRow.Status = {
            switch statusRaw {
            case "completed": return .paid
            case "pending":   return .pending
            case "processing": return .scheduled
            case "failed":    return .failed
            case "refunded":  return .refunded
            default:          return .pending
            }
        }()
        return PaymentRow(
            id: dto.id,
            artistName: dto.booking?.artist?.stageName ?? "Artist",
            eventLabel: eventLabel,
            amount: dto.amount,
            currency: ccy,
            amountFormatted: amountFormatted,
            status: status,
            eventDate: dto.booking?.eventDate,
            paidAt: dto.paidAt
        )
    }

    #if DEBUG
    public func _testLoad(_ rows: [PaymentRow]) {
        self.items = rows
        self.state = .loaded
    }
    #endif
}
