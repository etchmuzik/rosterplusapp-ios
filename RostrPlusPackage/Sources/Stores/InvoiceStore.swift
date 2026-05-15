// InvoiceStore.swift
//
// Loads the data needed to render an invoice for a single booking:
// the latest `payments` row associated with the booking_id (per RLS,
// only promoter / artist parties can read it). The DTO already
// inlines the bookings → artists join, so one round-trip is enough.
//
// Three states: idle / loading / loaded(invoice) / failed(message).
// Cached by bookingID so repeated visits to the same invoice are
// synchronous after the first fetch.

import Foundation
import Observation
import Supabase

public struct Invoice: Hashable, Sendable {
    public let bookingID: UUID
    public let invoiceNumber: String?
    public let issuedAt: Date?
    public let amount: Decimal
    public let currency: String
    public let status: PaymentRow.Status
    public let artistName: String
    public let venueName: String?
    public let eventDate: Date?
    public let billToName: String
    public let billToEmail: String?
}

@Observable
@MainActor
public final class InvoiceStore {

    public enum State: Sendable {
        case idle
        case loading(UUID)
        case loaded(Invoice)
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var cache: [UUID: Invoice] = [:]

    private let client = RostrSupabase.shared
    private var inFlight: Set<UUID> = []

    public init() {}

    /// Drop cached invoices. Called on sign-out so user B doesn't
    /// briefly see user A's invoices.
    public func reset() {
        inFlight.removeAll()
        cache.removeAll()
        state = .idle
    }

    /// Resolve an invoice for the given booking. Synchronous on cache
    /// hit; otherwise fetches and flips state to .loading until it
    /// resolves. `billToName` / `billToEmail` come from the caller's
    /// session (the view passes them in; AuthStore is the source).
    public func fetch(bookingID: UUID, billToName: String, billToEmail: String?) {
        if let cached = cache[bookingID] {
            state = .loaded(cached)
            return
        }
        if inFlight.contains(bookingID) { return }
        inFlight.insert(bookingID)
        state = .loading(bookingID)

        Task { [weak self] in
            guard let self else { return }
            defer { self.inFlight.remove(bookingID) }
            do {
                let rows: [PaymentDTO] = try await client
                    .from("payments")
                    .select(PaymentDTO.selectFields)
                    .eq("booking_id", value: bookingID)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                guard let payment = rows.first else {
                    if case .loading(let pending) = self.state, pending == bookingID {
                        self.state = .failed("No invoice has been issued for this booking yet.")
                    }
                    return
                }
                let invoice = Self.invoiceFromPayment(
                    payment,
                    bookingID: bookingID,
                    billToName: billToName,
                    billToEmail: billToEmail
                )
                self.cache[bookingID] = invoice
                if case .loading(let pending) = self.state, pending == bookingID {
                    self.state = .loaded(invoice)
                }
            } catch {
                if case .loading(let pending) = self.state, pending == bookingID {
                    self.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    private static func invoiceFromPayment(
        _ p: PaymentDTO,
        bookingID: UUID,
        billToName: String,
        billToEmail: String?
    ) -> Invoice {
        let status: PaymentRow.Status = {
            switch p.status {
            case "completed": return .paid
            case "pending":   return .pending
            case "processing": return .scheduled
            case "failed":    return .failed
            case "refunded":  return .refunded
            default:          return .pending
            }
        }()
        return Invoice(
            bookingID: bookingID,
            invoiceNumber: p.invoiceNumber,
            issuedAt: p.paidAt ?? p.createdAt,
            amount: p.amount,
            currency: p.currency ?? "AED",
            status: status,
            artistName: p.booking?.artist?.stageName ?? "Artist",
            venueName: p.booking?.venueName ?? p.booking?.eventName,
            eventDate: p.booking?.eventDate,
            billToName: billToName,
            billToEmail: billToEmail
        )
    }
}
