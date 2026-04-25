// SignInView.swift — Screen 20
//
// Email + Apple authentication entry. Two modes share the screen:
//
//   .signIn  → existing user, calls AuthStore.signIn(email:password:)
//   .signUp  → new user, calls AuthStore.signUp(email:password:role:displayName:)
//              which routes through the `signup` edge function.
//
// Mode is selected by a segmented control near the top of the form
// and "Create one" / "Sign in" footer link both flip the same flag.
// Role for new accounts comes from NavigationModel.role (set by
// OnboardView's role-picker step).
//
// AppRoot watches AuthStore.state and routes to the tab surface on
// success. This view never pushes — flipping to .signedIn is enough.

import SwiftUI
import AuthenticationServices
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct SignInView: View {
    @Bindable var nav: NavigationModel
    @Environment(AuthStore.self) private var auth

    enum Mode: String, CaseIterable {
        case signIn
        case signUp

        var headlineEyebrow: String {
            switch self {
            case .signIn: return "Welcome back"
            case .signUp: return "Get started"
            }
        }

        var headline: String {
            switch self {
            case .signIn: return "Sign in to\nyour ROSTR+."
            case .signUp: return "Join the\nROSTR+ roster."
            }
        }

        var subhead: String {
            switch self {
            case .signIn: return "Your contracts, payments, and pipeline — one tap away."
            case .signUp: return "Bookings, contracts, payments — all in one place."
            }
        }

        var primaryCTA: String {
            switch self {
            case .signIn: return "Sign in"
            case .signUp: return "Create account"
            }
        }
    }

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @State private var showingEmail: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var appleNonce: String = AppleNonceHelper.random()
    @State private var isSendingReset: Bool = false
    @State private var resetSentMessage: String?

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer(minLength: 32)
                welcome
                    .padding(.horizontal, R.S.lg)
                modeToggle
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.lg)
                Spacer(minLength: 24)
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
                Spacer(minLength: 32)
                footer
                    .padding(.horizontal, R.S.lg)
                    .padding(.bottom, R.S.xl)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(R.C.bg0)
        .scrollDismissesKeyboard(.interactively)
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
            Text(mode.headlineEyebrow)
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            Text(mode.headline)
                .font(R.F.display(36, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(R.C.fg1)
            Text(mode.subhead)
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
        }
    }

    // MARK: — Mode toggle (Sign in ↔ Sign up)

    private var modeToggle: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button {
                    if mode != m {
                        withAnimation(R.M.easeOut) {
                            mode = m
                            // Wipe transient state when flipping modes
                            // so error banners + reset-sent toasts
                            // don't bleed across.
                            resetSentMessage = nil
                        }
                        #if canImport(UIKit)
                        UISelectionFeedbackGenerator().selectionChanged()
                        #endif
                    }
                } label: {
                    Text(m == .signIn ? "Sign in" : "Sign up")
                        .font(R.F.mono(11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(mode == m ? R.C.bg0 : R.C.fg2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                                .fill(mode == m ? R.C.fg1 : Color.clear)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == m ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(R.C.glassLo)
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
        }
    }

    // MARK: — Providers (Apple, Google)

    private var providersStack: some View {
        VStack(spacing: R.S.sm) {
            SignInWithAppleButton(
                mode == .signUp ? .signUp : .signIn,
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
            .accessibilityLabel(mode == .signUp ? "Sign up with Apple" : "Sign in with Apple")

            // Google deferred — no client id wired yet.
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
                if mode == .signUp {
                    textField(
                        "Display name",
                        text: $displayName,
                        keyboard: .default,
                        autocapitalization: .words
                    )
                }
                textField("Email", text: $email, keyboard: .emailAddress)
                textField(
                    mode == .signUp ? "Password (min 8 chars)" : "Password",
                    text: $password,
                    secure: true
                )

                PrimaryButton(
                    mode.primaryCTA,
                    variant: .filled,
                    isLoading: isSubmitting,
                    isEnabled: canSubmit && !isSubmitting
                ) {
                    Task { await submitEmail() }
                }

                if mode == .signIn {
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
                } else {
                    Text("By creating an account you agree to our Terms and Privacy.")
                        .font(R.F.body(11, weight: .regular))
                        .foregroundStyle(R.C.fg3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }

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
                Text(mode == .signUp ? "Use email + password" : "Use email + password")
                    .font(R.F.mono(11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(R.C.fg2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
    }

    /// Form gate. Sign-in needs only email + password; sign-up also
    /// needs a non-empty display name + a stricter 8-char password.
    private var canSubmit: Bool {
        guard email.contains("@") else { return false }
        switch mode {
        case .signIn:
            return password.count >= 6
        case .signUp:
            return password.count >= 8 &&
                   displayName.trimmingCharacters(in: .whitespaces).count >= 2
        }
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
                Text(mode == .signIn ? "No account?" : "Have an account?")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                Button {
                    withAnimation(R.M.easeOut) {
                        mode = (mode == .signIn) ? .signUp : .signIn
                        showingEmail = true
                        resetSentMessage = nil
                    }
                    #if canImport(UIKit)
                    UISelectionFeedbackGenerator().selectionChanged()
                    #endif
                } label: {
                    Text(mode == .signIn ? "Create one" : "Sign in")
                        .font(R.F.body(12, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Form helpers

    private func textField(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        secure: Bool = false,
        autocapitalization: TextInputAutocapitalization = .never
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            Group {
                if secure {
                    SecureField("", text: text, prompt: Text(label).foregroundStyle(R.C.fg3))
                } else {
                    TextField("", text: text, prompt: Text(label).foregroundStyle(R.C.fg3))
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(autocapitalization)
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

    /// Single entrypoint for both modes — keeps the haptic + post-success
    /// branching logic in one place.
    private func submitEmail() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        isSubmitting = true
        defer { isSubmitting = false }

        switch mode {
        case .signIn:
            await auth.signIn(email: trimmedEmail, password: password)
        case .signUp:
            // Pull role from NavigationModel — OnboardView sets it on
            // role-picker continue. Fallback to "promoter" so users
            // who deep-link past onboarding still get a valid role.
            let role: String = (nav.role == .artist) ? "artist" : "promoter"
            await auth.signUp(
                email: trimmedEmail,
                password: password,
                role: role,
                displayName: trimmedName
            )
        }

        if auth.isSignedIn {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            // AppRoot watches AuthStore.state and routes to tabs.
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
                appleNonce = AppleNonceHelper.random()
            }
        case .failure:
            // User cancelled — no error banner.
            break
        }
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
