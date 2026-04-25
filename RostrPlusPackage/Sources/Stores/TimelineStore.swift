// TimelineStore.swift
//
// Fetches + caches booking_events for the BookingDetailView timeline.
// Keyed by booking UUID — opening a detail view hits `fetch(for:)`
// which is idempotent (cache hit = instant, miss = network).
//
// Wave 5.3 also subscribes to the booking_events postgres-changes
// stream scoped to that single booking, so the timeline updates live
// when the counterparty signs a contract, records a payment, etc.
// RLS gates what the channel delivers — a non-party never receives
// events for a booking they can't read.

import Foundation
import Observation
import Supabase
import Realtime

/// Display shape. Kind is normalised from the server-side string so
/// the view layer can exhaustively switch on it.
public struct TimelineEvent: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: Kind
    public let label: String
    public let createdAt: Date

    public enum Kind: String, Sendable {
        case requestSent           = "request_sent"
        case artistAccepted        = "artist_accepted"
        case artistDeclined        = "artist_declined"
        case contractDrafted       = "contract_drafted"
        case contractSignedArtist  = "contract_signed_artist"
        case contractSignedPromoter = "contract_signed_promoter"
        case contractCountersigned = "contract_countersigned"
        case paymentScheduled      = "payment_scheduled"
        case paymentRecorded       = "payment_recorded"
        case paymentConfirmed      = "payment_confirmed"
        case eventCompleted        = "event_completed"
        case eventCancelled        = "event_cancelled"
        case reviewSubmitted       = "review_submitted"
        case note                  = "note"
        case other                 = "other"
    }
}

@Observable
@MainActor
public final class TimelineStore {

    /// Cached events per booking id, ordered ascending by time.
    public private(set) var eventsByBooking: [UUID: [TimelineEvent]] = [:]

    /// Which booking we're currently subscribed to for realtime. Only
    /// one active channel at a time — the detail view rebinds on push.
    private var activeBookingID: UUID?
    private var activeChannel: RealtimeChannelV2?
    private var activeSubscription: RealtimeSubscription?

    private let client = RostrSupabase.shared
    private var inFlight: Set<UUID> = []

    public init() {}

    // MARK: — Fetch

    /// Pull the full timeline for a booking. Idempotent — if we already
    /// have cached events for this booking we no-op. Opens a realtime
    /// channel for this booking after the initial fetch lands.
    public func fetch(for bookingID: UUID) {
        if inFlight.contains(bookingID) { return }
        inFlight.insert(bookingID)

        Task { [weak self] in
            guard let self else { return }
            defer { self.inFlight.remove(bookingID) }
            do {
                let rows: [BookingEventDTO] = try await client
                    .from("booking_events")
                    .select(BookingEventDTO.selectFields)
                    .eq("booking_id", value: bookingID)
                    .order("created_at", ascending: true)
                    .execute()
                    .value
                self.eventsByBooking[bookingID] = rows.map(Self.eventFromDTO)
                await self.subscribe(to: bookingID)
            } catch {
                // Leave cache untouched — view falls back to empty list.
                #if DEBUG
                print("TimelineStore.fetch failed:", error)
                #endif
            }
        }
    }

    public func events(for bookingID: UUID) -> [TimelineEvent] {
        eventsByBooking[bookingID] ?? []
    }

    /// Active event — the latest one, highlighted in the view's dot.
    /// Matches the JSX where the most recent row is the "current" step.
    public func activeEventID(for bookingID: UUID) -> UUID? {
        eventsByBooking[bookingID]?.last?.id
    }

    // MARK: — Realtime

    /// Subscribe to INSERTs on booking_events for this specific booking.
    /// If we were subscribed to a different booking, tear that channel
    /// down first — one booking in focus at a time.
    private func subscribe(to bookingID: UUID) async {
        if activeBookingID == bookingID, activeChannel != nil { return }
        await unsubscribe()
        activeBookingID = bookingID

        let channel = client.realtimeV2.channel("booking_events:\(bookingID.uuidString)")
        let subscription = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "booking_events",
            filter: "booking_id=eq.\(bookingID.uuidString)"
        ) { [weak self] action in
            Task { @MainActor [weak self] in
                self?.handleInsert(action, for: bookingID)
            }
        }
        do {
            try await channel.subscribeWithError()
        } catch {
            print("TimelineStore.subscribe failed:", error)
        }
        activeChannel = channel
        activeSubscription = subscription
    }

    /// Tear down the active channel. Called on view disappear or when
    /// the focused booking changes.
    public func unsubscribe() async {
        activeSubscription?.cancel()
        activeSubscription = nil
        if let channel = activeChannel {
            await channel.unsubscribe()
        }
        activeChannel = nil
        activeBookingID = nil
    }

    /// Decode the inserted row + append to the cache, keeping the
    /// ascending-by-time invariant.
    private func handleInsert(_ action: InsertAction, for bookingID: UUID) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let dto = try action.decodeRecord(as: BookingEventDTO.self, decoder: decoder)
            guard dto.bookingID == bookingID else { return }
            let event = Self.eventFromDTO(dto)
            var current = eventsByBooking[bookingID] ?? []
            // Dedupe on id in case the initial fetch raced the INSERT.
            guard !current.contains(where: { $0.id == event.id }) else { return }
            current.append(event)
            current.sort { $0.createdAt < $1.createdAt }
            eventsByBooking[bookingID] = current
        } catch {
            #if DEBUG
            print("TimelineStore.handleInsert decode failed:", error)
            #endif
        }
    }

    // MARK: — Helpers

    private static func eventFromDTO(_ dto: BookingEventDTO) -> TimelineEvent {
        let kind = TimelineEvent.Kind(rawValue: dto.kind) ?? .other
        return TimelineEvent(
            id: dto.id,
            kind: kind,
            label: dto.label ?? defaultLabel(for: kind),
            createdAt: dto.createdAt
        )
    }

    /// Human-readable fallback when the trigger didn't set `label`.
    /// Keeps the display layer copy in one place.
    private static func defaultLabel(for kind: TimelineEvent.Kind) -> String {
        switch kind {
        case .requestSent:            return "Booking request sent"
        case .artistAccepted:         return "Artist accepted"
        case .artistDeclined:         return "Artist declined"
        case .contractDrafted:        return "Contract drafted"
        case .contractSignedArtist:   return "Artist signed"
        case .contractSignedPromoter: return "Promoter signed"
        case .contractCountersigned:  return "Contract countersigned"
        case .paymentScheduled:       return "Payment scheduled"
        case .paymentRecorded:        return "Payment recorded"
        case .paymentConfirmed:       return "Payment confirmed"
        case .eventCompleted:         return "Performance completed"
        case .eventCancelled:         return "Booking cancelled"
        case .reviewSubmitted:        return "Review submitted"
        case .note:                   return "Note"
        case .other:                  return "Update"
        }
    }

    #if DEBUG
    /// Test seam for preview + unit tests. Seeds the cache without
    /// touching the network.
    public func _testLoad(_ events: [TimelineEvent], for bookingID: UUID) {
        eventsByBooking[bookingID] = events.sorted { $0.createdAt < $1.createdAt }
    }
    #endif
}
