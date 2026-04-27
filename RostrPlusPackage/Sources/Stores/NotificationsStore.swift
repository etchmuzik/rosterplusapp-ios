// NotificationsStore.swift
//
// Fetches + caches the signed-in user's notifications. Partitioned into
// unread + read so the view can render two sections without re-filtering
// every frame. RLS enforces user_id = auth.uid() server-side.

import Foundation
import Observation
import OSLog
import Supabase
import Realtime

private let log = Logger(subsystem: "io.rosterplus.app", category: "NotificationsStore")

/// Display shape for a notification row. Maps server-side `type` onto
/// a small enum the view switches on for icon + tint.
public struct NotificationRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let kind: Kind
    public let title: String
    public let body: String
    public let createdAt: Date
    public let read: Bool
    public let href: String?

    public enum Kind: String, Sendable {
        case booking, message, payment, contract, review, calendar, profile, other
    }
}

@Observable
@MainActor
public final class NotificationsStore {

    public enum State {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var items: [NotificationRow] = []

    private let client = RostrSupabase.shared
    private var inFlight: Task<Void, Never>?

    // Realtime — one channel subscribed to new notifications scoped
    // to the signed-in user. Rebinds on user switch.
    private var channel: RealtimeChannelV2?
    private var subscription: RealtimeSubscription?

    public init() {}

    /// Drop cached rows, unsubscribe from realtime, cancel any in-flight
    /// fetch. Called on sign-out so the next signed-in user doesn't see
    /// the previous user's notifications or receive their realtime
    /// inserts.
    public func reset() async {
        inFlight?.cancel()
        inFlight = nil
        if let ch = channel { await ch.unsubscribe() }
        channel = nil
        subscription = nil
        items = []
        state = .idle
    }

    // MARK: — Fetch

    public func refresh(for userID: UUID) {
        if inFlight != nil { return }

        inFlight = Task { [weak self] in
            guard let self else { return }
            self.state = .loading
            do {
                let rows: [NotificationDTO] = try await client
                    .from("notifications")
                    .select(NotificationDTO.selectFields)
                    .eq("user_id", value: userID)
                    .order("created_at", ascending: false)
                    .limit(50)
                    .execute()
                    .value
                self.items = rows.map(Self.rowFromDTO)
                self.state = .loaded
                await self.subscribeRealtime(for: userID)
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.inFlight = nil
        }
    }

    // MARK: — Realtime

    /// Listen for INSERTs scoped to this user and prepend new rows.
    /// Dedupes on id so a race with the initial fetch is harmless.
    private func subscribeRealtime(for userID: UUID) async {
        await teardownRealtime()
        let ch = client.realtimeV2.channel("notifications:\(userID.uuidString)")
        let sub = ch.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "notifications",
            filter: "user_id=eq.\(userID.uuidString)"
        ) { [weak self] action in
            Task { @MainActor [weak self] in
                self?.handleInsert(action)
            }
        }
        do {
            try await ch.subscribeWithError()
        } catch {
            log.error("subscribeRealtime failed: \(error.localizedDescription, privacy: .public)")
        }
        self.channel = ch
        self.subscription = sub
    }

    private func handleInsert(_ action: InsertAction) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let dto = try action.decodeRecord(as: NotificationDTO.self, decoder: decoder)
            let row = Self.rowFromDTO(dto)
            guard !items.contains(where: { $0.id == row.id }) else { return }
            items.insert(row, at: 0)
        } catch {
            #if DEBUG
            log.error("handleInsert decode failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    private func teardownRealtime() async {
        subscription?.cancel()
        subscription = nil
        if let ch = channel {
            await ch.unsubscribe()
        }
        channel = nil
    }

    // MARK: — Derived

    public var unread: [NotificationRow] { items.filter { !$0.read } }
    public var read: [NotificationRow]   { items.filter {  $0.read } }
    public var unreadCount: Int           { unread.count }

    // MARK: — Mutations

    /// Optimistically mark one notification read, then mirror to server.
    public func markRead(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }), !items[idx].read else { return }
        items[idx] = NotificationRow(
            id: items[idx].id,
            kind: items[idx].kind,
            title: items[idx].title,
            body: items[idx].body,
            createdAt: items[idx].createdAt,
            read: true,
            href: items[idx].href
        )
        Task { [weak self] in
            guard let self else { return }
            struct Patch: Encodable { let read: Bool }
            do {
                _ = try await client
                    .from("notifications")
                    .update(Patch(read: true))
                    .eq("id", value: id)
                    .execute()
            } catch {
                // Optimistic stays; next refresh reconciles.
            }
        }
    }

    // MARK: — Helpers

    private static func rowFromDTO(_ dto: NotificationDTO) -> NotificationRow {
        NotificationRow(
            id: dto.id,
            kind: NotificationRow.Kind(rawValue: dto.type) ?? .other,
            title: dto.title,
            body: dto.body ?? "",
            createdAt: dto.createdAt ?? Date.distantPast,
            read: dto.read ?? false,
            href: dto.href
        )
    }

    #if DEBUG
    public func _testLoad(_ rows: [NotificationRow]) {
        self.items = rows
        self.state = .loaded
    }
    #endif
}
