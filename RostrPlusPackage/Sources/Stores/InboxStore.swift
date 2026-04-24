// InboxStore.swift
//
// Inbox list + per-thread messages. There is no `threads` table in our
// schema — we derive threads client-side by grouping messages on their
// (booking_id, counterparty_id) pair. The inbox row surfaces the most
// recent message per thread.
//
// The store pulls every message the current user is a party to
// (sender_id = me OR receiver_id = me). RLS enforces the same on the
// server side.

import Foundation
import Observation
import Supabase
import Realtime

/// Display shape for the inbox list (one row per conversation).
public struct InboxThread: Identifiable, Hashable, Sendable {
    /// Synthetic id — booking UUID when present, else counterparty UUID.
    public let id: String
    public let bookingID: UUID?
    public let counterpartyID: UUID
    public let counterpartyName: String
    public let lastMessage: String
    public let lastAt: Date
    public let unread: Int
}

/// Display shape for a single message inside a thread.
public struct ThreadMessage: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let content: String
    public let sentAt: Date
    public let isMine: Bool
}

@Observable
@MainActor
public final class InboxStore {

    public enum State {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    public private(set) var state: State = .idle

    /// Every message the user can see, raw. Views consume the derived
    /// `threads` and `messages(for:)` accessors below.
    private var messages: [MessageDTO] = []

    /// Counterparty display names, keyed by profile id. Populated in
    /// `refresh()` via a single `profiles` fetch once we have the set of
    /// counterparty ids.
    private var profileNames: [UUID: String] = [:]

    private let client = RostrSupabase.shared
    private var inFlight: Task<Void, Never>?
    private var currentUserID: UUID?

    // Realtime — one channel subscribed to messages where receiver_id
    // matches the signed-in user. Rebinds whenever `refresh(for:)`
    // switches users (sign-out + sign-in as someone else).
    private var channel: RealtimeChannelV2?
    private var subscription: RealtimeSubscription?

    public init() {}

    // MARK: — Fetch

    /// Fetch every message this user is a party to. Call once after
    /// sign-in, and again whenever the user pulls-to-refresh.
    public func refresh(for userID: UUID) {
        if inFlight != nil { return }
        currentUserID = userID

        inFlight = Task { [weak self] in
            guard let self else { return }
            self.state = .loading
            do {
                // or(sender.eq,receiver.eq) — PostgREST `or` filter.
                let rows: [MessageDTO] = try await client
                    .from("messages")
                    .select(MessageDTO.selectFields)
                    .or("sender_id.eq.\(userID.uuidString),receiver_id.eq.\(userID.uuidString)")
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                self.messages = rows

                // Resolve counterparty names for everyone in the set.
                let otherIDs = Set(rows.compactMap { msg -> UUID? in
                    guard let s = msg.senderID, let r = msg.receiverID else { return nil }
                    return s == userID ? r : s
                })
                if !otherIDs.isEmpty {
                    struct ProfileRow: Decodable { let id: UUID; let display_name: String? }
                    let ids = otherIDs.map(\.uuidString).joined(separator: ",")
                    let profiles: [ProfileRow] = try await client
                        .from("profiles")
                        .select("id,display_name")
                        .or("id.in.(\(ids))")
                        .execute()
                        .value
                    self.profileNames = Dictionary(
                        uniqueKeysWithValues: profiles.map { ($0.id, $0.display_name ?? "Member") }
                    )
                }
                self.state = .loaded
                await self.subscribeRealtime(for: userID)
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.inFlight = nil
        }
    }

    // MARK: — Realtime

    /// Subscribe to INSERTs on public.messages where I'm the receiver.
    /// New messages prepend so threads reorder instantly and the unread
    /// badge bumps without a refresh.
    private func subscribeRealtime(for userID: UUID) async {
        // Tear any prior channel down so we don't leak sockets.
        await teardownRealtime()

        let ch = client.realtimeV2.channel("messages:in:\(userID.uuidString)")
        let sub = ch.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "receiver_id=eq.\(userID.uuidString)"
        ) { [weak self] action in
            Task { @MainActor [weak self] in
                self?.handleInboundInsert(action)
            }
        }
        await ch.subscribe()
        self.channel = ch
        self.subscription = sub
    }

    /// Decode + prepend. Dedupes against optimistic rows that the
    /// sender's send() already inserted locally.
    private func handleInboundInsert(_ action: InsertAction) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let msg = try action.decodeRecord(as: MessageDTO.self, decoder: decoder)
            guard !messages.contains(where: { $0.id == msg.id }) else { return }
            messages.insert(msg, at: 0)

