// StatusTag.swift
//
// Booking status tag — "Confirmed / Pending / Contracted / Completed /
// Cancelled". A squarer, flatter variant of AvailPill — used inside
// detail rows where a full glass pill would compete with the row's own
// glass treatment. Matches `<StatusTag>` at ios-app.jsx line 75.

import SwiftUI
import DesignSystem

public struct StatusTag: View {
    public enum Status: String, CaseIterable {
        case confirmed
        case pending
        case contracted
        case completed
        case cancelled
    }

    let status: Status

    public init(_ status: Status) {
        self.status = status
    }

    public var body: some View {
        let (color, label) = config(for: status)
        Text(label)
            .font(R.F.mono(9, weight: .semibold))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(R.C.glassLo, in: RoundedRectangle(cornerRadius: R.Rad.xs, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.xs, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(label)")
    }

    private func config(for status: Status) -> (Color, String) {
        switch status {
        case .confirmed:  return (R.C.green, "Confirmed")
        case .pending:    return (R.C.amber, "Pending")
        case .contracted: return (R.C.blue,  "Contracted")
        case .completed:  return (R.C.fg2,   "Completed")
        case .cancelled:  return (R.C.red,   "Cancelled")
        }
    }
}

#if DEBUG
#Preview("StatusTag — all statuses") {
    VStack(alignment: .leading, spacing: R.S.sm) {
        ForEach(StatusTag.Status.allCases, id: \.rawValue) { s in
            StatusTag(s)
        }
    }
    .padding()
    .background(R.C.bg0)
    .preferredColorScheme(.dark)
}
#endif
