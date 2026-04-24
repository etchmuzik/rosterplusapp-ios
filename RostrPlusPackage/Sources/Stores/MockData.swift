// MockData.swift
//
// Mirrors the `artists`, `upcoming`, and `inbox` arrays at the top of
// ios-app.jsx. Used by previews + the v0 HomeScreen until the Supabase
// DTOs and fetch flow are wired up.

import Foundation

public struct MockArtist: Identifiable, Hashable, Sendable {
    public let id: Int
    public let stage: String
    public let genre: String
    public let city: String
    public let rating: Double
    public let avail: Avail
    public let featured: Bool

    public enum Avail: String, Sendable {
        case avail, busy, booked
    }
}

public struct MockBooking: Identifiable, Hashable, Sendable {
    public var id: String { day + artist }
    public let day: String
    public let time: String
    public let artist: String
    public let venue: String
    public let status: Status
    public let fee: String

    public enum Status: String, Sendable {
        case confirmed, pending, contracted
    }
}

public struct MockInboxThread: Identifiable, Hashable, Sendable {
    public var id: String { who }
    public let who: String
    public let last: String
    public let time: String
    public let unread: Int
}

public enum MockData {
    public static let artists: [MockArtist] = [
        .init(id: 1, stage: "DJ NOVAK",  genre: "Tech House",     city: "Dubai",     rating: 4.9, avail: .avail,  featured: false),
        .init(id: 2, stage: "MIRELA",    genre: "Deep House",     city: "Dubai",     rating: 4.8, avail: .busy,   featured: false),
        .init(id: 3, stage: "ORION KAI", genre: "Afro House",     city: "Riyadh",    rating: 5.0, avail: .avail,  featured: true),
        .init(id: 4, stage: "KARIMA-N",  genre: "Melodic Techno", city: "Dubai",     rating: 4.7, avail: .avail,  featured: false),
        .init(id: 5, stage: "SAMI ROUX", genre: "Organic House",  city: "Abu Dhabi", rating: 4.8, avail: .booked, featured: false),
        .init(id: 6, stage: "SIRENE",    genre: "Progressive",    city: "Doha",      rating: 4.9, avail: .avail,  featured: false)
    ]

    public static let upcoming: [MockBooking] = [
        .init(day: "TUE 24", time: "23:00", artist: "DJ NOVAK",  venue: "WHITE Dubai",  status: .confirmed,  fee: "AED 28K"),
        .init(day: "FRI 27", time: "22:00", artist: "ORION KAI", venue: "Blu Dahlia",   status: .pending,    fee: "SAR 42K"),
        .init(day: "SAT 28", time: "00:00", artist: "KARIMA-N",  venue: "Cavalli Club", status: .contracted, fee: "AED 32K")
    ]

    public static let inbox: [MockInboxThread] = [
        .init(who: "MIRELA",      last: "Sending the updated set list by EOD.", time: "14:20",      unread: 2),
        .init(who: "ORION KAI",   last: "Rider approved. Flight confirmed.",    time: "12:02",      unread: 0),
        .init(who: "Soho Garden", last: "Contract countersigned ✓",              time: "Yesterday", unread: 0),
        .init(who: "DJ NOVAK",    last: "Can we push soundcheck to 21:00?",     time: "Mon",        unread: 1)
    ]
}
