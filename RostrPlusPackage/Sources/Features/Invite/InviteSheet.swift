// InviteSheet.swift
//
// Modal sheet for inviting a new artist (or co-promoter) to ROSTR+.
// Wired from Roster's nav header. Submits through InvitationsStore;
// success closes the sheet with a haptic + toast.
//
// Mirrors the web's invite.html flow but stripped to the four fields
// that matter for a phone-first compose: email, display name, role,
// optional personal note.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct InviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @Environment(InvitationsStore.self) private var store

    @State private var email: String = ""
    @State private var name: String = ""
    @State private var role: String = "artist"
    @State private var message: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            handle
                .padding(.top, R.S.xs)
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.lg) {
                    headline
                    formCard
                    if case .failed(let m) = store.sendResult {
                        errorBanner(m)
                    }
                    if case .sent(let to) = store.sendResult {
                        successBanner("Invite sent to \(to)")
                    }
                    Color.clear.frame(height: R.S.md)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.md)
            }
            footer
        }
        .background(R.C.bg0)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear { store.reset() }
    }

    // MARK: — Bits

    private var handle: some View {
        Capsule()
            .fill(R.C.borderMid)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Invite an artist")
                .font(R.F.display(28, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(R.C.fg1)
            Text("They'll get an email with a one-click claim link.")
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            roleSegment
            field("Email", text: $email, keyboard: .emailAddress)
            field("Display name", text: $name, capitalization: .words)
            messageField
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    private var roleSegment: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Role")
                .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            HStack(spacing: 4) {
                ForEach(["artist", "promoter"], id: \.self) { r in
                    Button {
                        if role != r {
                            role = r
                            #if canImport(UIKit)
                            UISelectionFeedbackGenerator().selectionChanged()
                            #endif
                        }
                    } label: {
                        Text(r.capitalized)
                            .font(R.F.mono(10, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(role == r ? R.C.bg0 : R.C.fg2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                                    .fill(role == r ? R.C.fg1 : Color.clear)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(R.C.glassLo)
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
        }
    }

    private var messageField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Personal note · optional")
                .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            TextEditor(text: $message)
                .font(R.F.body(13))
                .foregroundStyle(R.C.fg1)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 130)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .fill(R.C.glassLo)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                }
        }
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .never
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            TextField(
                "",
                text: text,
                prompt: Text(label).foregroundStyle(R.C.fg3)
            )
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
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

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: R.S.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(R.C.red)
            Text(message)
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg1)
            Spacer(minLength: 0)
        }
        .padding(R.S.md)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(R.C.red.opacity(0.10))
        }
    }

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: R.S.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(R.C.green)
            Text(message)
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg1)
            Spacer(minLength: 0)
        }
        .padding(R.S.md)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(R.C.green.opacity(0.10))
        }
    }

    private var isWorking: Bool {
        if case .sending = store.sendResult { return true }
        return false
    }

    private var canSend: Bool {
        email.contains("@") &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isWorking
    }

    private var footer: some View {
        HStack(spacing: R.S.sm) {
            PrimaryButton("Cancel", variant: .ghost) { dismiss() }
            PrimaryButton(
                "Send invite",
                variant: .filled,
                isLoading: isWorking,
                isEnabled: canSend
            ) {
                Task { await submit() }
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, R.S.lg)
        .padding(.vertical, R.S.md)
    }

    private func submit() async {
        guard case .signedIn(let userID, let email, _) = auth.state else {
            return
        }
        let inviterName = profileStore.current?.displayName
            ?? email.split(separator: "@").first.map(String.init)
            ?? "A ROSTR+ promoter"
        await store.send(
            email: self.email,
            name: name,
            role: role,
            message: message,
            invitedBy: userID,
            inviterName: inviterName
        )
        if case .sent = store.sendResult {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            // Auto-dismiss after a beat so the user sees the success banner.
            try? await Task.sleep(for: .seconds(0.9))
            dismiss()
        } else {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
        }
    }
}

#if DEBUG
#Preview("InviteSheet") {
    let auth = AuthStore()
    let profile = ProfileStore()
    let invs = InvitationsStore()
    return Color.black
        .sheet(isPresented: .constant(true)) {
            InviteSheet()
                .environment(auth)
                .environment(profile)
                .environment(invs)
        }
        .preferredColorScheme(.dark)
}
#endif
