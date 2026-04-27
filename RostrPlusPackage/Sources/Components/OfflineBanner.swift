// OfflineBanner.swift
//
// Slim banner shown at the top of the screen when NetworkMonitor
// reports the device is offline. Hidden the rest of the time. Kept
// outside any tab / detail surface so it stays visible across nav
// transitions.

import SwiftUI
import DesignSystem

public struct OfflineBanner: View {
    @Environment(NetworkMonitor.self) private var monitor

    public init() {}

    public var body: some View {
        Group {
            if !monitor.isOnline {
                HStack(spacing: R.S.sm) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                        .accessibilityHidden(true)
                    Text(S.State.offline)
                        .font(R.F.body(12, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, R.S.xs)
                .padding(.horizontal, R.S.lg)
                .background {
                    Rectangle()
                        .fill(R.C.amber.opacity(0.9))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(S.State.offline)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: monitor.isOnline)
    }
}
