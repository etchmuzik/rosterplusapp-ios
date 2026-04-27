// ContractsStore.swift
//
// Fetches + caches a single contract row keyed by booking id, then
// exposes the two mutations the view needs:
//
//   - sign(as:)     — flips promoter_signed or artist_signed; if the
//                     other side is already signed, also sets
//                     status='signed' + signed_at = now.
//   - send()        — promoter dispatches a draft contract; flips
//                     status from 'draft' to 'sent'.
//
// Mirrors the web app's `DB.signContract` semantics
// (rosterplus-deploy/assets/js/app.js) so contracts signed on iOS
// reflect immediately when the counterparty refreshes the web view.

import Foundation
import Observation
import Supabase

/// Display-friendly snapshot of a contract.
public struct ContractRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let bookingID: UUID?
    public let title: String
    public let content: String
    public let status: Status
    public let promoterSigned: Bool
    public let artistSigned: Bool
    public let promoterSignedAt: Date?
    public let artistSignedAt: Date?
    public let signedAt: Date?
    public let createdAt: Date?

    public enum Status: String, Sendable {
        case draft, sent, signed, expired, cancelled, unknown

        init(raw: String?) {
            switch raw {
            case "draft":     self = .draft
            case "sent":      self = .sent
            case "signed":    self = .signed
            case "expired":   self = .expired
            case "cancelled": self = .cancelled
            default:          self = .unknown
            }
        }
    }
}

@Observable
@MainActor
public final class ContractsStore {

    public enum State {
        case idle
        case loading(UUID)
        case loaded(ContractRow)
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var lastError: String?

    /// Cache keyed by the contract row's UUID.
    public private(set) var cache: [UUID: ContractRow] = [:]

    private let client = RostrSupabase.shared
    private var inFlight: Set<UUID> = []

    public init() {}

    /// Drop cached contracts. Called on sign-out so the next signed-in
    /// user doesn't see the previous user's contracts.
    public func reset() {
        inFlight.removeAll()
        cache.removeAll()
        lastError = nil
        state = .idle
    }

    // MARK: — Fetch

    /// Pull the contract belonging to a booking. The view passes the
    /// booking id (from the route) and we resolve via booking_id.
    public func fetch(forBookingID bookingID: UUID) {
        if inFlight.contains(bookingID) { return }
        inFlight.insert(bookingID)

        Task { [weak self] in
            guard let self else { return }
            defer { self.inFlight.remove(bookingID) }
            do {
                let dtos: [ContractDTO] = try await client
                    .from("contracts")
                    .select(ContractDTO.selectFields)
                    .eq("booking_id", value: bookingID)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                if let dto = dtos.first {
                    let row = Self.rowFromDTO(dto)
                    self.cache[row.id] = row
                    self.state = .loaded(row)
                } else {
                    self.state = .failed("No contract for this booking yet.")
                }
            } catch {
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: — Mutations

    public enum Signer: String, Sendable {
        case promoter, artist
    }

    /// Sign the contract on behalf of the current user. Mirrors the
    /// web `DB.signContract`: PATCHes the role-specific flag plus a
    /// timestamp; if the *other* side is already signed, also flips
    /// status to 'signed' and stamps signed_at.
    public func sign(contractID: UUID, as signer: Signer) async {
        lastError = nil
        guard var existing = cache[contractID] else {
            lastError = "Contract isn't loaded yet."
            return
        }

        // Optimistic: mark this side signed locally + recompute status.
        let now = Date()
        let nextPromoterSigned = signer == .promoter ? true : existing.promoterSigned
        let nextArtistSigned   = signer == .artist   ? true : existing.artistSigned
        let bothNow = nextPromoterSigned && nextArtistSigned
        existing = ContractRow(
            id: existing.id,
            bookingID: existing.bookingID,
            title: existing.title,
            content: existing.content,
            status: bothNow ? .signed : existing.status,
            promoterSigned: nextPromoterSigned,
            artistSigned: nextArtistSigned,
            promoterSignedAt: signer == .promoter ? now : existing.promoterSignedAt,
            artistSignedAt:   signer == .artist   ? now : existing.artistSignedAt,
            signedAt: bothNow ? now : existing.signedAt,
            createdAt: existing.createdAt
        )
        cache[contractID] = existing
        state = .loaded(existing)

        // Persist. We send only the fields we own — the trigger /
        // server-side timestamp can fill in the rest if it wants.
        struct Patch: Encodable {
            let promoter_signed: Bool?
            let artist_signed: Bool?
            let promoter_signed_at: String?
            let artist_signed_at: String?
            let status: String?
            let signed_at: String?
        }
        let iso = ISO8601DateFormatter().string(from: now)
        let patch = Patch(
            promoter_signed: signer == .promoter ? true : nil,
            artist_signed:   signer == .artist   ? true : nil,
            promoter_signed_at: signer == .promoter ? iso : nil,
            artist_signed_at:   signer == .artist   ? iso : nil,
            status:    bothNow ? "signed" : nil,
            signed_at: bothNow ? iso : nil
        )

        do {
            _ = try await client
                .from("contracts")
                .update(patch)
                .eq("id", value: contractID)
                .execute()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Promoter dispatches a draft contract. Optimistic flip of
    /// status from 'draft' to 'sent'.
    public func send(contractID: UUID) async {
        lastError = nil
        guard var existing = cache[contractID] else {
            lastError = "Contract isn't loaded yet."
            return
        }
        guard existing.status == .draft else { return }

        existing = ContractRow(
            id: existing.id,
            bookingID: existing.bookingID,
            title: existing.title,
            content: existing.content,
            status: .sent,
            promoterSigned: existing.promoterSigned,
            artistSigned: existing.artistSigned,
            promoterSignedAt: existing.promoterSignedAt,
            artistSignedAt: existing.artistSignedAt,
            signedAt: existing.signedAt,
            createdAt: existing.createdAt
        )
        cache[contractID] = existing
        state = .loaded(existing)

        struct Patch: Encodable { let status: String }
        do {
            _ = try await client
                .from("contracts")
                .update(Patch(status: "sent"))
                .eq("id", value: contractID)
                .execute()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: — Helpers

    private static func rowFromDTO(_ dto: ContractDTO) -> ContractRow {
        ContractRow(
            id: dto.id,
            bookingID: dto.bookingID,
            title: dto.title ?? "Performance Contract",
            content: dto.content ?? "",
            status: ContractRow.Status(raw: dto.status),
            promoterSigned: dto.promoterSigned ?? false,
            artistSigned: dto.artistSigned ?? false,
            promoterSignedAt: dto.promoterSignedAt,
            artistSignedAt: dto.artistSignedAt,
            signedAt: dto.signedAt,
            createdAt: dto.createdAt
        )
    }

    #if DEBUG
    /// Test seam — seed the cache + state without touching Supabase.
    public func _testLoad(_ row: ContractRow) {
        cache[row.id] = row
        state = .loaded(row)
    }
    #endif
}
