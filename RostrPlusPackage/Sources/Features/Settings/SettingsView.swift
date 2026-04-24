// SettingsView.swift — Screen 15
//
// Me / Settings. Port of `SettingsScreen` at ios-app.jsx line 1351.
// Lives on the .me tab (not a push). Sections:
//
//   1. Profile header   — Cover + display name + email + "Edit profile"
//   2. Account          — Claim profile, Change email, Password
//   3. Preferences      — Push notifications toggle, Email updates toggle,
//                         Haptics toggle
//   4. Privacy          — Hide from search toggle, Block list row
//   5. Support          — Help centre, Contact support, Terms, Privacy
//   6. Build            — tiny footer with version + build
//   7. Sign out         — destructive button
//
// Pure nav + state in this wave. Real Apple OAuth, email edits, and
// privacy toggles land when backends are wired.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct SettingsView: View {
    @Bindable var nav: NavigationModel
    @Environment(AuthStore.self) private var auth

    @State private var pushEnabled = true
    @State private var emailUpdates = true
    @State private var hapticsEnabled = true
    @State private var hideFromSearch = false

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    /// Derived email for the profile card. Falls back to the placeholder
    /// only before AuthStore resolves — once signed in we show the real
    /// address from the current session.
    private var displayEmail: String {
        if case .signedIn(_, let email, _) = auth.state, !email.isEmpty {
            return email
        }
        return "hesham@beyondmngmt.ae"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: R.S.xl) {
                header
                profileCard
                accountSection
                preferencesSection
                privacySection
                supportSection
                buildFooter
                signOutButton
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, R.S.lg)
            .padding(.top, R.S.sm)
        }
        .background(R.C.bg0)
    }

    // MARK: — Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Me")
                .font(R.F.display(30, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(R.C.fg1)
            Text("\(nav.role == .artist ? "Artist" : "Promoter") account")
                .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
        }
    }

    // MARK: — Profile card

    private var profileCard: some View {
        HStack(alignment: .center, spacing: R.S.md) {
            Cover(seed: "Hesham", size: 56, cornerRadius: R.Rad.card)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hesham Saied")
                    .font(R.F.body(15, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(displayEmail)
                    .font(R.F.mono(10.5, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(R.C.fg3)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                nav.push(.profileEdit)
            } label: {
                Text("Edit")
                    .monoLabel(size: 10, tracking: 0.6, color: R.C.fg1)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background { Capsule().fill(R.C.glassLo) }
                    .overlay { Capsule().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline) }
            }
            .buttonStyle(.plain)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Account

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            SettingsRow(icon: "checkmark.seal", label: "Claim profile", trailing: .chevron) {
                nav.push(.claim)
            }
            SettingsRow(icon: "envelope", label: "Change email", value: displayEmail, trailing: .chevron) {
                // Placeholder
            }
            SettingsRow(icon: "lock", label: "Password", trailing: .chevron) {
                // Placeholder
            }
        }
    }

    // MARK: — Preferences

    private var preferencesSection: some View {
        SettingsSection(title: "Preferences") {
            ToggleRow(icon: "bell", label: "Push notifications", isOn: $pushEnabled)
            ToggleRow(icon: "paperplane", label: "Email updates", isOn: $emailUpdates)
            ToggleRow(icon: "waveform", label: "Haptics", isOn: $hapticsEnabled)
        }
    }

    // MARK: — Privacy

    private var privacySection: some View {
        SettingsSection(title: "Privacy") {
            ToggleRow(icon: "eye.slash", label: "Hide from search", isOn: $hideFromSearch)
            SettingsRow(icon: "hand.raised", label: "Blocked accounts", value: "0", trailing: .chevron) {
                // Placeholder
            }
        }
    }

    // MARK: — Support

    private var supportSection: some View {
        SettingsSection(title: "Support") {
            SettingsRow(icon: "questionmark.circle", label: "Help centre", trailing: .chevron) {}
            SettingsRow(icon: "bubble.left", label: "Contact support", trailing: .chevron) {}
            SettingsRow(icon: "doc.text", label: "Terms of service", trailing: .chevron) {}
            SettingsRow(icon: "hand.thumbsup", label: "Privacy policy", trailing: .chevron) {}
        }
    }

    // MARK: — Build footer

    private var buildFooter: some View {
        VStack(alignment: .center, spacing: 3) {
            Text("ROSTR+ iOS")
                .monoLabel(size: 9, tracking: 0.8, color: R.C.fg3)
            Text("v0.1.0 · Build 1")
                .font(R.F.mono(9, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(R.C.fg3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, R.S.sm)
    }

    // MARK: — Sign out

    private var signOutButton: some View {
        PrimaryButton("Sign out", variant: .destructive) {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
            // AuthStore flips to .signedOut which makes AppRoot swap
            // in the UnauthenticatedShell automatically. No manual
            // nav.push(.signIn) needed — the boot gate handles it.
            Task { await auth.signOut() }
        }
    }
}

// MARK: - Section wrapper

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Text(title)
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                .padding(.horizontal, R.S.xs)
            VStack(spacing: R.S.hairline) {
                content()
            }
            .padding(R.S.xxs)
            .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
        }
    }
}

// MARK: - Row variants

private enum RowTrailing {
    case chevron
    case none
}

private struct SettingsRow: View {
    let icon: String
    let label: String
    var value: String? = nil
    var trailing: RowTrailing = .chevron
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: R.S.md) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                    .frame(width: 32, height: 32)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                            .fill(R.C.glassLo)
                    }
                Text(label)
                    .font(R.F.body(13.5, weight: .regular))
                    .foregroundStyle(R.C.fg1)
                Spacer()
                if let value {
                    Text(value)
                        .monoLabel(size: 10, tracking: 0.4, color: R.C.fg3)
                }
                if trailing == .chevron {
                    ChevronRightIcon(size: 11, color: R.C.fg3)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, R.S.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ToggleRow: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: R.S.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(R.C.fg1)
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                        .fill(R.C.glassLo)
                }
            Text(label)
                .font(R.F.body(13.5, weight: .regular))
                .foregroundStyle(R.C.fg1)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(R.C.fg1)
                .accessibilityLabel(label)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, R.S.xs)
    }
}

#if DEBUG
#Preview("SettingsView") {
    let nav = NavigationModel()
    let auth = AuthStore()
    return SettingsView(nav: nav)
        .environment(auth)
        .preferredColorScheme(.dark)
}
#endif
