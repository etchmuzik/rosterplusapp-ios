// NavHeader.swift
//
// Shared back-header for every push-stack detail screen. Matches the
// top bar shown across ArtistScreen, BookingScreen, ThreadScreen etc.
// in ios-app.jsx — a thin chrome row with a chevron-left back button,
// title in display font, and optional trailing action slot.
//
// Kept tiny on purpose: one behaviour (back), one title, optional
// trailing content. No overflow menu, no large-title collapse — the
// JSX prototype doesn't use either.

import SwiftUI
import DesignSystem

public struct NavHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    let trailing: Trailing

    public init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: R.S.md) {
            Button(action: onBack) {
                // 36pt hit target with the chevron centred. Matches the
                // tap-target size of the bell button on Home for rhythm.
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                    .frame(width: 36, height: 36)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .fill(R.C.glassLo)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(S.Common.back)

            Text(title)
                .font(R.F.display(20, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(R.C.fg1)
                .lineLimit(1)

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal, R.S.lg)
        .padding(.vertical, R.S.xs)
    }
}
