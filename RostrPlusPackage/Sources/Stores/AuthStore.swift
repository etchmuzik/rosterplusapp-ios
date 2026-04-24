// AuthStore.swift
//
// Session + current-user state. Thin wrapper around Supabase auth that
// exposes SwiftUI-friendly @Observable state + a couple of typed
// helpers the views actually call.
//
// Wave 1 ships this as a stub (no session observed, no sign-in wired
// yet). Wave 5 fills in Apple + Google OAuth and hooks the custom
// `signup` edge function per the plan.

import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class AuthStore {

    public private(set) var user: User?
    public private(set) var role: String?

    public init() {}

    /// Load the current session, if any, from Supabase's local storage.
    /// Call at app start — if a user was signed in, this rehydrates.
    public func loadSession() async {
        // Intentionally empty until Wave 5. Keeps the API surface stable
        // so view code can reference `authStore.user` today without
        // blocking the initial UI port.
    }

    public var isSignedIn: Bool { user != nil }
}
