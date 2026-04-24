// TabBar.swift
//
// Floating 5-tab glass bar — Home / Roster / Bookings / Inbox / Me.
// Matches the JSX `<TabBar>` at ios-app.jsx line 123.
//
// Positioning: 12pt from the sides, 24pt from the bottom safe area.
// Height self-sizes — ~58pt with the icon + label stack.
//
// Haptics: light impact on tap per the plan defaults.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct TabBar: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case home, roster, bookings, inbox, me
        public var id: String { rawValue }

        fileprivate var label: String {
            switch self {
            case .home:     return "Home"
            case .roster:   return "Roster"
            case .bookings: return "Bookings"
            case .inbox:    return "Inbox"
            case .me:       return "Me"
            }
        }
        fileprivate var iconKind: TabIcon.Kind {
            switch self {
            case .home:     return .home
            case .roster:   return .roster
            case .bookings: return .bookings
            case .inbox:    return .inbox
            case .me:       return .me
            }
        }
    }

    @Binding var active: Tab
    var onChange: ((Tab) -> Void)? = nil

    public init(active: Binding<Tab>, onChange: ((Tab) -> Void)? = nil) {
        self._active = active
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                TabButton(tab: tab, isActive: active == tab) {
                    // Light-impact haptic on tap — plan default.
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(R.M.easeOutFast) {
                        active = tab
                    }
                    onChange?(tab)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: R.Rad.tabBar, intensity: .strong)
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
        .padding(.horizontal, R.S.md)
    }
}

// MARK: - Per-tab button

private struct TabButton: View {
    let tab: TabBar.Tab
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                TabIconView(
                    tab.iconKind,
                    size: 20,
                    color: isActive ? R.C.fg1 : R.C.fg3,
                    filled: false
                )
                Text(tab.label)
                    .font(R.F.mono(8.5, weight: .semibold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(isActive ? R.C.fg1 : R.C.fg3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.08) : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

#if DEBUG
#Preview("TabBar — Home active") {
    TabBarPreviewHarness(active: .home)
        .preferredColorScheme(.dark)
}

private struct TabBarPreviewHarness: View {
    @State var active: TabBar.Tab
    var body: some View {
        VStack {
            Spacer()
            TabBar(active: $active)
        }
        .frame(width: 390, height: 200)
        .background(R.C.bg0)
    }
}
#endif