            // Best-effort name lookup if we've never seen this sender.
            if let sender = msg.senderID, profileNames[sender] == nil {
                Task { [weak self] in
                    guard let self else { return }
                    struct ProfileRow: Decodable { let id: UUID; let display_name: String? }
                    do {
                        let rows: [ProfileRow] = try await client
                            .from("profiles")
                            .select("id,display_name")
                            .eq("id", value: sender)
                            .limit(1)
                            .execute()
                            .value
                        if let name = rows.first?.display_name {
                            self.profileNames[sender] = name
                        }
                    } catch {
                        // Ignored — name stays as "Member" fallback.
                    }
                }
            }
        } catch {
            #if DEBUG
            print("InboxStore.handleInboundInsert decode failed:", error)
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

    /// One row per (booking_id, counterparty_id) pair. Most-recent first.
    public var threads: [InboxThread] {
        guard let me = currentUserID else { return [] }
        var bucketed: [String: [MessageDTO]] = [:]
        for m in messages {
            guard
                let sender = m.senderID,
                let receiver = m.receiverID,
                let created = m.createdAt
            else { continue }
            _ = created
            let other = sender == me ? receiver : sender
            let key = (m.bookingID?.uuidString ?? "none") + "|" + other.uuidString
            bucketed[key, default: []].append(m)
        }

        return bucketed.values.compactMap { group -> InboxThread? in
            // Group is already sorted newest-first (outer fetch).
            guard
                let latest = group.first,
                let sender = latest.senderID,
                let receiver = latest.receiverID,
                let sentAt = latest.createdAt
            else { return nil }
            let other = sender == me ? receiver : sender
            let unread = group.reduce(0) { partial, msg in
                partial + ((msg.receiverID == me && (msg.read ?? false) == false) ? 1 : 0)
            }
            let name = profileNames[other] ?? "Member"
            let id = (latest.bookingID?.uuidString ?? other.uuidString)
            return InboxThread(
                id: id,
                bookingID: latest.bookingID,
                counterpartyID: other,
                counterpartyName: name,
                lastMessage: latest.content,
                lastAt: sentAt,
                unread: unread
            )
        }
        .sorted { $0.lastAt > $1.lastAt }
    }

    /// Total unread across all threads.
    public var unreadCount: Int {
        threads.reduce(0) { $0 + $1.unread }
    }

    /// Messages in one thread, ascending by time (chat render order).
    public func messages(for threadID: String) -> [ThreadMessage] {
        guard let me = currentUserID else { return [] }
        let match = messages.filter { msg in
            let key = (msg.bookingID?.uuidString ?? "none") + "|" + otherID(msg, me: me).uuidString
            return key == threadID
                || msg.bookingID?.uuidString == threadID
                || otherID(msg, me: me).uuidString == threadID
        }
        return match
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            .map { msg in
                ThreadMessage(
                    id: msg.id,
                    content: msg.content,
                    sentAt: msg.createdAt ?? Date.distantPast,
                    isMine: msg.senderID == me
                )
            }
    }

    /// Counterparty display name for a given thread — used by
    /// ThreadView's header when loading a thread on deep-link.
    public func counterpartyName(for threadID: String) -> String {
        threads.first { $0.id == threadID }?.counterpartyName ?? "Conversation"
    }

    // MARK: — Send

    /// Optimistically append a message to the local store and mirror it
    /// to the server. If the insert fails, the optimistic row stays on
    /// screen (with a stale timestamp) — the next refresh will reconcile.
    public func send(
        content: String,
        to receiverID: UUID,
        bookingID: UUID?
    ) {
        guard let me = currentUserID else { return }
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Optimistic local insert.
        let temp = MessageDTO(
            id: UUID(),
            senderID: me,
            receiverID: receiverID,
            bookingID: bookingID,
            content: trimmed,
            read: false,
            createdAt: Date()
        )
        messages.insert(temp, at: 0)

        Task { [weak self] in
            guard let self else { return }
            struct Insert: Encodable {
                let sender_id: UUID
                let receiver_id: UUID
                let booking_id: UUID?
                let content: String
            }
            do {
                _ = try await client
                    .from("messages")
                    .insert(Insert(
                        sender_id: me,
                        receiver_id: receiverID,
                        booking_id: bookingID,
                        content: trimmed
                    ))
                    .execute()
            } catch {
                // Silently swallow — the optimistic row stays. A real
                // app would flag the row as failed; for now we log.
                #if DEBUG
                print("InboxStore.send failed:", error)
                #endif
            }
        }
    }

    // MARK: — Helpers

    private func otherID(_ msg: MessageDTO, me: UUID) -> UUID {
        if msg.senderID == me { return msg.receiverID ?? me }
        return msg.senderID ?? me
    }

    #if DEBUG
    /// Test seam — seed both the messages pool and the name lookup so
    /// filter logic can be exercised without hitting Supabase.
    public func _testLoad(
        userID: UUID,
        messages: [MessageDTO],
        names: [UUID: String]
    ) {
        self.currentUserID = userID
        self.messages = messages
        self.profileNames = names
        self.state = .loaded
    }
    #endif
}
