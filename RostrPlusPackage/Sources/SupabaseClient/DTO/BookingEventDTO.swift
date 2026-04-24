// BookingEventDTO.swift
//
// Codable mirror of public.booking_events — the append-only log that
// powers the iOS BookingDetailView timeline. Every meaningful state
// transition on a booking lands as one row; RLS ensures a caller only
// sees events for bookings they're a party to.
//
// `kind` is the enum-constrained column — we normalise it client-side
// into a Kind enum for the view layer, so switching on cases works.

import Foundation

public struct BookingEventDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let bookingID: UUID
    public let actorID: UUID?
    public let kind: String
    public let label: String?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case bookingID = "booking_id"
        case actorID   = "actor_id"
        case kind
        case label
        case createdAt = "created_at"
    }

    public static let selectFields =
        "id,booking_id,actor_id,kind,label,created_at"
}
