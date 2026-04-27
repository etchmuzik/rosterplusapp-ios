// Route.swift
//
// Every possible push destination in the app. Mirrors the `kind` strings
// used by `InteractiveDevice` in ios-app.jsx (line 768-779):
//
//   'artist' · 'booking' · 'thread' · 'booking-detail' · 'epk' ·
//   'contract' · 'notifications' · 'review' · 'claim' · 'availability' ·
//   'profile-edit' · 'invoice'
//
// Payload-carrying cases use associated values; everything else is pure.

import Foundation

public enum Route: Hashable, Identifiable, Sendable {
    case artist(artistID: String)
    case booking(artistID: String)
    case bookingDetail(bookingID: String)
    case thread(threadID: String)
    case epk(artistID: String)
    case contract(contractID: String)
    case notifications
    case review(bookingID: String)
    case claim
    case availability
    case profileEdit
    case invoice(bookingID: String)
    case signIn
    case onboard
    case calendar
    case analytics

    public var id: String {
        switch self {
        case .artist(let id):         return "artist:\(id)"
        case .booking(let id):        return "booking:\(id)"
        case .bookingDetail(let id):  return "bookingDetail:\(id)"
        case .thread(let id):         return "thread:\(id)"
        case .epk(let id):            return "epk:\(id)"
        case .contract(let id):       return "contract:\(id)"
        case .notifications:          return "notifications"
        case .review(let id):         return "review:\(id)"
        case .claim:                  return "claim"
        case .availability:           return "availability"
        case .profileEdit:            return "profileEdit"
        case .invoice(let id):        return "invoice:\(id)"
        case .signIn:                 return "signIn"
        case .onboard:                return "onboard"
        case .calendar:               return "calendar"
        case .analytics:              return "analytics"
        }
    }
}

// MARK: - CaseIterable (test seam)

extension Route: CaseIterable {
    /// One canonical instance per Route case, used by parameterised
    /// tests that walk every navigation destination (e.g. "every
    /// pushable Route renders a back affordance"). Associated-value
    /// payloads use a fixed UUID so test snapshots stay stable.
    public static var allCases: [Route] {
        let id = "00000000-0000-0000-0000-000000000001"
        return [
            .artist(artistID: id),
            .booking(artistID: id),
            .bookingDetail(bookingID: id),
            .thread(threadID: id),
            .epk(artistID: id),
            .contract(contractID: id),
            .notifications,
            .review(bookingID: id),
            .claim,
            .availability,
            .profileEdit,
            .invoice(bookingID: id),
            .signIn,
            .onboard,
            .calendar,
            .analytics
        ]
    }
}

// MARK: - URL / href → Route

public extension Route {
    /// Parse a server-issued href ("/bookings/<uuid>", "/threads/<uuid>",
    /// "/contracts/<uuid>", "/invoices/<uuid>", "/reviews/<uuid>",
    /// "/artists/<uuid>", "/epks/<uuid>", "/notifications") into a Route.
    /// Used by:
    ///   - in-app notification taps in NotificationsView
    ///   - APNs payload taps in AppDelegate
    ///   - Universal-link / custom-scheme opens via `onOpenURL`
    /// Returns nil for unrecognised paths so callers can decide whether
    /// to ignore the tap or fall back to a default surface.
    static func parse(href: String) -> Route? {
        // Tolerate leading slash, full URL (https://rosterplus.io/...),
        // bare path, and custom-scheme URLs (rostr://bookings/<id>).
        // For custom schemes the first segment lives in `host`; for
        // https-style URLs the host is a domain we should skip and the
        // first segment is the leading path component.
        let trimmed = href.trimmingCharacters(in: .whitespaces)
        var parts: [String] = []
        if let url = URL(string: trimmed), let scheme = url.scheme {
            let isWeb = scheme == "http" || scheme == "https"
            if let host = url.host, !host.isEmpty, !isWeb {
                parts.append(host)
            }
            parts.append(contentsOf: url.path
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init))
        } else {
            parts = trimmed
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
        }
        guard let head = parts.first else { return nil }
        let id = parts.count >= 2 ? parts[1] : ""
        switch head {
        case "bookings":      return id.isEmpty ? nil : .bookingDetail(bookingID: id)
        case "threads":       return id.isEmpty ? nil : .thread(threadID: id)
        case "contracts":     return id.isEmpty ? nil : .contract(contractID: id)
        case "invoices":      return id.isEmpty ? nil : .invoice(bookingID: id)
        case "reviews":       return id.isEmpty ? nil : .review(bookingID: id)
        case "artists":       return id.isEmpty ? nil : .artist(artistID: id)
        case "epks", "epk":   return id.isEmpty ? nil : .epk(artistID: id)
        case "notifications": return .notifications
        default:              return nil
        }
    }
}
