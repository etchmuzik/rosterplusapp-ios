// AppRoot.swift
//
// Top-level view + boot gate. Decides whether to show:
//   1. A loading shell while AuthStore checks for a cached session
//   2. Onboarding (first launch only) + SignIn (no session)
//   3. The tab surface (signed in)
//
// AuthStore drives the three-way state machine; NavigationModel handles
// tab + push-stack routing inside the authenticated shell.

import SwiftUI
import DesignSystem

public struct AppRoot: View {
    @State private var nav = NavigationModel()
    @State private var auth = AuthStore()
    @State private var roster = RosterStore()
    @State private var bookings = BookingsStore()
    @State private var inbox = InboxStore()
    @State private var notifications = NotificationsStore()
    @State private var payments = PaymentsStore()
    @State private var artistDetail = ArtistDetailStore()
    // AnalyticsStore derives from BookingsStore; constructed lazily so
    // it captures the same instance we inject below.
    @State private var analytics: AnalyticsStore? = nil

    public init() {}

    public var body: some View {
        Group {
            switch auth.state {
            case .unknown:
                LoadingShell()

            case .signedOut:
                UnauthenticatedShell(nav: nav)

            case .signedIn(let userID, _, let role):
                AuthenticatedShell(nav: nav)
                    .onAppear {
                        // Keep NavigationModel.role in sync with the
                        // server-side role after every fresh sign-in.
                        let svcRole: Role = role == "artist" ? .artist : .promoter
                        if nav.role != svcRole { nav.setRole(svcRole) }
                        // Prefetch all the user-scoped stores. Each is
                        // idempotent — calling during an in-flight fetch
                        // no-ops.
                        bookings.refresh(for: userID, role: svcRole)
                        inbox.refresh(for: userID)
                        notifications.refresh(for: userID)
                        payments.refresh(for: userID)
                        if analytics == nil {
                            analytics = AnalyticsStore(bookings: bookings)
                        }
                    }
            }
        }
        .environment(nav)
        .environment(auth)
        .environment(roster)
        .environment(bookings)
        .environment(inbox)
        .environment(notifications)
        .environment(payments)
        .environment(artistDetail)
        .environment(analytics ?? AnalyticsStore(bookings: bookings))
        .background(R.C.bg0.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            await auth.loadSession()
            await auth.startObserving()
        }
    }
}

// MARK: - Loading

private struct LoadingShell: View {
    var body: some View {
        VStack(spacing: R.S.md) {
            Text("ROSTR+")
                .font(R.F.display(24, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(R.C.fg1)
            ProgressView()
                .progressViewStyle(.circular)
                .tint(R.C.fg1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(R.C.bg0)
    }
}

// MARK: - Unauthenticated shell

private struct UnauthenticatedShell: View {
    @Bindable var nav: NavigationModel

    private var onboardCompleted: Bool {
        UserDefaults.standard.bool(forKey: kOnboardCompletedKey)
    }

    var body: some View {
        if !onboardCompleted {
            OnboardView(nav: nav)
        } else {
            SignInView(nav: nav)
        }
    }
}

// MARK: - Authenticated shell

private struct AuthenticatedShell: View {
    @Bindable var nav: NavigationModel
    @Environment(RosterStore.self) private var roster

    var body: some View {
        ZStack(alignment: .bottom) {
            routeContent
                .ignoresSafeArea(edges: .bottom)
            TabBar(active: Binding(
                get: { nav.tab },
                set: { nav.setTab($0) }
            ))
            .padding(.bottom, R.S.xxl)
            .opacity(nav.top == nil ? 1 : 0)
            .allowsHitTesting(nav.top == nil)
        }
        .task {
            // Prefetch the live roster so the Roster tab feels instant.
            roster.refresh()
        }
    }

    @ViewBuilder
    private var routeContent: some View {
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
                // Route id is a UUID string in the live flow; fallback
                // to a nil-UUID so the view still renders its loading
                // skeleton for deep links with stale identifiers.
                ArtistView(nav: nav, artistID: UUID(uuidString: id) ?? UUID())

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
