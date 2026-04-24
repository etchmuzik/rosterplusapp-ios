// MessageDTO.swift
//
// Codable mirror of public.messages. Messages are 1:1 bound to a booking
// (every thread is about a booking). The "thread" concept lives entirely
// on the client — we derive it by grouping messages by booking_id.
//
// RLS on public.messages restricts SELECT to sender or receiver, so
// clients can never read another user's conversations.

import Foundation

public struct MessageDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let senderID: UUID?
    public let receiverID: UUID?
    public let bookingID: UUID?
    public let content: String
    public let read: Bool?
    public let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case senderID   = "sender_id"
        case receiverID = "receiver_id"
        case bookingID  = "booking_id"
        case content
        case read
        case createdAt  = "created_at"
    }

    public static let selectFields =
        "id,sender_id,receiver_id,booking_id,content,read,created_at"
}
