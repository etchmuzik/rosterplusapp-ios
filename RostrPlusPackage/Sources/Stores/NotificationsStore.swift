// NotificationsStore.swift
//
// Fetches + caches the signed-in user's notifications. Partitioned into
// unread + read so the view can render two sections without re-filtering
// every frame. RLS enforces user_id = auth.uid() server-side.

import Foundation
import Observation
import Supabase

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

    public init() {}

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
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.inFlight = nil
        }
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
