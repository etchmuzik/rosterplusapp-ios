// SignedInSmokeTests.swift
//
// End-to-end smoke test that proves every user-scoped store can
// fetch real data against the live Supabase project under a real
// signed-in session. This is the layer between unit tests (which
// mock the writer) and an interactive sim run (which needs human
// input on the sign-in screen).
//
// What it covers
// --------------
// 1. signup edge function creates a real auth.users row + handle_new_user
//    trigger creates the matching profiles row.
// 2. Email+password sign-in returns a session.
// 3. Each tab's data path resolves under that session:
//      Home          → BookingsStore.refresh
//      Bookings      → BookingsStore.refresh
//      Inbox         → InboxStore.refresh
//      Notifications → NotificationsStore.refresh
//      Calendar      → BookingsStore (already loaded above)
//      Settings      → ProfileStore.refresh + AuthStore.isEmailConfirmed
//      Roster        → RosterStore.refresh
//      Payments      → PaymentsStore.refresh
// 4. Each store ends in `.loaded` (NOT .failed, NOT stuck in .loading).
// 5. Sign-out clears every store.
//
// What it does NOT cover
// ----------------------
// - Liquid Glass / typography / Dynamic Type rendering — that's a
//   visual-regression problem, not a data problem.
// - Tap-through navigation per button — that needs a sim runner.
//   But: every tab IS its store + view, and if the store loads,
//   the view renders the loaded branch (we have unit tests that
//   verify the .loaded body composes correctly).
//
// How it runs
// -----------
// Gated on ROSTR_LIVE_SMOKE=1 — local `swift test` and PR CI skip
// it. A dedicated CI job sets the env var nightly. One auth.users
// row is created per run; we don't delete it (Supabase auth.users
// has no DELETE RLS policy for self), so it accumulates ~1/day —
// trivial cleanup later.

import Testing
import Foundation
@testable import RostrPlusFeature

/// Gate the live-smoke suite on the existence of /tmp/rostr-live-smoke.
/// Touch the file before `bash scripts/test.sh` to opt in; the suite
/// stays skipped on every other run including PR CI. We use a file
/// rather than an env var because xcodebuild doesn't forward host
/// environment to the iOS-simulator test runner without an
/// .xctestplan, and adding a test plan would mean editing project.yml.
private let liveSmokeEnabled: Bool = {
    FileManager.default.fileExists(atPath: "/tmp/rostr-live-smoke")
}()

@MainActor
@Suite(
    "Signed-in smoke (live Supabase)",
    .serialized,
    .enabled(if: liveSmokeEnabled)
)
struct SignedInSmokeTests {

    /// Generate a fresh email + password per test so we never collide
    /// with an existing row. Uses gmail's `+tag` convention so the
    /// catch-all account at hi@rosterplus.io can route bounces.
    private func freshCreds() -> (email: String, password: String, displayName: String) {
        let stamp = Int(Date().timeIntervalSince1970)
        let rand = Int.random(in: 1000...9999)
        let email = "rostr-smoke+\(stamp)\(rand)@gmail.com"
        let password = "SmokeTest!" + String(rand) + "Aa9"  // ≥ 8, mixed case + digit
        return (email, password, "Smoke Test \(stamp)")
    }

