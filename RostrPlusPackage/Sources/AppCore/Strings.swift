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
        public static let back   = LocalizedStringResource("common.back",   bundle: .atURL(Bundle.module.bundleURL))
        public static let cancel = LocalizedStringResource("common.cancel", bundle: .atURL(Bundle.module.bundleURL))
        public static let save   = LocalizedStringResource("common.save",   bundle: .atURL(Bundle.module.bundleURL))
        public static let done   = LocalizedStringResource("common.done",   bundle: .atURL(Bundle.module.bundleURL))
        public static let retry  = LocalizedStringResource("common.retry",  bundle: .atURL(Bundle.module.bundleURL))
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
        public static let book    = LocalizedStringResource("cta.book",    bundle: .atURL(Bundle.module.bundleURL))
        public static let message = LocalizedStringResource("cta.message", bundle: .atURL(Bundle.module.bundleURL))
        public static let share   = LocalizedStringResource("cta.share",   bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum State {
        public static let loading       = LocalizedStringResource("state.loading",        bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyBookings = LocalizedStringResource("state.empty.bookings", bundle: .atURL(Bundle.module.bundleURL))
        public static let emptyInbox    = LocalizedStringResource("state.empty.inbox",    bundle: .atURL(Bundle.module.bundleURL))
        public static let offline       = LocalizedStringResource("state.offline",        bundle: .atURL(Bundle.module.bundleURL))
    }

    public enum Screen {
        public static let epk           = LocalizedStringResource("epk.title",           bundle: .atURL(Bundle.module.bundleURL))
        public static let calendar      = LocalizedStringResource("calendar.title",      bundle: .atURL(Bundle.module.bundleURL))
        public static let notifications = LocalizedStringResource("notifications.title", bundle: .atURL(Bundle.module.bundleURL))
    }
}
