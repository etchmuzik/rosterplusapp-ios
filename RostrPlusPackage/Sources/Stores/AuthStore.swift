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

    public private(set) var state: State = .unknown {
        didSet {
            // Tie email-confirmation flag and any stale error to
            // session validity so any path that flips state to
            // .signedOut clears them without a manual reset call.
            if case .signedIn = state { return }
            isEmailConfirmed = false
            lastError = nil
        }
    }
    public private(set) var lastError: String?

    /// Whether the signed-in user has confirmed their email address.
    /// Mirrors `auth.users.email_confirmed_at != nil`. Reset to false
    /// on sign-out.
    public private(set) var isEmailConfirmed: Bool = false

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
        } catch let error as FunctionsError {
            // Edge function returned a non-2xx — the body carries our
            // own error codes (email_taken, weak_password, …). Extract
            // and feed into humanize().
            lastError = humanize(decodeFunctionError(error) ?? error)
            state = .signedOut
        } catch {
            lastError = humanize(error)
            state = .signedOut
        }
    }

    /// Decode the JSON body of a FunctionsError.httpError into a
    /// stub Error whose localizedDescription is the edge function's
    /// machine code (email_taken, weak_password, …). humanize() then
    /// maps it to copy.
    private func decodeFunctionError(_ error: FunctionsError) -> Error? {
        guard case .httpError(_, let data) = error else { return nil }
        struct Body: Decodable { let error: String? }
        do {
            let body = try JSONDecoder().decode(Body.self, from: data)
            if let code = body.error, !code.isEmpty {
                return AuthError.message(code)
            }
        } catch {
            // Body wasn't JSON — fall through to the original error.
        }
        return nil
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

    /// Surface a friendly error when the Apple authorization itself fails
    /// (before we ever get a credential) — e.g. a network drop or an Apple
    /// service error. The SignInWithAppleButton's `.failure` branch calls
    /// this for genuine errors but stays silent on a user cancellation.
    public func setAppleAuthorizationError(_ message: String) {
        lastError = message
    }

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

    // MARK: — Delete account

    /// Permanently delete the signed-in user's account (App Store
    /// Guideline 5.1.1(v)). Calls the `delete-account` edge function,
    /// which verifies this session's JWT, scrubs the user's PII, and
    /// hard-deletes the auth user. The `confirm: "DELETE"` body is the
    /// server-side echo of the type-to-confirm step in DeleteAccountView.
    ///
    /// On success we tear down the local session exactly like sign-out so
    /// AppRoot swaps to the sign-in shell. Returns false (and sets
    /// `lastError`) if the function rejects the request.
    @discardableResult
    public func deleteAccount() async -> Bool {
        lastError = nil
        do {
            let payload: [String: AnyJSON] = [
                "confirm": .string("DELETE"),
                "source":  .string("ios")
            ]
            // functions.invoke attaches the current session JWT, which the
            // edge function verifies to identify the account to delete.
            try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(body: payload)
            )
            // Server session is already gone — clear local state so the UI
            // lands on sign-in. (.userDeleted in startObserving() is a
            // second safety net if the auth listener fires first.)
            await signOut()
            return true
        } catch let error as FunctionsError {
            lastError = humanize(decodeFunctionError(error) ?? error)
            return false
        } catch {
            lastError = humanize(error)
            return false
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
        isEmailConfirmed = user.emailConfirmedAt != nil
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
        // Edge-function specific errors (returned as { error: code } JSON
        // bodies which surface in the localizedDescription).
        if raw.contains("email_taken") {
            return "An account with that email already exists. Try signing in."
        }
        if raw.contains("weak_password") {
            return "Password must be at least 8 characters."
        }
        if raw.contains("invalid_email") {
            return "Enter a valid email address."
        }
        if raw.contains("invalid_role") {
            return "Pick a role on the previous screen first."
        }
        if raw.contains("rate_limited") {
            return "Hold on — try again in a minute."
        }
        // Shared by signup / send-password-reset / delete-account: the
        // function is missing an env secret. Context-neutral copy — this
        // used to say "Sign-up is…" and rendered on the delete flow too.
        if raw.contains("misconfigured") {
            return "This service is temporarily unavailable. Try again shortly."
        }
        // delete-account edge-function codes.
        if raw.contains("admin_account") {
            return "This account can’t be deleted in-app. Contact support."
        }
        if raw.contains("confirm_mismatch") {
            return "Type DELETE exactly to confirm."
        }
        if raw.contains("delete_failed") {
            return "Couldn’t delete your account. Try again in a moment."
        }
        // The function does its own JWT check (verify_jwt is off at the
        // gateway); an expired/missing session comes back as a bare
        // "unauthorized" body — never show that string to a person.
        if raw == "unauthorized" || raw.contains("unauthorized") || raw.contains("jwt") {
            return "Your session has expired. Sign in again, then retry."
        }
        // Server-side generic failures (delete-account `internal` /
        // `invalid_body`, or an edge function that returned a non-JSON
        // non-2xx — the SDK's own text is "Edge Function returned a
        // non-2xx status code"). Same class of leak as the raw
        // "Provider … is not enabled" screenshot from App Review.
        if raw == "internal" || raw == "invalid_body" || raw == "method_not_allowed"
            || raw.contains("internal server") || raw.contains("non-2xx")
            || raw.contains("edge function returned") {
            return "Something went wrong on our side. Try again in a moment."
        }
        // GoTrue / Supabase Auth errors.
        if raw.contains("invalid login credentials") || raw.contains("invalid_credentials") {
            return "Email or password didn't match."
        }
        if raw.contains("email not confirmed") {
            return "Check your inbox for a confirmation link."
        }
        if raw.contains("password") && (raw.contains("short") || raw.contains("weak")) {
            return "Password must be at least 8 characters."
        }
        if raw.contains("already") && raw.contains("registered") {
            return "An account with that email already exists. Try signing in."
        }
        if raw.contains("network") || raw.contains("internet") || raw.contains("offline") {
            return "Connection issue — check your network."
        }
        // Provider disabled / not enabled (GoTrue error_code "provider_disabled").
        // Fired when an OAuth/id-token grant lands while that provider is off
        // in the Supabase project. Map it to friendly copy so a raw GoTrue
        // string can never render in the sign-in banner again — it was the
        // App Store 2.1(a) "Provider … is not enabled" screenshot.
        if raw.contains("provider") && (raw.contains("not enabled") || raw.contains("disabled")) {
            return "That sign-in method isn’t available right now. Try email and password instead."
        }
        return error.localizedDescription
    }

    #if DEBUG
    /// Force the store into `.signedIn` with a fake session — NO network.
    /// Used by screenshot mode (see ScreenshotSeed) to bypass the auth
    /// gate so curated demo data can render the authenticated surface.
    /// DEBUG-only; cannot exist in the shipping binary.
    public func _forceSignIn(userID: UUID, email: String, role: String) {
        isEmailConfirmed = true
        state = .signedIn(userID: userID, email: email, role: role)
    }
    #endif
}
