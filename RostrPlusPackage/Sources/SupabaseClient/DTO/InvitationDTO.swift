// InvitationDTO.swift
//
// Codable mirror of public.invitations. Promoters insert one of these
// to invite an artist (or another promoter) to the platform; the row
// gets a server-side token that the recipient uses to claim the
// account on first sign-in.
//
// RLS allows the inviter to read + write their own invitations.

import Foundation

public struct InvitationDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let invitedBy: UUID?
    public let email: String
    public let name: String?
    public let role: String?
    public let message: String?
    public let status: String?
    public let token: String?
    public let createdAt: Date?
    public let acceptedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case invitedBy  = "invited_by"
        case email
        case name
        case role
        case message
        case status
        case token
        case createdAt  = "created_at"
        case acceptedAt = "accepted_at"
    }

    public static let selectFields =
        "id,invited_by,email,name,role,message,status,token,created_at,accepted_at"
}
