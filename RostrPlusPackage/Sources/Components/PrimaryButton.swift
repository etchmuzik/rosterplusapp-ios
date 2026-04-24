// PrimaryButton.swift
//
// The monochrome near-white CTA used across the app. Per the locked
// plan: primary CTAs are C.fg1 on C.bg0 (black text on near-white
// fill). Gold is reserved for pending states, NOT buttons.
//
// Three variants, all glass-consistent:
//   .filled     — solid fg1, black text. Most primary CTAs.
//   .ghost      — transparent with hairline border. Secondary.
//   .destructive— red tint, used for cancel/delete confirmations.
//
// Haptics: light on tap (per plan defaults). Successful submit upgrades
// to a .success notification haptic at the call site, not here.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct PrimaryButton: View {
    public enum Variant {
        case filled
        case ghost
        case destructive
    }

    let title: String
    let variant: Variant
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    public init(
        _ title: String,
        variant: Variant = .filled,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        } label: {
            content
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            Text(title)
                .font(R.F.mono(11, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(foregroundColor)
                .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(foregroundColor)
                    .scaleEffect(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                .fill(backgroundFill)
        }
        .overlay {
            if variant == .ghost {
                RoundedRectangle(cornerRadius: R.Rad.button, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .filled:      return R.C.bg0
        case .ghost:       return R.C.fg1
        case .destructive: return R.C.red
        }
    }

    private var backgroundFill: Color {
        switch variant {
        case .filled:      return R.C.fg1
        case .ghost:       return R.C.glassLo
        case .destructive: return Color(hex: 0xf3a0a0, opacity: 0.12)
        }
    }
}

#if DEBUG
#Preview("PrimaryButton variants") {
    VStack(spacing: R.S.md) {
        PrimaryButton("Request booking", variant: .filled) {}
        PrimaryButton("Message artist", variant: .ghost) {}
        PrimaryButton("Cancel booking", variant: .destructive) {}
        PrimaryButton("Loading…", isLoading: true) {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .background(R.C.bg0)
    .preferredColorScheme(.dark)
}
#endif
