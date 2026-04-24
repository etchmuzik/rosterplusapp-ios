// AppRoot.swift
//
// The top-level view for the app. Mirrors the big switch at the bottom
// of InteractiveDevice in ios-app.jsx (line 767-786): pick a tab-root
// screen, then overlay any detail route from nav.stack on top.
//
// Placeholder views are used for every screen not yet implemented in
// Wave 1 — they render a friendly "Coming in Wave N" card in the same
// glass treatment so visual parity is still intact.

import SwiftUI
import DesignSystem

public struct AppRoot: View {
    @State private var nav = NavigationModel()

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            rootScreen
                .ignoresSafeArea(edges: .bottom) // tab bar is floating
            TabBar(active: Binding(
                get: { nav.tab },
                set: { nav.setTab($0) }
            ))
            .padding(.bottom, R.S.xxl)
        }
        .environment(nav)
        .background(R.C.bg0.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Routing

    @ViewBuilder
    private var rootScreen: some View {
        // Detail overlay wins. If the stack has anything, render the top
        // detail route full-screen. Otherwise fall back to the tab root.
        if let top = nav.top {
            DetailRouter(route: top, nav: nav)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            TabRootRouter(nav: nav)
        }
    }
}

// MARK: - Tab root

private struct TabRootRouter: View {
    @Bindable var nav: NavigationModel

    var body: some View {
        switch nav.tab {
        case .home:
            if nav.role == .artist {
                PlaceholderScreen(
                    title: "Artist dashboard",
                    note: "Lands in Wave 3 (artist-side flows)."
                )
            } else {
                HomeView(nav: nav)
            }
        case .roster:
            PlaceholderScreen(
                title: "Roster",
                note: "Wave 2 — core promoter loop."
            )
        case .bookings:
            PlaceholderScreen(
                title: "Bookings",
                note: "Wave 2 — with chart icon → analytics + review prompt."
            )
        case .inbox:
            PlaceholderScreen(
                title: "Inbox",
                note: "Wave 2 — threads + real-time on public.messages."
            )
        case .me:
            PlaceholderScreen(
                title: "Me / Settings",
                note: "Wave 4."
            )
        }
    }
}

// MARK: - Detail router

private struct DetailRouter: View {
    let route: Route
    @Bindable var nav: NavigationModel

    var body: some View {
        VStack(spacing: 0) {
            // Shared back-header for every detail screen. Kept inline
            // here because it's one of those "used 12 times, defined in
            // one place" widgets — nothing else needs to render it.
            HStack {
                Button {
                    nav.pop()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(R.F.mono(10, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(R.C.fg1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer()
            }
            .padding(.horizontal, R.S.lg)
            .padding(.top, R.S.md)

            PlaceholderScreen(
                title: routeTitle,
                note: "Detail stub. Full screen lands in its wave."
            )
        }
        .background(R.C.bg0)
    }

    private var routeTitle: String {
        switch route {
        case .artist:         return "Artist profile"
        case .booking:        return "Request booking"
        case .bookingDetail:  return "Booking detail"
        case .thread:         return "Message thread"
        case .epk:            return "EPK"
        case .contract:       return "Contract"
        case .notifications:  return "Notifications"
        case .review:         return "Leave a review"
        case .claim:          return "Claim profile"
        case .availability:   return "Availability"
        case .profileEdit:    return "Edit profile"
        case .invoice:        return "Invoice"
        case .signIn:         return "Sign in"
        case .onboard:        return "Welcome"
        }
    }
}

// MARK: - Placeholder

/// Used for screens scheduled in later waves. Renders in the same glass
/// treatment so visual parity is intact when you swap it for the real
/// view later.
private struct PlaceholderScreen: View {
    let title: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Spacer()
            Text(title)
                .font(R.F.display(26, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(R.C.fg1)
            Text(note)
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.xl)
        .padding(.horizontal, R.S.lg)
        .background(R.C.bg0)
    }
}
