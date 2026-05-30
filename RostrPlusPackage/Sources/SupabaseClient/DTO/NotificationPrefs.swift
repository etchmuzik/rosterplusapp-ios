// NotificationPrefs.swift
//
// Codable mirror of the `profiles.notification_prefs` JSONB column.
// Five boolean switches the dispatch side honours (send-push v4,
// send-email v13, send-booking-reminders v5). The web client at
// /settings.html is the reference writer — iOS must encode the SAME
// five keys so a user who opts out on one surface is opted out on both.
//
// Contract (shared/SCHEMA_NOTES.md → profiles.notification_prefs):
//   email     — master email switch
//   bookings  — booking_* push + email
//   messages  — message_* push
//   contracts — contract_* push + email
//   payouts   — payout_*/payment_* push + email
//
// OPT-OUT MODEL: every key defaults to `true`. A missing key (legacy
// rows written before the 2026-05-18 migration) reads as `true` — never
// silently suppress a notification because we couldn't read a pref.
//
// Decoding has to be lenient: the column may be `null`, an empty object,
// or a partial object. A synthesised Codable init would THROW on the
// first missing key and fail the entire ProfileDTO decode, blacking out
// the whole Settings screen. So we decode key-by-key with a fallback.

import Foundation

public struct NotificationPrefs: Codable, Hashable, Sendable {
    public var email: Bool
    public var bookings: Bool
    public var messages: Bool
    public var contracts: Bool
    public var payouts: Bool

    public init(
        email: Bool,
        bookings: Bool,
        messages: Bool,
        contracts: Bool,
        payouts: Bool
    ) {
        self.email = email
        self.bookings = bookings
        self.messages = messages
        self.contracts = contracts
        self.payouts = payouts
    }

    enum CodingKeys: String, CodingKey {
        case email, bookings, messages, contracts, payouts
    }

    // MARK: — Lenient decode
    //
    // Default-resolution rule: missing OR explicitly-null key == `true`.
    // This mirrors the web reference writer (settings.html:409
    // `prefs[key] !== false`) so a legacy/partial row renders identical
    // toggle states on both surfaces, and matches the dispatch side,
    // which also reads a missing key as "send" (opt-out safety).
    //
    // `decodeIfPresent` returns nil for both an absent key and a JSON
    // null; either way we fall through to `true`. A non-bool value (the
    // column should only ever hold bools, but be defensive) makes the
    // `try?` itself nil — still `true`, never a thrown decode that would
    // black out the whole ProfileDTO.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func flag(_ key: CodingKeys) -> Bool {
            ((try? c.decodeIfPresent(Bool.self, forKey: key)) ?? nil) ?? true
        }
        self.email     = flag(.email)
        self.bookings  = flag(.bookings)
        self.messages  = flag(.messages)
        self.contracts = flag(.contracts)
        self.payouts   = flag(.payouts)
    }

    /// All-on default used when the whole column is null/absent. Matches
    /// the decoder's per-key fallback above (missing == true).
    public static let defaultAllOn = NotificationPrefs(
        email: true, bookings: true, messages: true, contracts: true, payouts: true
    )
}
