// BookingDTO.swift
//
// Codable mirror of public.bookings. Matches the column set the web
// app reads (see rostrplusapp/assets/js/app.js DB.getMyBookings).
//
// Embedded artist + promoter joins use PostgREST's inline-select
// syntax — BookingsStore fetches them in one trip so we don't need a
// second round trip per row to show the display name.

import Foundation

public struct BookingDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let promoterID: UUID?
    public let artistID: UUID?
    public let venueID: UUID?
    public let eventName: String?
    public let eventDate: Date?
    public let eventTime: String?
    public let setDuration: Int?
    public let status: String?
    public let fee: Double?
    public let currency: String?
    public let venueName: String?
    public let notes: String?
    public let createdAt: Date?

    /// Inlined join — PostgREST can pull an artist's stage_name alongside
    /// the booking row. Keeps lists one-round-trip.
    public let artist: Artist?

    public struct Artist: Codable, Hashable, Sendable {
        public let stageName: String?

        enum CodingKeys: String, CodingKey {
            case stageName = "stage_name"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case promoterID   = "promoter_id"
        case artistID     = "artist_id"
        case venueID      = "venue_id"
        case eventName    = "event_name"
        case eventDate    = "event_date"
        case eventTime    = "event_time"
        case setDuration  = "set_duration"
        case status
        case fee
        case currency
        case venueName    = "venue_name"
        case notes
        case createdAt    = "created_at"
        case artist       = "artists"
    }

    /// Column list for PostgREST .select(). Includes the inlined
    /// artist join via artists(stage_name). Kept here so every store
    /// touching bookings queries the same shape.
    public static let selectFields = """
    id,promoter_id,artist_id,venue_id,event_name,event_date,event_time,\
    set_duration,status,fee,currency,venue_name,notes,created_at,\
    artists(stage_name)
    """
}