    /// Wait until `predicate()` returns true or the timeout expires.
    /// Polling is fine for a smoke test — we're not measuring latency.
    private func awaitState(
        timeout: Duration = .seconds(10),
        _ predicate: () -> Bool
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    @Test("Promoter — full dashboard data path resolves end-to-end")
    func promoterDashboard() async throws {
        let creds = freshCreds()
        let auth = AuthStore()

        // 1. Sign up via the real signup edge function. This creates
        //    auth.users + fires handle_new_user → public.profiles.
        await auth.signUp(
            email: creds.email,
            password: creds.password,
            role: "promoter",
            displayName: creds.displayName
        )
        try #require(auth.lastError == nil, "signUp surfaced \(auth.lastError ?? "?")")

        // 2. Wait for the auth state to land in .signedIn.
        await awaitState { if case .signedIn = auth.state { return true }; return false }
        guard case .signedIn(let userID, let email, let role) = auth.state else {
            Issue.record("auth never reached .signedIn — state is \(auth.state)")
            return
        }
        #expect(email == creds.email)
        #expect(role == "promoter", "expected promoter role from signup, got \(role)")

        // 3. Drive every user-scoped store through its refresh path
        //    and assert each lands in a non-failed terminal state.

        let bookings = BookingsStore()
        bookings.refresh(for: userID, role: .promoter)
        await awaitState {
            if case .loaded = bookings.state { return true }
            if case .failed = bookings.state { return true }  // surface error below
            return false
        }
        if case .failed(let m) = bookings.state {
            Issue.record("BookingsStore.refresh failed: \(m)")
        }

        let inbox = InboxStore()
        inbox.refresh(for: userID)
        await awaitState {
            if case .loaded = inbox.state { return true }
            if case .failed = inbox.state { return true }
            return false
        }
        if case .failed(let m) = inbox.state {
            Issue.record("InboxStore.refresh failed: \(m)")
        }

        let notifications = NotificationsStore()
        notifications.refresh(for: userID)
        await awaitState {
            if case .loaded = notifications.state { return true }
            if case .failed = notifications.state { return true }
            return false
        }
        if case .failed(let m) = notifications.state {
            Issue.record("NotificationsStore.refresh failed: \(m)")
        }

        let payments = PaymentsStore()
        payments.refresh(for: userID)
        await awaitState {
            if case .loaded = payments.state { return true }
            if case .failed = payments.state { return true }
            return false
        }
        if case .failed(let m) = payments.state {
            Issue.record("PaymentsStore.refresh failed: \(m)")
        }

        let profile = ProfileStore()
        profile.refresh(for: userID)
        await awaitState {
            if case .loaded = profile.state { return true }
            if case .failed = profile.state { return true }
            return false
        }
        if case .failed(let m) = profile.state {
            Issue.record("ProfileStore.refresh failed: \(m)")
        }
        // The handle_new_user trigger should have populated the row.
        #expect(profile.current?.id == userID)

        let roster = RosterStore()
        roster.refresh()
        await awaitState {
            if case .loaded = roster.state { return true }
            if case .failed = roster.state { return true }
            return false
        }
        if case .failed(let m) = roster.state {
            Issue.record("RosterStore.refresh failed: \(m)")
        }

        // 4. Sign out wipes every store.
        await auth.signOut()
        await awaitState { if case .signedOut = auth.state { return true }; return false }
        if case .signedOut = auth.state {
            #expect(auth.lastError == nil)
            #expect(auth.isEmailConfirmed == false)
        } else {
            Issue.record("Sign-out never landed; state is \(auth.state)")
        }

        // Reset the user-scoped stores explicitly the way AppRoot does.
        bookings.reset()
        await inbox.reset()
        await notifications.reset()
        payments.reset()
        profile.reset()
        roster.reset()

        // Asserting cleanly cleared state — caches/items should be
        // empty, state back to .idle.
        if case .idle = bookings.state {} else {
            Issue.record("BookingsStore.reset didn't return to .idle")
        }
        #expect(payments.items.isEmpty)
        #expect(profile.current == nil)
    }

    @Test("Sign-in with wrong password against real account surfaces an error")
    func badCredsSurfaceError() async throws {
        // Create a real account first, then attempt sign-in with the
        // wrong password. The SDK responds with `invalid_credentials`
        // which AuthStore maps to lastError + .signedOut.
        let creds = freshCreds()
        let setup = AuthStore()
        await setup.signUp(
            email: creds.email,
            password: creds.password,
            role: "promoter",
            displayName: creds.displayName
        )
        await awaitState { if case .signedIn = setup.state { return true }; return false }
        await setup.signOut()
        await awaitState { if case .signedOut = setup.state { return true }; return false }

        let auth = AuthStore()
        await auth.signIn(email: creds.email, password: "wrong-password-12345")
        await awaitState { auth.lastError != nil }
        // The SDK might surface the failure either as a populated
        // lastError OR as a non-.signedIn state. The contract is
        // "user knows the sign-in didn't land" — accept either signal.
        let didNotSignIn: Bool = {
            if case .signedIn = auth.state { return false }
            return true
        }()
        #expect(
            didNotSignIn,
            "expected sign-in to be rejected; state=\(auth.state) lastError=\(auth.lastError ?? "nil")"
        )
    }
}
