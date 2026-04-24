// ProfileDTO.swift
//
// Codable mirror of public.profiles. Each auth.users row has a matching
// profile row (via handle_new_user trigger), so we can always fetch
// one by auth.uid(). RLS lets a user read+update only their own row.

import Foundation

public struct ProfileDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let email: String
    public let displayName: String?
    public let role: String
    public let avatarURL: String?
    public let phone: String?
    public let company: String?
    public let bio: String?
    public let city: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case role
        case avatarURL   = "avatar_url"
        case phone
        case company
        case bio
        case city
    }

    public static let selectFields =
        "id,email,display_name,role,avatar_url,phone,company,bio,city"
}
