// ArtistDTO.swift
//
// Codable mirror of public.artists. Used by RosterStore + artist detail
// + EPK. Pull fields only when we need them — extend this shape as
// individual screens come online in later waves.

import Foundation

public struct ArtistDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let stageName: String?
    public let genre: [String]?
    public let citiesActive: [String]?
    public let baseFee: Double?
    public let currency: String?
    public let rating: Double?
    public let verified: Bool?
    public let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case stageName    = "stage_name"
        case genre
        case citiesActive = "cities_active"
        case baseFee      = "base_fee"
        case currency
        case rating
        case verified
        case status
    }

    /// Comma-separated column list for PostgREST .select(). Kept here so
    /// any store fetching artists pulls the same fields and DTOs stay in
    /// lockstep.
    public static let selectFields =
        "id,stage_name,genre,cities_active,base_fee,currency,rating,verified,status"
}
