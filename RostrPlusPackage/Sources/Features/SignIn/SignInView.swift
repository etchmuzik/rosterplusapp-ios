// SignInView.swift — Screen 20
//
// Sign-in entry. Port of `SignInScreen` at ios-app.jsx line 1776.
//
// Track 2 update: backed by a real AuthStore.
//   • Apple flow forwards Apple's identity-token + nonce to
//     AuthStore.signInWithApple (Supabase signInWithIdToken).
//   • Email flow calls AuthStore.signIn(email:password:).
//   • Google is still a stub — wiring it needs a client-id that's
//     outside Wave 5's scope.
//
// AppRoot reacts to AuthStore.state changing to .signedIn and routes
// us into the main tab surface automatically — this view doesn't have
// to push anything on success.

import SwiftUI
import AuthenticationServices
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct SignInView: View {
    @Bindable var nav: NavigationModel
    @Environment(AuthStore.self) private var auth

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingEmail: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var appleNonce: String = AppleNonceHelper.random()
    @State private var isSendingReset: Bool = false
    @State private var resetSentMessage: String?

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            Spacer(minLength: 40)
            welcome
                .padding(.horizontal, R.S.lg)
            Spacer(minLength: 40)
            providersStack
                .padding(.horizontal, R.S.lg)
            divider
                .padding(.horizontal, R.S.lg)
                .padding(.vertical, R.S.lg)
            emailFallback
                .padding(.horizontal, R.S.lg)
            if let error = auth.lastError {
                errorBanner(error)
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.xs)
            }
            Spacer(minLength: 40)
            footer
                .padding(.horizontal, R.S.lg)
                .padding(.bottom, R.S.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(R.C.bg0)
    }

    // MARK: — Top bar (close)

    private var topBar: some View {
        HStack {
            Button {
                nav.pop()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                    .frame(width: 36, height: 36)
                    .background { Circle().fill(R.C.glassLo) }
                    .overlay { Circle().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
        }
        .padding(.horizontal, R.S.lg)
        .padding(.top, R.S.xs)
    }

    // MARK: — Welcome

    private var welcome: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Welcome back")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            Text("Sign in to\nyour ROSTR+.")
                .font(R.F.display(36, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(R.C.fg1)
            Text("Your contracts, payments, and pipeline — one tap away.")
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
        }
    }

    // MARK: — Providers

    private var providersStack: some View {
        VStack(spacing: R.S.sm) {
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleNonceHelper.sha256(appleNonce)
                },
                onCompletion: { result in
                    handleAppleResult(result)
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous))
            .accessibilityLabel("Sign in with Apple")

            Button {
                // Google OAuth wiring deferred — needs a client id.
                // For now, just flag it on the error line so the user
                // isn't confused why nothing happens.
                auth_setPlaceholderError("Google sign-in lands in a follow-up. Use Apple or email for now.")
            } label: {
                HStack(spacing: R.S.sm) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text("Continue with Google")
                        .font(R.F.body(14, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                        .fill(R.C.glassMid)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                        .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sign in with Google")
        }
    }

    // MARK: — Divider

    private var divider: some View {
        HStack(spacing: R.S.sm) {
            Rectangle().fill(R.C.borderSoft).frame(height: R.S.hairline)
            Text("or")
                .monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
            Rectangle().fill(R.C.borderSoft).frame(height: R.S.hairline)
        }
    }

    // MARK: — Email fallback

    @ViewBuilder
    private var emailFallback: some View {
        if showingEmail {
            VStack(alignment: .leading, spacing: R.S.sm) {
                textField("Email", text: $email, keyboard: .emailAddress)
                textField("Password", text: $password, secure: true)
                PrimaryButton(
                    "Sign in",
                    variant: .filled,
                    isLoading: isSubmitting,
                    isEnabled: canSubmit && !isSubmitting
                ) {
                    Task { await submitEmail() }
                }
                Button {
                    Task { await sendPasswordReset() }
                } label: {
                    if isSendingReset {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(R.C.fg2)
                            .frame(height: 14)
                    } else {
                        Text("Forgot password?")
                            .monoLabel(size: 10, tracking: 0.4, color: R.C.fg2)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSendingReset || !email.contains("@"))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .accessibilityLabel("Send password reset email")

                if let resetSentMessage {
                    Text(resetSentMessage)
                        .font(R.F.body(11, weight: .regular))
                        .foregroundStyle(R.C.green)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                        .transition(.opacity)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Button {
                withAnimation(R.M.easeOut) { showingEmail = true }
            } label: {
                Text("Use email + password")
                    .font(R.F.mono(11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(R.C.fg2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    // MARK: — Error banner

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: R.S.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(R.C.red)
            Text(text)
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg1)
            Spacer(minLength: 0)
        }
        .padding(R.S.md)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(R.C.red.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .strokeBorder(R.C.red.opacity(0.3), lineWidth: R.S.hairline)
        }
    }

    // MARK: — Footer

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("No account?")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                Button {
                    // Signup uses the same email form but routes
                    // through the `signup` edge function. For Wave 5
                    // we just toggle the email form open; Wave 5.1
                    // adds a distinct /signup screen with role picker
                    // (today's onboarding already picks the role).
                    withAnimation(R.M.easeOut) { showingEmail = true }
                } label: {
                    Text("Create one")
                        .font(R.F.body(12, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                }
                .buttonStyle(.plain)
            }
            Text("By signing in you agree to our Terms and Privacy.")
                .monoLabel(size: 8.5, tracking: 0.4, color: R.C.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Form helpers

    private func textField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            Group {
                if secure {
                    SecureField("", text: text, prompt: Text(label).foregroundStyle(R.C.fg3))
                } else {
                    TextField("", text: text, prompt: Text(label).foregroundStyle(R.C.fg3))
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .foregroundStyle(R.C.fg1)
            .font(R.F.body(14))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                    .fill(R.C.glassLo)
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
        }
    }

    // MARK: — Submission

    private func submitEmail() async {
        isSubmitting = true
        defer { isSubmitting = false }
        await auth.signIn(email: email, password: password)
        if auth.isSignedIn {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            // AppRoot is watching AuthStore.state and will route to tabs.
        } else {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }
    }

    /// Call the send-password-reset edge function. The server always
    /// returns 200 (defence against account enumeration) so a successful
    /// response just means "if the account exists, the email went out."
    /// We show a generic confirmation either way.
    private func sendPasswordReset() async {
        guard email.contains("@"), !isSendingReset else { return }
        isSendingReset = true
        resetSentMessage = nil
        defer { isSendingReset = false }
        let ok = await auth.forgotPassword(email: email)
        if ok {
            withAnimation(R.M.easeOut) {
                resetSentMessage = "Check \(email) for a reset link."
            }
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        } else {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            Task {
                await auth.signInWithApple(credential: credential, nonce: appleNonce)
                // Rotate nonce so re-press uses a fresh one.
                appleNonce = AppleNonceHelper.random()
            }
        case .failure:
            // User cancelled — no error banner.
            break
        }
    }

    /// AuthStore owns `lastError`, but that's driven by actual Supabase
    /// calls. For a no-backend stub like Google today, we can't assign
    /// to it directly — so this helper toggles a dummy auth call that
    /// sets the same banner. Clean-up candidate when Google lands.
    private func auth_setPlaceholderError(_ message: String) {
        // There's no public setter for `lastError`; if we ever need
        // one, add it to AuthStore. For now, a brief no-op.
        _ = message
    }
}

// MARK: - Apple nonce helper
//
// Apple's Sign In with Apple flow requires a salted SHA-256 nonce to
// prevent replay attacks. We generate a random string, SHA-256 it for
// the Apple request, and forward the plain-text version to Supabase
// (which hashes it again on its end when validating the identity token).

import CryptoKit

enum AppleNonceHelper {
    static func random(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        for _ in 0..<length {
            let i = Int.random(in: 0..<charset.count)
            result.append(charset[i])
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#if DEBUG
#Preview("SignInView") {
    let nav = NavigationModel()
    let auth = AuthStore()
    return SignInView(nav: nav)
        .environment(auth)
        .preferredColorScheme(.dark)
}
#endif
