// ArtistDTO.swift
//
// Codable mirror of public.artists. Used by RosterStore + artist detail
// + EPK. Extended in Wave 5.1 with the JSONB EPK fields (press_quotes,
// past_performances) + the basic bio/social/tech-rider surface.
//
// The JSONB columns decode into nested Codable structs below — keeps
// everything type-safe at the view layer.

import Foundation

public struct ArtistDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let profileID: UUID?
    public let stageName: String?
    public let genre: [String]?
    public let citiesActive: [String]?
    public let baseFee: Double?
    public let currency: String?
    public let rating: Double?
    public let totalBookings: Int?
    public let verified: Bool?
    public let status: String?
    public let epkURL: String?
    public let pressQuotes: [PressQuote]?
    public let pastPerformances: [PastPerformance]?
    public let socialLinks: SocialLinks?

    /// Shape of each element inside the `press_quotes` JSONB array.
    /// Matches what the web admin tool writes: { outlet, quote }.
    public struct PressQuote: Codable, Hashable, Sendable, Identifiable {
        public let outlet: String
        public let quote: String
        public var id: String { outlet + "|" + quote.prefix(16) }
    }

    /// Shape of each element inside the `past_performances` JSONB array.
    /// Schema lives on the web admin side: { venue, city, date, crowd }.
    public struct PastPerformance: Codable, Hashable, Sendable, Identifiable {
        public let venue: String
        public let city: String?
        public let date: String?
        public let crowd: String?
        public var id: String { venue + "|" + (date ?? "") }
    }

    /// Optional social URLs the artist chooses to publish.
    public struct SocialLinks: Codable, Hashable, Sendable {
        public let instagram: String?
        public let soundcloud: String?
        public let spotify: String?
    }

    enum CodingKeys: String, CodingKey {
        case id
        case profileID        = "profile_id"
        case stageName        = "stage_name"
        case genre
        case citiesActive     = "cities_active"
        case baseFee          = "base_fee"
        case currency
        case rating
        case totalBookings    = "total_bookings"
        case verified
        case status
        case epkURL           = "epk_url"
        case pressQuotes      = "press_quotes"
        case pastPerformances = "past_performances"
        case socialLinks      = "social_links"
    }

    /// Compact list-view columns — what RosterStore asks for. Keeps the
    /// roster grid fast by skipping the big JSONB blobs.
    public static let selectFields =
        "id,stage_name,genre,cities_active,base_fee,currency,rating,verified,status"

    /// Full detail columns — what ArtistView + EPKView ask for. Includes
    /// the press/performance JSONB and social handles.
    public static let selectFieldsDetail = """
    id,profile_id,stage_name,genre,cities_active,base_fee,currency,\
    rating,total_bookings,verified,status,epk_url,press_quotes,\
    past_performances,social_links
    """
}
