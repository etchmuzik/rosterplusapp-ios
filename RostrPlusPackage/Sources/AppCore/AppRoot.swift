// AppRoot.swift
//
// Top-level view. Picks the tab-root screen, then overlays any detail
// route from nav.stack on top. Mirrors the big switch at the bottom of
// InteractiveDevice in ios-app.jsx.
//
// Wave 2 wires the promoter core loop — Home, Roster, Bookings, Inbox
// + all their detail screens. Screens not yet implemented fall back
// to a placeholder that renders in the same glass treatment so visual
// parity stays intact.

import SwiftUI
import DesignSystem

public struct AppRoot: View {
    @State private var nav = NavigationModel()

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            rootScreen
                .ignoresSafeArea(edges: .bottom)
            TabBar(active: Binding(
                get: { nav.tab },
                set: { nav.setTab($0) }
            ))
            .padding(.bottom, R.S.xxl)
            // Hide the tab bar when a detail route is pushed so it
            // doesn't cover the sticky action bar on detail screens.
            .opacity(nav.top == nil ? 1 : 0)
            .allowsHitTesting(nav.top == nil)
        }
        .environment(nav)
        .background(R.C.bg0.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Routing

    @ViewBuilder
    private var rootScreen: some View {
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
                ArtistDashboardView(nav: nav)
            } else {
                HomeView(nav: nav)
            }
        case .roster:
            RosterView(nav: nav)
        case .bookings:
            BookingsView(nav: nav)
        case .inbox:
            InboxView(nav: nav)
        case .me:
            SettingsView(nav: nav)
        }
    }
}

// MARK: - Detail router

private struct DetailRouter: View {
    let route: Route
    @Bindable var nav: NavigationModel

    var body: some View {
        Group {
            switch route {
            case .artist(let id):
                // Look up the mock artist; fall back to the first if not found.
                let artist = MockData.artists.first { String($0.id) == id } ?? MockData.artists[0]
                ArtistView(nav: nav, artist: artist)

            case .booking(let artistID):
                BookingView(nav: nav, artistID: artistID)

            case .bookingDetail(let id):
                BookingDetailView(nav: nav, bookingID: id)

            case .contract(let id):
                ContractView(nav: nav, contractID: id)

            case .thread(let id):
                ThreadView(nav: nav, threadID: id)

            case .invoice(let id):
                InvoiceView(nav: nav, bookingID: id)

            case .availability:
                AvailabilityView(nav: nav)

            case .profileEdit:
                ProfileEditView(nav: nav)

            case .epk(let id):
                EPKView(nav: nav, artistID: id)

            case .calendar:
                CalendarView(nav: nav)

            case .analytics:
                AnalyticsView(nav: nav)

            case .notifications:
                NotificationsView(nav: nav)

            case .review(let id):
                ReviewView(nav: nav, bookingID: id)

            case .claim:
                ClaimView(nav: nav)

            case .signIn:
                SignInView(nav: nav)

            case .onboard:
                OnboardView(nav: nav)
            }
        }
        .background(R.C.bg0)
    }
}
