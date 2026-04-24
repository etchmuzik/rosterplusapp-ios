// NotificationDTO.swift
//
// Codable mirror of public.notifications. Every row is scoped to one
// user via user_id — RLS enforces that on the server, we also filter
// client-side so the eq() in NotificationsStore is belt-and-braces.

import Foundation

public struct NotificationDTO: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let userID: UUID?
    public let type: String
    public let title: String
    public let body: String?
    public let href: String?
    public let read: Bool?
    public let createdAt: Date?
    public let bookingID: UUID?
    public let contractID: UUID?
    public let paymentID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userID     = "user_id"
        case type
        case title
        case body
        case href
        case read
        case createdAt  = "created_at"
        case bookingID  = "booking_id"
        case contractID = "contract_id"
        case paymentID  = "payment_id"
    }

    public static let selectFields =
        "id,user_id,type,title,body,href,read,created_at,booking_id,contract_id,payment_id"
}
