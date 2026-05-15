// FailureCard.swift
//
// Shared error-state card. Renders a heading + raw error message + a
// "Try again" CTA wired to the caller's retry closure. Use anywhere a
// store can land in `state == .failed(...)` so the user always has a
// way out (instead of staring at a forever-skeleton).
//
// Originally lived as a private view inside RosterView; lifted into
// Components/ so Artist / EPK / BookingDetail can share it. The
// heading is a `LocalizedStringResource` so each call site can pass
// its own surface-specific copy ("Couldn't load this artist", etc.).

import SwiftUI
import DesignSystem

public struct FailureCard: View {
    let heading: LocalizedStringResource
    let message: String
    let retry: () -> Void

    public init(
        heading: LocalizedStringResource,
        message: String,
        retry: @escaping () -> Void
    ) {
        self.heading = heading
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack(spacing: R.S.sm) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(R.C.red)
                Text(heading)
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
            }
            Text(message)
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg3)
                .lineLimit(3)
            PrimaryButton(S.Common.tryAgain, variant: .ghost) {
                retry()
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }
}
