// AuthStore.swift
//
// Supabase-backed session store. Single source of truth for "am I
// signed in, and as whom." Views observe `state` to decide whether to
// show the onboarding/sign-in flow or the authenticated tab surface.
//
// Signup strategy (per plan defaults):
//   Password signups go through the existing `signup` edge function so
//   iOS and web stay behaviourally identical — same welcome email, same
//   handle_new_user trigger. Apple/Google OAuth uses the Supabase-native
//   flow since those providers bypass our SMTP concerns anyway.

import Foundation
import Observation
import Supabase
import AuthenticationServices

@Observable
@MainActor
public final class AuthStore {

    public enum State: Equatable {
        /// We haven't checked for a session yet. Show a loading shell.
        case unknown
        /// No valid session. Route through onboarding → sign-in.
        case signedOut
        /// Authenticated. Show the tab surface.
        case signedIn(userID: UUID, email: String, role: String)
    }

    public enum AuthError: Error, LocalizedError {
        case notInitialised
        case message(String)

        public var errorDescription: String? {
            switch self {
            case .notInitialised:    return "Auth not initialised"
            case .message(let m):    return m
            }
        }
    }

    public private(set) var state: State = .unknown
    public private(set) var lastError: String?

    private let client = RostrSupabase.shared

    public init() {}

    // MARK: — Session lifecycle

    /// Call at app start. Rehydrates the session from secure storage.
    /// Safe to call multiple times.
    public func loadSession() async {
        do {
            let session = try await client.auth.session
            await apply(session: session)
        } catch {
            // Any error here == no valid cached session. Not fatal.
            state = .signedOut
        }
    }

    /// Start observing auth-state changes. Fires when a sign-in, sign-out,
    /// or token refresh happens in any part of the SDK. Call once from
    /// AppRoot's .task modifier.
    public func startObserving() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                if let session {
                    await apply(session: session)
                } else {
                    state = .signedOut
                }
            case .signedOut, .userDeleted:
                state = .signedOut
            case .passwordRecovery, .mfaChallengeVerified:
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: — Email + password

    /// Sign in with existing credentials. Maps Supabase errors to
    /// friendly messages on `lastError`.
    public func signIn(email: String, password: String) async {
        lastError = nil
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            await apply(session: session)
        } catch {
            lastError = humanize(error)
            state = .signedOut
        }
    }

    /// Sign up via the custom `signup` edge function (bypasses SMTP,
    /// fires handle_new_user trigger, sends Resend welcome email).
    /// Role must be "promoter" or "artist" — the edge function rejects
    /// anything else.
    public func signUp(email: String, password: String, role: String, displayName: String) async {
        lastError = nil
        do {
            // Call the edge function directly. Not the built-in
            // signUp() — that uses Supabase's SMTP which is unwired.
            let payload: [String: AnyJSON] = [
                "email":        .string(email),
                "password":     .string(password),
                "role":         .string(role),
                "display_name": .string(displayName)
            ]
            try await client.functions.invoke(
                "signup",
                options: FunctionInvokeOptions(body: payload)
            )

            // After the edge function creates the auth user, sign in
            // locally so we have a session token cached for subsequent
            // RLS-gated calls.
            let session = try await client.auth.signIn(email: email, password: password)
            await apply(session: session)
        } catch {
            lastError = humanize(error)
            state = .signedOut
        }
    }

    // MARK: — Forgot password

    /// Kick the send-password-reset edge function. The function always
    /// returns 200 (on purpose — account-enumeration defence), so a
    /// success here means "the email was dispatched IF the account
    /// exists" rather than "the account exists".
    ///
    /// Views show a generic "check your email" confirmation on the
    /// returning true regardless of the actual account state.
    @discardableResult
    public func forgotPassword(email: String) async -> Bool {
        lastError = nil
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@") else {
            lastError = "Enter a valid email address."
            return false
        }
        do {
            let payload: [String: AnyJSON] = [
                "email": .string(trimmed.lowercased())
            ]
            try await client.functions.invoke(
                "send-password-reset",
                options: FunctionInvokeOptions(body: payload)
            )
            return true
        } catch {
            lastError = humanize(error)
            return false
        }
    }

    // MARK: — Apple

    /// Finish an Apple Sign In flow. Hand in the `ASAuthorizationAppleIDCredential`
    /// from the SignInWithAppleButton callback.
    public func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async {
        lastError = nil
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            lastError = "Apple didn't return an identity token."
            return
        }
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            await apply(session: session)
        } catch {
            lastError = humanize(error)
        }
    }

    // MARK: — Sign out

    public func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Even on network failure, clear local state — the user
            // pressing "Sign out" expects to land on the sign-in screen.
        }
        state = .signedOut
    }

    // MARK: — Helpers

    /// Synchronous accessor for views that need the user id without
    /// pattern-matching the State enum. Returns nil if signed out.
    public var currentUserID: UUID? {
        if case .signedIn(let id, _, _) = state { return id }
        return nil
    }

    public var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// Read the user's role from `public.profiles` and persist into
    /// the signed-in state. Called after every fresh session load so
    /// Home can branch promoter ↔ artist correctly.
    private func apply(session: Session) async {
        let user = session.user
        let role = await fetchRole(userID: user.id) ?? "promoter"
        state = .signedIn(
            userID: user.id,
            email: user.email ?? "",
            role: role
        )
    }

    private func fetchRole(userID: UUID) async -> String? {
        struct RoleRow: Decodable { let role: String? }
        do {
            let rows: [RoleRow] = try await client
                .from("profiles")
                .select("role")
                .eq("id", value: userID)
                .limit(1)
                .execute()
                .value
            return rows.first?.role
        } catch {
            return nil
        }
    }

    private func humanize(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("invalid login credentials") {
            return "Email or password didn't match."
        }
        if raw.contains("email not confirmed") {
            return "Check your inbox for a confirmation link."
        }
        if raw.contains("password") && raw.contains("short") {
            return "Password must be at least 8 characters."
        }
        if raw.contains("already") && raw.contains("registered") {
            return "An account with that email already exists. Try signing in."
        }
        if raw.contains("network") || raw.contains("internet") {
            return "Connection issue — check your network."
        }
        return error.localizedDescription
    }
}
