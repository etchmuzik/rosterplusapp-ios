// ProfileStore.swift
//
// Loads + persists the signed-in user's public.profiles row. Powers
// ProfileEditView (bio, display name, phone, city, company) and
// SettingsView's profile header + edit controls.
//
// RLS on public.profiles allows a user to read/update only their own
// row, so every mutation is keyed off auth.uid().

import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class ProfileStore {

    public enum State {
        case idle
        case loading
        case loaded(ProfileDTO)
        case failed(String)
    }

    public private(set) var state: State = .idle

    /// Last known save error, surfaced inline by forms. nil after a
    /// successful save (or before the first attempt).
    public private(set) var lastError: String?

    private let client = RostrSupabase.shared
    private var inFlight: Task<Void, Never>?

    public init() {}

    // MARK: — Read

    public var current: ProfileDTO? {
        if case .loaded(let p) = state { return p }
        return nil
    }

    public func refresh(for userID: UUID) {
        if inFlight != nil { return }

        inFlight = Task { [weak self] in
            guard let self else { return }
            self.state = .loading
            do {
                let dto: ProfileDTO = try await client
                    .from("profiles")
                    .select(ProfileDTO.selectFields)
                    .eq("id", value: userID)
                    .single()
                    .execute()
                    .value
                self.state = .loaded(dto)
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.inFlight = nil
        }
    }

    // MARK: — Write

    /// Patch the avatar URL column only. Separate from the text-field
    /// update() because avatar uploads are always a two-step flow
    /// (upload first, then patch the URL) and we don't want to conflate
    /// them with the form's other fields.
    public func updateAvatarURL(_ url: String, userID: UUID) async {
        lastError = nil
        guard case .loaded(let existing) = state else {
            lastError = "Profile not loaded yet."
            return
        }
        let optimistic = ProfileDTO(
            id: existing.id,
            email: existing.email,
            displayName: existing.displayName,
            role: existing.role,
            avatarURL: url,
            phone: existing.phone,
            company: existing.company,
            bio: existing.bio,
            city: existing.city
        )
        state = .loaded(optimistic)

        struct Patch: Encodable { let avatar_url: String }
        do {
            _ = try await client
                .from("profiles")
                .update(Patch(avatar_url: url))
                .eq("id", value: userID)
                .execute()
        } catch {
            lastError = error.localizedDescription
            state = .loaded(existing)
        }
    }

    /// Patch a subset of the profile row. Any nil field is left alone
    /// (we don't wipe columns the caller didn't touch). Optimistic —
    /// flips the local state on `loaded` instantly, rolls back on
    /// failure with a surfaced error.
    public func update(
        userID: UUID,
        displayName: String? = nil,
        phone: String? = nil,
        company: String? = nil,
        bio: String? = nil,
        city: String? = nil
    ) async {
        lastError = nil
        guard case .loaded(let existing) = state else {
            lastError = "Profile not loaded yet."
            return
        }
        // Optimistic local update.
        let optimistic = Self.merge(
            existing,
            displayName: displayName,
            phone: phone,
            company: company,
            bio: bio,
            city: city
        )
        state = .loaded(optimistic)

        struct Patch: Encodable {
            let display_name: String?
            let phone: String?
            let company: String?
            let bio: String?
            let city: String?
        }
        let patch = Patch(
            display_name: displayName,
            phone: phone,
            company: company,
            bio: bio,
            city: city
        )

        do {
            _ = try await client
                .from("profiles")
                .update(patch)
                .eq("id", value: userID)
                .execute()
        } catch {
            lastError = error.localizedDescription
            // Rollback to server truth on failure.
            state = .loaded(existing)
        }
    }

    // MARK: — Helpers

    /// Value-type merge — builds a new ProfileDTO carrying only the
    /// non-nil patch fields over the existing row.
    private static func merge(
        _ existing: ProfileDTO,
        displayName: String?,
        phone: String?,
        company: String?,
        bio: String?,
        city: String?
    ) -> ProfileDTO {
        ProfileDTO(
            id: existing.id,
            email: existing.email,
            displayName: displayName ?? existing.displayName,
            role: existing.role,
            avatarURL: existing.avatarURL,
            phone: phone ?? existing.phone,
            company: company ?? existing.company,
            bio: bio ?? existing.bio,
            city: city ?? existing.city
        )
    }

    #if DEBUG
    public func _testLoad(_ dto: ProfileDTO) {
        state = .loaded(dto)
    }
    #endif
}
