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

public enum Route: Hashable, Identifiable {
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
        }
    }
}
