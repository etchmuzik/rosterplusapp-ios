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

/// Narrow seam for the writes ContractsStore performs against
/// public.contracts. Production wires a Supabase-backed impl that
/// PATCHes the row; tests inject a mock so optimistic-update +
/// rollback branches can be observed without a live session.
public protocol ContractWriter: Sendable {
    func patchContract<Patch: Encodable & Sendable>(
        _ patch: Patch, contractID: UUID
    ) async throws
}

public struct SupabaseContractWriter: ContractWriter {
    public init() {}

    public func patchContract<Patch: Encodable & Sendable>(
        _ patch: Patch, contractID: UUID
    ) async throws {
        _ = try await RostrSupabase.shared
            .from("contracts")
            .update(patch)
            .eq("id", value: contractID)
            .execute()
    }
}

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
    private let writer: any ContractWriter
    private var inFlight: Set<UUID> = []

    public init(writer: any ContractWriter = SupabaseContractWriter()) {
        self.writer = writer
    }

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
        #if DEBUG
        // Screenshot mode: serve the single seeded contract from cache
        // instead of networking (which would 'No contract yet').
        if ScreenshotSeed.isActive {
            if let row = cache.values.first(where: { $0.bookingID == bookingID })
                ?? cache.values.first {
                state = .loaded(row)
            }
            return
        }
        #endif
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
    /// status to 'signed' and stamps signed_at. Optimistic — rolls
    /// back to the prior row on failure.
    public func sign(contractID: UUID, as signer: Signer) async {
        lastError = nil
        guard let snapshot = cache[contractID] else {
            lastError = "Contract isn't loaded yet."
            return
        }

        // Optimistic: mark this side signed locally + recompute status.
        let now = Date()
        let nextPromoterSigned = signer == .promoter ? true : snapshot.promoterSigned
        let nextArtistSigned   = signer == .artist   ? true : snapshot.artistSigned
        let bothNow = nextPromoterSigned && nextArtistSigned
        let optimistic = ContractRow(
            id: snapshot.id,
            bookingID: snapshot.bookingID,
            title: snapshot.title,
            content: snapshot.content,
            status: bothNow ? .signed : snapshot.status,
            promoterSigned: nextPromoterSigned,
            artistSigned: nextArtistSigned,
            promoterSignedAt: signer == .promoter ? now : snapshot.promoterSignedAt,
            artistSignedAt:   signer == .artist   ? now : snapshot.artistSignedAt,
            signedAt: bothNow ? now : snapshot.signedAt,
            createdAt: snapshot.createdAt
        )
        cache[contractID] = optimistic
        state = .loaded(optimistic)

        // Persist. We send only the fields we own — the trigger /
        // server-side timestamp can fill in the rest if it wants.
        struct Patch: Encodable, Sendable {
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
            try await writer.patchContract(patch, contractID: contractID)
        } catch {
            lastError = error.localizedDescription
            // Rollback to the pre-sign snapshot so the UI doesn't keep
            // showing a signature that didn't land.
            cache[contractID] = snapshot
            state = .loaded(snapshot)
        }
    }

    /// Promoter dispatches a draft contract. Optimistic flip of
    /// status from 'draft' to 'sent'; rolls back on failure.
    public func send(contractID: UUID) async {
        lastError = nil
        guard let snapshot = cache[contractID] else {
            lastError = "Contract isn't loaded yet."
            return
        }
        guard snapshot.status == .draft else { return }

        let optimistic = ContractRow(
            id: snapshot.id,
            bookingID: snapshot.bookingID,
            title: snapshot.title,
            content: snapshot.content,
            status: .sent,
            promoterSigned: snapshot.promoterSigned,
            artistSigned: snapshot.artistSigned,
            promoterSignedAt: snapshot.promoterSignedAt,
            artistSignedAt: snapshot.artistSignedAt,
            signedAt: snapshot.signedAt,
            createdAt: snapshot.createdAt
        )
        cache[contractID] = optimistic
        state = .loaded(optimistic)

        struct Patch: Encodable, Sendable { let status: String }
        do {
            try await writer.patchContract(Patch(status: "sent"), contractID: contractID)
        } catch {
            lastError = error.localizedDescription
            cache[contractID] = snapshot
            state = .loaded(snapshot)
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
