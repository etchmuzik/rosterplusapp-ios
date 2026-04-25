// ContractDTO.swift
//
// Codable mirror of public.contracts. Each row is anchored to a
// booking via booking_id and has independent promoter_signed +
// artist_signed flags. When both flip true the trigger / our update
// helper sets `status = 'signed'` + `signed_at`.
//
// RLS lets the booking's promoter or artist read + update; everyone
// else gets nothing.

import Foundation

public struct ContractDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let bookingID: UUID?
    public let title: String?
    public let content: String?
    public let status: String?
    public let promoterSigned: Bool?
    public let artistSigned: Bool?
    public let signedAt: Date?
    public let expiresAt: Date?
    public let pdfURL: String?
    public let createdAt: Date?
    public let promoterSignedAt: Date?
    public let artistSignedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case bookingID         = "booking_id"
        case title
        case content
        case status
        case promoterSigned    = "promoter_signed"
        case artistSigned      = "artist_signed"
        case signedAt          = "signed_at"
        case expiresAt         = "expires_at"
        case pdfURL            = "pdf_url"
        case createdAt         = "created_at"
        case promoterSignedAt  = "promoter_signed_at"
        case artistSignedAt    = "artist_signed_at"
    }

    public static let selectFields = """
    id,booking_id,title,content,status,promoter_signed,artist_signed,\
    signed_at,expires_at,pdf_url,created_at,promoter_signed_at,artist_signed_at
    """
}
