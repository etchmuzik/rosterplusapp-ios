// DeleteAccountView.swift
//
// Self-service account deletion (App Store Guideline 5.1.1(v)). Reached
// from Settings → "Delete account". Requires the user to type DELETE to
// confirm, then calls AuthStore.deleteAccount() (→ the `delete-account`
// edge function), which permanently removes the auth user and scrubs the
// account's PII. On success the session is torn down and AppRoot swaps to
// the sign-in shell.
//
// Renders its own back button via NavHeader (nav.pop()) — every detail
// Route is responsible for its own back affordance, enforced by
// NavigationBackAffordanceTests.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct DeleteAccountView: View {
    @Bindable var nav: NavigationModel
    @Environment(AuthStore.self) private var auth

    /// The user must type this exact word to arm the delete button — a
    /// deliberate friction step so deletion can't happen by accident. The
    /// edge function echoes the same check server-side.
    private static let confirmWord = "DELETE"

    @State private var typed = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    private var isArmed: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines) == Self.confirmWord
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: R.S.xl) {
                NavHeader(title: "Delete account", onBack: { nav.pop() })

                warningCard
                whatHappensCard
                confirmField

                if let errorMessage {
                    Text(errorMessage)
                        .font(R.F.body(12, weight: .regular))
                        .foregroundStyle(R.C.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(R.S.md)
                        .glassSurface(cornerRadius: R.Rad.card)
                        .transition(.opacity)
                }

                PrimaryButton(
                    "Delete my account",
                    variant: .destructive,
                    isLoading: isDeleting,
                    isEnabled: isArmed && !isDeleting
                ) {
                    Task { await performDelete() }
                }

                Text("This is permanent and can’t be undone.")
                    .font(R.F.body(11, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .frame(maxWidth: .infinity, alignment: .center)

                Color.clear.frame(height: 60)
            }
            .padding(.horizontal, R.S.lg)
            .padding(.top, R.S.sm)
        }
        .background(R.C.bg0)
    }

    // MARK: — Cards

    private var warningCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack(spacing: R.S.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(R.C.red)
                Text("Delete your ROSTR+ account")
                    .font(R.F.body(15, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
            }
            Text("Deleting your account permanently removes your profile and personal data from ROSTR+. You can’t sign back in afterwards.")
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(R.S.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    private var whatHappensCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("WHAT GETS DELETED")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            bullet("Your profile — name, email, phone, photo, bio.")
            bullet("Your artist page and EPK, if you have one.")
            bullet("Your push registration and notification settings.")
            Text("WHAT STAYS")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                .padding(.top, R.S.xs)
            bullet("Bookings and contracts you share with another party stay on their side as records, shown as “Deleted user.” Any of your still-open requests are cancelled.")
        }
        .padding(R.S.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: R.S.sm) {
            Text("•")
                .font(R.F.body(13, weight: .bold))
                .foregroundStyle(R.C.fg3)
            Text(text)
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var confirmField: some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Text("Type DELETE to confirm")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            TextField("DELETE", text: $typed)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(R.F.mono(14, weight: .semibold))
                .foregroundStyle(R.C.fg1)
                .padding(R.S.md)
                .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
                .accessibilityLabel("Type DELETE to confirm account deletion")
        }
    }

    // MARK: — Action

    private func performDelete() async {
        guard isArmed, !isDeleting else { return }
        isDeleting = true
        withAnimation { errorMessage = nil }
        #if canImport(UIKit)
        Haptics.warning()
        #endif

        // Note: we deliberately do NOT clear the push token up front. On
        // success the edge function hard-deletes the auth user (device_tokens
        // cascades server-side) and AppRoot's .signedOut teardown clears the
        // local token; on failure the user stays signed in and must keep
        // receiving pushes — pre-clearing left them silently unsubscribed
        // until the next launch.
        let ok = await auth.deleteAccount()
        if ok {
            // AuthStore flipped to .signedOut; AppRoot swaps to the
            // sign-in shell, so this view goes away with the stack.
            #if canImport(UIKit)
            Haptics.success()
            #endif
        } else {
            isDeleting = false
            #if canImport(UIKit)
            Haptics.error()
            #endif
            withAnimation {
                errorMessage = auth.lastError ?? "Couldn’t delete your account. Try again."
            }
        }
    }
}

#if DEBUG
#Preview("DeleteAccountView") {
    let nav = NavigationModel()
    let auth = AuthStore()
    return DeleteAccountView(nav: nav)
        .environment(auth)
        .preferredColorScheme(.dark)
}
#endif
