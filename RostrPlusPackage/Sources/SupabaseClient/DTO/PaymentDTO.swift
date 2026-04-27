// PaymentDTO.swift
//
// Codable mirror of public.payments. Every payment is anchored to a
// booking via booking_id. We inline the bookings(event_name,artist:…)
// join so PaymentsView can render without a second round-trip.
//
// RLS on public.payments only lets the booking's promoter or artist
// read the rows.

import Foundation

public struct PaymentDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let bookingID: UUID?
    public let amount: Decimal
    public let currency: String?
    public let type: String?
    public let status: String?
    public let paymentMethod: String?
    public let paidAt: Date?
    public let createdAt: Date?
    public let invoiceNumber: String?
    public let booking: BookingLite?

    public struct BookingLite: Codable, Hashable, Sendable {
        public let eventName: String?
        public let eventDate: Date?
        public let venueName: String?
        public let artist: Artist?

        public struct Artist: Codable, Hashable, Sendable {
            public let stageName: String?
            enum CodingKeys: String, CodingKey {
                case stageName = "stage_name"
            }
        }

        enum CodingKeys: String, CodingKey {
            case eventName = "event_name"
            case eventDate = "event_date"
            case venueName = "venue_name"
            case artist    = "artists"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bookingID     = "booking_id"
        case amount
        case currency
        case type
        case status
        case paymentMethod = "payment_method"
        case paidAt        = "paid_at"
        case createdAt     = "created_at"
        case invoiceNumber = "invoice_number"
        case booking       = "bookings"
    }

    public static let selectFields = """
    id,booking_id,amount,currency,type,status,payment_method,paid_at,\
    created_at,invoice_number,\
    bookings(event_name,event_date,venue_name,artists(stage_name))
    """
}
