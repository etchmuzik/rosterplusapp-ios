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

    /// Raw decode of the `notification_prefs` JSONB column. `nil` when the
    /// column is null/absent (legacy rows). Prefer the `prefs` accessor,
    /// which resolves nil to the opt-out-safe all-on default.
    public let notificationPrefs: NotificationPrefs?

    /// Notification preferences with the legacy/null fallback applied.
    /// Never suppresses a channel just because the column was empty.
    public var prefs: NotificationPrefs {
        notificationPrefs ?? .defaultAllOn
    }

    /// Explicit memberwise init with `notificationPrefs` defaulting to
    /// `nil`. Lets every existing positional call site (and test fixture)
    /// stay unchanged while the new column rides along as an optional.
    public init(
        id: UUID,
        email: String,
        displayName: String?,
        role: String,
        avatarURL: String?,
        phone: String?,
        company: String?,
        bio: String?,
        city: String?,
        notificationPrefs: NotificationPrefs? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.avatarURL = avatarURL
        self.phone = phone
        self.company = company
        self.bio = bio
        self.city = city
        self.notificationPrefs = notificationPrefs
    }

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
        case notificationPrefs = "notification_prefs"
    }

    public static let selectFields =
        "id,email,display_name,role,avatar_url,phone,company,bio,city,notification_prefs"
}
