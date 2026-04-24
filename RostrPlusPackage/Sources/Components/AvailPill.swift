// AvailPill.swift
//
// Availability pill — "Free / Tight / Booked" — shown on roster cards
// and artist detail headers. Matches the JSX `<AvailPill>` at
// ios-app.jsx line 56.

import SwiftUI
import DesignSystem

public struct AvailPill: View {
    public enum State: String {
        case avail, busy, booked
    }

    let state: State

    public init(_ state: State) {
        self.state = state
    }

    public var body: some View {
        let (color, label) = config(for: state)
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(R.F.mono(9, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(color)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .glassSurface(
            cornerRadius: R.Rad.pill,
            intensity: .soft,
            showsInnerHighlight: false
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Availability: \(label)")
    }

    private func config(for state: State) -> (Color, String) {
        switch state {
        case .avail:  return (R.C.green, "Free")
        case .busy:   return (R.C.amber, "Tight")
        case .booked: return (R.C.red,   "Booked")
        }
    }
}

#if DEBUG
#Preview("AvailPill — all states") {
    HStack(spacing: R.S.md) {
        AvailPill(.avail)
        AvailPill(.busy)
        AvailPill(.booked)
    }
    .padding()
    .background(R.C.bg0)
    .preferredColorScheme(.dark)
}
#endif
