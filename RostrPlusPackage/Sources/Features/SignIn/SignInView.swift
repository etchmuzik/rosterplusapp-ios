// SignInView.swift — Screen 20
//
// Sign-in entry. Port of `SignInScreen` at ios-app.jsx line 1776.
// Apple + Google OAuth buttons plus an email fallback, matched to the
// web app's auth.html flow.
//
// Per plan: OAuth scaffolded with Apple + Google buttons, real wire
// up lives behind a feature flag until team+bundle IDs are supplied.
// Pressing the buttons today fires a haptic + dismisses — enough to
// demo the visual system.

import SwiftUI
import AuthenticationServices
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct SignInView: View {
    @Bindable var nav: NavigationModel

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingEmail: Bool = false

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
                },
                onCompletion: { _ in
                    finishSignIn()
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous))
            .accessibilityLabel("Sign in with Apple")

            Button {
                finishSignIn()
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
                PrimaryButton("Sign in", variant: .filled, isEnabled: canSubmit) {
                    finishSignIn()
                }
                Button {
                    // Wave 5: real forgot-password flow
                } label: {
                    Text("Forgot password?")
                        .monoLabel(size: 10, tracking: 0.4, color: R.C.fg2)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
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

    // MARK: — Footer

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("No account?")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                Button {
                    // Future: push a distinct sign-up flow. For now,
                    // same screen accepts new creds by routing them
                    // through the `signup` edge function server-side.
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

    // MARK: — Helpers

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

    private func finishSignIn() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        // For now, just dismiss into the app. Real auth flow wires to
        // AuthStore.signIn(with:) in a later pass.
        nav.clearStack()
        nav.setTab(.home)
    }
}

#if DEBUG
#Preview("SignInView") {
    let nav = NavigationModel()
    return SignInView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
