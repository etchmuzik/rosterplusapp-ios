// ClaimView.swift — Screen 19
//
// Artist claim-profile verification checklist.
//
// Three steps to unlock full booking privileges:
//   1. Verify email   — derived from auth.users.email_confirmed_at
//   2. Link a social profile (IG / SoundCloud / Spotify)
//   3. Add a payout method
//
// Steps 2 + 3 don't have in-app flows yet; tapping their CTAs opens
// the support inbox so the user has an actual path forward rather
// than a fake-progress local-state toggle.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ClaimView: View {
    @Bindable var nav: NavigationModel
    @Environment(AuthStore.self) private var auth
    @Environment(ProfileStore.self) private var profile
    @Environment(\.openURL) private var openURL

    @State private var resendingEmail = false
    @State private var emailToast: String?

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    /// The user's real email — surfaced in the Step-1 copy so we
    /// don't leak the operator's address to every artist.
    private var userEmail: String {
        if let email = profile.current?.email, !email.isEmpty { return email }
        if case .signedIn(_, let email, _) = auth.state, !email.isEmpty { return email }
        return "your account email"
    }

    private var emailVerified: Bool { auth.isEmailConfirmed }
    /// Social + payout aren't backed by real flows yet. Treating
    /// them as in-progress (always "request via support") is the
    /// honest state — better than fake-completed local toggles.
    private var socialLinked: Bool { false }
    private var payoutAdded: Bool { false }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Claim profile", onBack: { nav.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.lg) {
                    hero
                    progressCard
                    if let toast = emailToast {
                        Text(toast)
                            .font(R.F.body(12, weight: .regular))
                            .foregroundStyle(R.C.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(R.S.md)
                            .glassSurface(cornerRadius: R.Rad.card)
                            .transition(.opacity)
                    }
                    stepsStack
                    helpCard
                    Color.clear.frame(height: R.S.xxl)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.sm)
            }
        }
        .background(R.C.bg0)
    }

    private func resendVerificationEmail() async {
        guard !resendingEmail, userEmail.contains("@") else { return }
        resendingEmail = true
        defer { resendingEmail = false }
        // Reuse the password-reset edge function as a session-recovery
        // signal; Supabase auth confirmation emails are sent
        // automatically on signup. Surface a clear path until a
        // dedicated "resend verification" edge function lands.
        let ok = await auth.forgotPassword(email: userEmail)
        emailToast = ok
            ? "We sent a sign-in link to \(userEmail) — open it on this device."
            : "Couldn’t send right now. Message support."
        Task {
            try? await Task.sleep(for: .seconds(5))
            emailToast = nil
        }
    }

    private func openSupport(subject: String) {
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        if let url = URL(string: "mailto:hi@rosterplus.io?subject=\(encoded)") {
            openURL(url)
        }
    }

    // MARK: — Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Three quick checks")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text("Claim your profile to accept bookings.")
                .font(R.F.display(22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(R.C.fg1)
            Text("Takes about two minutes. Promoters see a verified badge on your roster card once you're done.")
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    // MARK: — Progress

    private var progressCard: some View {
        let steps = [emailVerified, socialLinked, payoutAdded]
        let done = steps.filter { $0 }.count
        return HStack(alignment: .center, spacing: R.S.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(done) of 3 complete")
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(done == 3 ? "Verified — you're all set." : "Keep going — \(3 - done) left.")
                    .monoLabel(size: 9.5, tracking: 0.5, color: R.C.fg3)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < done ? R.C.green : R.C.glassMid)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .strokeBorder(i < done ? R.C.green.opacity(0.4) : R.C.borderSoft, lineWidth: R.S.hairline)
                        }
                }
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
    }

    // MARK: — Steps

    private var stepsStack: some View {
        VStack(spacing: R.S.sm) {
            StepCard(
                index: 1,
                glyph: "envelope",
                title: "Verify email",
                copy: emailVerified
                    ? "Email verified — \(userEmail) is confirmed."
                    : "We sent a verification email to \(userEmail). Tap the link inside. Resend if it didn't arrive.",
                isDone: emailVerified,
                ctaLabel: resendingEmail ? "Sending…" : "Resend",
                action: {
                    Task { await resendVerificationEmail() }
                }
            )
            StepCard(
                index: 2,
                glyph: "link",
                title: "Link a social profile",
                copy: "Pick one: Instagram, SoundCloud, or Spotify. Message support — we'll set this up while in-app linking ships.",
                isDone: socialLinked,
                ctaLabel: "Request",
                action: {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    openSupport(subject: "Link a social profile to my ROSTR+ artist account")
                }
            )
            StepCard(
                index: 3,
                glyph: "creditcard",
                title: "Add a payout method",
                copy: "IBAN or card. Payments land directly after each event. Message support to add yours while the in-app form ships.",
                isDone: payoutAdded,
                ctaLabel: "Request",
                action: {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    openSupport(subject: "Add a payout method to my ROSTR+ artist account")
                }
            )
        }
    }

    // MARK: — Help card

    private var helpCard: some View {
        HStack(alignment: .top, spacing: R.S.sm) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(R.C.fg2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Stuck on a step?")
                    .font(R.F.body(13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text("Message support — we respond within a few hours.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg2)
            }
            Spacer()
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Step card

private struct StepCard: View {
    let index: Int
    let glyph: String
    let title: String
    let copy: String
    let isDone: Bool
    let ctaLabel: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: R.S.md) {
            ZStack {
                RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                    .fill(isDone ? R.C.green.opacity(0.14) : R.C.glassMid)
                Image(systemName: isDone ? "checkmark" : glyph)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isDone ? R.C.green : R.C.fg1)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: R.S.xs) {
                    Text("Step \(index)")
                        .monoLabel(size: 8.5, tracking: 0.6, color: R.C.fg3)
                    if isDone {
                        Text(S.Common.done)
                            .monoLabel(size: 8.5, tracking: 0.6, color: R.C.green)
                    }
                }
                Text(title)
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(copy)
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .lineSpacing(2)

                if !isDone {
                    Button(action: action) {
                        Text(ctaLabel)
                            .font(R.F.mono(10, weight: .bold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(R.C.bg0)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                            .background { Capsule().fill(R.C.fg1) }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }
}

#if DEBUG
#Preview("ClaimView") {
    let nav = NavigationModel()
    return ClaimView(nav: nav)
        .environment(AuthStore())
        .environment(ProfileStore())
        .preferredColorScheme(.dark)
}
#endif
