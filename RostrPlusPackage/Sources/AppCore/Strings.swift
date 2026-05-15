// Strings.swift
//
// Type-safe accessors for every key in Resources/Localizable.xcstrings.
// Adding a new string is a two-step:
//   1. Add it to the .xcstrings file (with at least an EN value).
//   2. Add a `static let` here that points at the same key.
//
// Views read via `S.Common.back`, `S.Tab.home`, etc. The compiler then
// catches any drift between the catalog and the call sites — fat-
// fingering a key string can't reach production.
//
// All values are `LocalizedStringResource` so they thread through
// SwiftUI's `Text(_:)` and `Button(_:action:)` overloads with the
// correct bundle (`.module`) without each call site having to remember
// to pass `bundle:`.

import Foundation
import SwiftUI

public enum S {

    public enum Common {
        public static let back     = LocalizedStringResource("common.back",     bundle: .atURL(Bundle.module.bundleURL))
        public static let cancel   = LocalizedStringResource("common.cancel",   bundle: .atURL(Bundle.module.bundleURL))
        public static let save     = LocalizedStringResource("common.save",     bundle: .atURL(Bundle.module.bundleURL))
        public static let done     = LocalizedStringResource("common.done",     bundle: .atURL(Bundle.module.bundleURL))
        public static let retry    = LocalizedStringResource("common.retry",    bundle: .atURL(Bundle.module.bundleURL))
        public static let edit     = LocalizedStringResource("common.edit",     bundle: .atURL(Bundle.module.bundleURL))
        public static let skip     = LocalizedStringResource("common.skip",     bundle: .atURL(Bundle.module.bundleURL))
        public static let tryAgain = LocalizedStringResource("common.tryAgain", bundle: .atURL(Bundle.module.bundleURL))
        public static let all      = LocalizedStringResource("common.all",      bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Tab {
        public static let home     = LocalizedStringResource("tab.home",     bundle: .atURL(Bundle.module.bundleURL))
        public static let roster   = LocalizedStringResource("tab.roster",   bundle: .atURL(Bundle.module.bundleURL))
        public static let bookings = LocalizedStringResource("tab.bookings", bundle: .atURL(Bundle.module.bundleURL))
        public static let inbox    = LocalizedStringResource("tab.inbox",    bundle: .atURL(Bundle.module.bundleURL))
        public static let me       = LocalizedStringResource("tab.me",       bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Auth {
        public static let signIn         = LocalizedStringResource("auth.signin",         bundle: .atURL(Bundle.module.bundleURL))
        public static let signUp         = LocalizedStringResource("auth.signup",         bundle: .atURL(Bundle.module.bundleURL))
        public static let signOut        = LocalizedStringResource("auth.signout",        bundle: .atURL(Bundle.module.bundleURL))
        public static let forgotPassword = LocalizedStringResource("auth.forgotpassword", bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum CTA {
        public static let book           = LocalizedStringResource("cta.book",           bundle: .atURL(Bundle.module.bundleURL))
        public static let message        = LocalizedStringResource("cta.message",        bundle: .atURL(Bundle.module.bundleURL))
        public static let share          = LocalizedStringResource("cta.share",          bundle: .atURL(Bundle.module.bundleURL))
        public static let openBooking    = LocalizedStringResource("cta.openBooking",    bundle: .atURL(Bundle.module.bundleURL))
        public static let browseRoster   = LocalizedStringResource("cta.browseRoster",   bundle: .atURL(Bundle.module.bundleURL))
        public static let requestBooking = LocalizedStringResource("cta.requestBooking", bundle: .atURL(Bundle.module.bundleURL))
        public static let messageArtist  = LocalizedStringResource("cta.messageArtist",  bundle: .atURL(Bundle.module.bundleURL))
        public static let viewContract   = LocalizedStringResource("cta.viewContract",   bundle: .atURL(Bundle.module.bundleURL))
        public static let viewInvoice    = LocalizedStringResource("cta.viewInvoice",    bundle: .atURL(Bundle.module.bundleURL))
        public static let sendMessage    = LocalizedStringResource("cta.sendMessage",    bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum State {
        public static let loading               = LocalizedStringResource("state.loading",                 bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyBookings         = LocalizedStringResource("state.empty.bookings",          bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyInbox            = LocalizedStringResource("state.empty.inbox",             bundle: .atURL(Bundle.module.bundleURL))
        public static let offline               = LocalizedStringResource("state.offline",                 bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyUpcomingBookings = LocalizedStringResource("state.empty.upcomingBookings",  bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyUpcomingGigs     = LocalizedStringResource("state.empty.upcomingGigs",      bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyPastPerformances = LocalizedStringResource("state.empty.pastPerformances",  bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyPressQuotes      = LocalizedStringResource("state.empty.pressQuotes",       bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyRecentSets       = LocalizedStringResource("state.empty.recentSets",        bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyPaymentsTitle    = LocalizedStringResource("state.empty.payments.title",    bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyPaymentsBody     = LocalizedStringResource("state.empty.payments.body",     bundle: .atURL(Bundle.module.bundleURL))
        public static let errorBookings         = LocalizedStringResource("state.error.bookings",          bundle: .atURL(Bundle.module.bundleURL))
        public static let errorPayments         = LocalizedStringResource("state.error.payments",          bundle: .atURL(Bundle.module.bundleURL))
        public static let errorNotifications    = LocalizedStringResource("state.error.notifications",     bundle: .atURL(Bundle.module.bundleURL))
        public static let errorRoster           = LocalizedStringResource("state.error.roster",            bundle: .atURL(Bundle.module.bundleURL))
        public static let errorProfile          = LocalizedStringResource("state.error.profile",           bundle: .atURL(Bundle.module.bundleURL))
        public static let errorEPK              = LocalizedStringResource("state.error.epk",               bundle: .atURL(Bundle.module.bundleURL))
        public static let errorBooking          = LocalizedStringResource("state.error.booking",           bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Screen {
        public static let epk           = LocalizedStringResource("epk.title",           bundle: .atURL(Bundle.module.bundleURL))
        public static let calendar      = LocalizedStringResource("calendar.title",      bundle: .atURL(Bundle.module.bundleURL))
        public static let notifications = LocalizedStringResource("notifications.title", bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Home {
        public static let greetingEvening = LocalizedStringResource("home.greeting.evening", bundle: .atURL(Bundle.module.bundleURL))
        public static let upNext          = LocalizedStringResource("home.upNext",           bundle: .atURL(Bundle.module.bundleURL))
        public static let allBookings     = LocalizedStringResource("home.allBookings",      bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyCTA        = LocalizedStringResource("home.empty.cta",        bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyBody       = LocalizedStringResource("home.empty.body",       bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyCalendar   = LocalizedStringResource("home.empty.calendar",   bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Inbox {
        public static let emptyTitle = LocalizedStringResource("inbox.empty.title", bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyBody  = LocalizedStringResource("inbox.empty.body",  bundle: .atURL(Bundle.module.bundleURL))
        public static let errorTitle = LocalizedStringResource("inbox.error.title", bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Booking {
        public static let timeline      = LocalizedStringResource("booking.timeline",       bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyTimeline = LocalizedStringResource("booking.empty.timeline", bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Availability {
        public static let baseFee  = LocalizedStringResource("availability.baseFee",  bundle: .atURL(Bundle.module.bundleURL))
        public static let tourMode = LocalizedStringResource("availability.tourMode", bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Section {
        public static let about             = LocalizedStringResource("section.about",             bundle: .atURL(Bundle.module.bundleURL))
        public static let press             = LocalizedStringResource("section.press",             bundle: .atURL(Bundle.module.bundleURL))
        public static let recentSets       = LocalizedStringResource("section.recentSets",         bundle: .atURL(Bundle.module.bundleURL))
        public static let pastPerformances  = LocalizedStringResource("section.pastPerformances",  bundle: .atURL(Bundle.module.bundleURL))
        public static let upcomingGigs      = LocalizedStringResource("section.upcomingGigs",      bundle: .atURL(Bundle.module.bundleURL))
        public static let bookingRequests   = LocalizedStringResource("section.bookingRequests",   bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Notification {
        public static let markRead = LocalizedStringResource("notifications.markRead", bundle: .atURL(Bundle.module.bundleURL))
    }
}
