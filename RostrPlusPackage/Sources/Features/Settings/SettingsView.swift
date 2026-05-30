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
    @Environment(ProfileStore.self) private var profileStore
    @Environment(PushStore.self) private var push

    /// Local working copy of the five notification switches, seeded from
    /// the loaded profile and written back to `profiles.notification_prefs`
    /// on every flip. `nil` until the profile resolves — the toggles read
    /// the opt-out-safe all-on default in the meantime so they never show
    /// "off" for a channel that's actually on.
    @State private var prefs: NotificationPrefs?

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var hideFromSearch = false

    /// Transient message shown when a notification-pref write fails. The
    /// optimistic toggle reverts on its own (via the .onChange re-seed
    /// from the store rollback) — this explains why, so the snap-back
    /// isn't silent motion. Mirrors the web's "Failed to save" toast.
    @State private var prefsErrorToast: String?

    @Environment(\.openURL) private var openURL
    @State private var passwordResetToast: String?
    @State private var isSendingReset = false

    /// Bridges the bell toggle to PushStore.authorization. Reading
    /// returns the cached iOS permission state; setting triggers the
    /// OS prompt (first flip) or a no-op if already granted/denied.
    private var pushEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                push.authorization == .authorized || push.authorization == .provisional
            },
            set: { wantsOn in
                if wantsOn {
                    Task { await push.requestAuthorization() }
                } else {
                    // iOS won't let us revoke on the app's behalf —
                    // send the user to Settings.app via an alert or
                    // fall back to local state. Until Wave 5.7 adds
                    // that UX, we just re-sync with the OS state.
                    Task { await push.refreshAuthorization() }
                }
            }
        )
    }

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    /// The prefs the toggles render against: the local working copy once
    /// seeded, else the profile's resolved prefs, else all-on. Keeps the
    /// switches honest before the local `@State` is populated.
    private var effectivePrefs: NotificationPrefs {
        prefs ?? profileStore.current?.prefs ?? .defaultAllOn
    }

    /// Builds a binding for one notification key. Reading reflects the
    /// current working copy; writing mutates that copy and persists ALL
    /// five keys to `profiles.notification_prefs` (never a partial
    /// object — the hidden role-gated key rides along unchanged, matching
    /// the web writer at settings.html:269).
    private func prefBinding(_ keyPath: WritableKeyPath<NotificationPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { effectivePrefs[keyPath: keyPath] },
            set: { newValue in
                var next = effectivePrefs
                next[keyPath: keyPath] = newValue
                prefs = next
                if case .signedIn(let userID, _, _) = auth.state {
                    Task {
                        await profileStore.updateNotificationPrefs(next, userID: userID)
                        // The store rolls back its loaded state on failure
                        // (which re-seeds the toggle via .onChange); surface
                        // a transient note so the snap-back isn't silent.
                        if profileStore.lastError != nil {
                            showPrefsError()
                        }
                    }
                }
            }
        )
    }

    /// Show the pref-write failure note for a few seconds, then clear it.
    private func showPrefsError() {
        withAnimation { prefsErrorToast = "Couldn’t save that preference — check your connection and try again." }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation { prefsErrorToast = nil }
        }
    }

    /// Derived email for the profile card. Falls back to the placeholder
    /// only before AuthStore resolves — once signed in we show the real
    /// address from the current session.
    private var displayEmail: String {
        if let profileEmail = profileStore.current?.email, !profileEmail.isEmpty {
            return profileEmail
        }
        if case .signedIn(_, let email, _) = auth.state, !email.isEmpty {
            return email
        }
        return "—"
    }

    /// Display name falls back through profile → email local-part → "You".
    private var displayName: String {
        if let name = profileStore.current?.displayName, !name.isEmpty {
            return name
        }
        if case .signedIn(_, let email, _) = auth.state {
            let local = email.split(separator: "@").first.map(String.init) ?? "You"
            let token = local.split(separator: ".").first.map(String.init) ?? local
            return token.prefix(1).uppercased() + token.dropFirst()
        }
        return "You"
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: R.S.xl) {
                header
                profileCard
                accountSection
                if let toast = passwordResetToast {
                    Text(toast)
                        .font(R.F.body(12, weight: .regular))
                        .foregroundStyle(R.C.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(R.S.md)
                        .glassSurface(cornerRadius: R.Rad.card)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                preferencesSection
                if let toast = prefsErrorToast {
                    Text(toast)
                        .font(R.F.body(12, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(R.S.md)
                        .glassSurface(cornerRadius: R.Rad.card)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
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
        // Seed the local working copy from server truth on first render,
        // and re-seed if the profile reloads underneath us (scenePhase
        // resync). Keeps the toggles in sync with what the server holds.
        .onChange(of: profileStore.current?.notificationPrefs, initial: true) { _, _ in
            if let serverPrefs = profileStore.current?.notificationPrefs {
                prefs = serverPrefs
            }
        }
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
            Cover(seed: displayName, size: 56, cornerRadius: R.Rad.card)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
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
                Text(S.Common.edit)
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
                // Self-service email change isn't in-app yet — route via
                // the support inbox so the user has an actual path
                // forward instead of a dead row.
                if let url = URL(string: "mailto:hi@rosterplus.io?subject=Change%20email%20on%20my%20ROSTR%2B%20account&body=Current%20email%3A%20\(displayEmail)%0A%0ANew%20email%3A%20") {
                    openURL(url)
                }
            }
            SettingsRow(icon: "lock", label: "Password", trailing: .chevron) {
                Task { await sendPasswordReset() }
            }
        }
    }

    /// Sends a password-reset email to the signed-in user via the
    /// existing AuthStore flow. Shows a transient toast on success.
    private func sendPasswordReset() async {
        guard !isSendingReset, displayEmail.contains("@") else { return }
        isSendingReset = true
        defer { isSendingReset = false }
        let ok = await auth.forgotPassword(email: displayEmail)
        passwordResetToast = ok
            ? "Password-reset email sent to \(displayEmail)."
            : "Couldn’t send reset email — try again later."
        Task {
            try? await Task.sleep(for: .seconds(4))
            passwordResetToast = nil
        }
    }

    // MARK: — Preferences

    private var preferencesSection: some View {
        SettingsSection(title: "Preferences") {
            ToggleRow(icon: "bell", label: "Push notifications", isOn: pushEnabledBinding)
            ToggleRow(icon: "paperplane", label: "Email updates", isOn: prefBinding(\.email))
            ToggleRow(icon: "calendar", label: "Booking alerts", isOn: prefBinding(\.bookings))
            ToggleRow(icon: "message", label: "Message alerts", isOn: prefBinding(\.messages))
            // Role-gated, matching the web: promoters get contract
            // notifications, artists get payout notifications. The hidden
            // key still round-trips at its saved value on every write.
            if nav.role == .promoter {
                ToggleRow(icon: "doc.text", label: "Contract alerts", isOn: prefBinding(\.contracts))
            }
            if nav.role == .artist {
                ToggleRow(icon: "creditcard", label: "Payout alerts", isOn: prefBinding(\.payouts))
            }
            ToggleRow(icon: "waveform", label: "Haptics", isOn: $hapticsEnabled)
        }
    }

    // MARK: — Privacy

    private var privacySection: some View {
        SettingsSection(title: "Privacy") {
            ToggleRow(icon: "eye.slash", label: "Hide from search", isOn: $hideFromSearch)
            SettingsRow(icon: "hand.raised", label: "Blocked accounts", value: "0", trailing: .chevron) {
                // Block-list management isn't in-app yet — route via
                // the support inbox until the screen ships.
                if let url = URL(string: "mailto:hi@rosterplus.io?subject=Manage%20blocked%20accounts") {
                    openURL(url)
                }
            }
        }
    }

    // MARK: — Support

    private var supportSection: some View {
        SettingsSection(title: "Support") {
            SettingsRow(icon: "questionmark.circle", label: "Help centre", trailing: .chevron) {
                if let url = URL(string: "https://rosterplus.io/help") { openURL(url) }
            }
            SettingsRow(icon: "bubble.left", label: "Contact support", trailing: .chevron) {
                if let url = URL(string: "mailto:hi@rosterplus.io?subject=ROSTR%2B%20support%20request") {
                    openURL(url)
                }
            }
            SettingsRow(icon: "doc.text", label: "Terms of service", trailing: .chevron) {
                if let url = URL(string: "https://rosterplus.io/terms") { openURL(url) }
            }
            SettingsRow(icon: "hand.thumbsup", label: "Privacy policy", trailing: .chevron) {
                if let url = URL(string: "https://rosterplus.io/privacy") { openURL(url) }
            }
        }
    }

    // MARK: — Build footer

    private var buildFooter: some View {
        VStack(alignment: .center, spacing: 3) {
            Text("ROSTR+ iOS")
                .monoLabel(size: 9, tracking: 0.8, color: R.C.fg3)
            Text(buildString)
                .font(R.F.mono(9, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(R.C.fg3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, R.S.sm)
    }

    /// Pulls CFBundleShortVersionString + CFBundleVersion from the
    /// app shell's Info.plist so the footer doesn't lie about which
    /// build the user is running.
    private var buildString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) · Build \(build)"
    }

    // MARK: — Sign out

    private var signOutButton: some View {
        PrimaryButton("Sign out", variant: .destructive) {
            #if canImport(UIKit)
            Haptics.warning()
            #endif
            // Clear push token first so the device stops receiving
            // notifications for the signed-out user. AuthStore then
            // flips to .signedOut and AppRoot swaps shells.
            Task {
                if case .signedIn(let userID, _, _) = auth.state {
                    await push.clearToken(for: userID)
                }
                await auth.signOut()
            }
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
    let profile = ProfileStore()
    let push = PushStore()
    return SettingsView(nav: nav)
        .environment(auth)
        .environment(profile)
        .environment(push)
        .preferredColorScheme(.dark)
}
#endif
