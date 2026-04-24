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

public struct MockPayment: Identifiable, Hashable, Sendable {
    public let id: String
    public let artist: String
    public let event: String
    public let date: String
    public let amount: String
    public let status: Status
    public enum Status: String, Sendable { case paid, pending, scheduled }
}

public struct MockMessage: Identifiable, Hashable, Sendable {
    public let id: String
    public let from: String    // sender display name or "me"
    public let body: String
    public let time: String
    public let isMine: Bool
}

public struct MockTimelineEvent: Identifiable, Hashable, Sendable {
    public let id: String
    public let when: String
    public let label: String
    public let isActive: Bool
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

    public static let past: [MockBooking] = [
        .init(day: "SAT 20", time: "23:00", artist: "KARIMA-N",  venue: "Cavalli Club",  status: .confirmed, fee: "AED 32K"),
        .init(day: "FRI 12", time: "22:00", artist: "DJ NOVAK",  venue: "Soho Garden",   status: .confirmed, fee: "AED 28K"),
        .init(day: "SAT 06", time: "00:30", artist: "MIRELA",    venue: "WHITE Dubai",   status: .confirmed, fee: "AED 24K")
    ]

    public static let payments: [MockPayment] = [
        .init(id: "p1", artist: "DJ NOVAK",  event: "WHITE Dubai · TUE 24",   date: "24 Apr",  amount: "AED 28,000", status: .paid),
        .init(id: "p2", artist: "KARIMA-N",  event: "Cavalli Club · SAT 28",  date: "28 Apr",  amount: "AED 32,000", status: .scheduled),
        .init(id: "p3", artist: "ORION KAI", event: "Blu Dahlia · FRI 27",    date: "27 Apr",  amount: "SAR 42,000", status: .pending),
        .init(id: "p4", artist: "MIRELA",    event: "WHITE Dubai · SAT 06",   date: "06 Apr",  amount: "AED 24,000", status: .paid)
    ]

    public static let threadMessages: [MockMessage] = [
        .init(id: "m1", from: "DJ NOVAK", body: "Good morning — quick one on soundcheck.",                         time: "11:02", isMine: false),
        .init(id: "m2", from: "me",       body: "Shoot.",                                                          time: "11:04", isMine: true),
        .init(id: "m3", from: "DJ NOVAK", body: "Can we push to 21:00 instead of 20:00? Flight lands at 18:40.",   time: "11:05", isMine: false),
        .init(id: "m4", from: "me",       body: "Works for us. I'll loop the venue.",                              time: "11:08", isMine: true),
        .init(id: "m5", from: "DJ NOVAK", body: "Thanks — sending updated rider after lunch.",                     time: "11:09", isMine: false)
    ]

    public static let bookingTimeline: [MockTimelineEvent] = [
        .init(id: "t1", when: "Apr 14 · 10:22", label: "Booking request sent",           isActive: false),
        .init(id: "t2", when: "Apr 14 · 14:08", label: "Artist accepted",                isActive: false),
        .init(id: "t3", when: "Apr 15 · 09:41", label: "Contract drafted",               isActive: false),
        .init(id: "t4", when: "Apr 15 · 11:17", label: "Artist signed",                  isActive: false),
        .init(id: "t5", when: "Apr 15 · 16:02", label: "Promoter signed · countersigned", isActive: true),
        .init(id: "t6", when: "Event · TUE 24", label: "Performance",                    isActive: false)
    ]
}
