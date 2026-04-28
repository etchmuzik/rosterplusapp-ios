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
    /// Deep-link target waiting for sign-in to land. Set by external
    /// triggers (push tap, universal link) while the user is signed-out;
    /// consumed by the .onChange(of: auth.state) handler below as soon
    /// as auth flips to .signedIn.
    @State private var pendingDeepLink: Route?
    @State private var roster = RosterStore()
    @State private var bookings = BookingsStore()
    @State private var inbox = InboxStore()
    @State private var notifications = NotificationsStore()
    @State private var payments = PaymentsStore()
    @State private var artistDetail = ArtistDetailStore()
    @State private var timeline = TimelineStore()
    @State private var profile = ProfileStore()
    @State private var availabilityCheck = AvailabilityCheckStore()
    @State private var push = PushStore()
    @State private var contracts = ContractsStore()
    @State private var invitations = InvitationsStore()
    @State private var network = NetworkMonitor()
    // AnalyticsStore derives from BookingsStore; constructed lazily so
    // it captures the same instance we inject below.
    @State private var analytics: AnalyticsStore? = nil

    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
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
                        profile.refresh(for: userID)
                        // Resolve the artist's own row on sign-in so
                        // availability / profile-edit forms have
                        // something to mutate against.
                        if svcRole == .artist {
                            Task { await artistDetail.resolveMyArtistID(userID: userID) }
                        }
                        if analytics == nil {
                            analytics = AnalyticsStore(bookings: bookings)
                        }
                        // Refresh cached push permission state (the
                        // user may have toggled it in Settings while
                        // the app was backgrounded).
                        Task { await push.refreshAuthorization() }
                    }
                    .task(id: userID) {
                        // Listen for APNs token posts from the app
                        // shell's AppDelegate. The shell forwards
                        // didRegisterForRemoteNotificationsWithDeviceToken
                        // via NotificationCenter; we upsert into
                        // public.device_tokens scoped to this user.
                        let center = NotificationCenter.default
                        for await note in center.notifications(
                            named: PushStore.tokenReceivedNotification
                        ) {
                            guard let data = note.object as? Data else { continue }
                            await push.register(rawTokenData: data, for: userID)
                        }
                    }
                }
            }
            // Offline banner sits above all content. NetworkMonitor
            // hides it the rest of the time so the layer is invisible
            // when there's nothing to say.
            OfflineBanner()
        }
        .environment(nav)
        .environment(auth)
        .environment(roster)
        .environment(bookings)
        .environment(inbox)
        .environment(notifications)
        .environment(payments)
        .environment(artistDetail)
        .environment(timeline)
        .environment(profile)
        .environment(availabilityCheck)
        .environment(push)
        .environment(contracts)
        .environment(invitations)
        .environment(network)
        .environment(analytics ?? AnalyticsStore(bookings: bookings))
        .background(R.C.bg0.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            await auth.loadSession()
            await auth.startObserving()
        }
        .task {
            // Listen for deep-link route requests from external triggers
            // (push-notification taps from AppDelegate). The publisher
            // is process-wide so this stream lives for the whole app
            // lifetime — no .task(id:) reset needed. If the user is
            // signed-out when the tap arrives, stash the route and let
            // the auth.state onChange handler below replay it on sign-in.
            for await note in NotificationCenter.default.notifications(
                named: PushStore.routeRequestedNotification
            ) {
                guard let route = note.object as? Route else { continue }
                if auth.isSignedIn {
                    nav.push(route)
                } else {
                    pendingDeepLink = route
                }
            }
        }
        .onOpenURL { url in
            // Universal link (https://rosterplus.io/...) or custom scheme
            // (rostr://...). Either way, the path component decides the
            // route. Unrecognised paths are dropped silently — the OS
            // still opens the app.
            guard let route = Route.parse(href: url.path.isEmpty ? url.absoluteString : url.path)
            else { return }
            if auth.isSignedIn {
                nav.push(route)
            } else {
                pendingDeepLink = route
            }
        }
        .onChange(of: auth.state) { oldValue, newValue in
            // On sign-out (or session expiry the SDK reports as
            // signedOut), wipe every user-scoped store. Otherwise the
            // next signed-in user briefly sees the previous user's
            // bookings / inbox / notifications / etc. before refresh
            // overwrites them. Realtime channels are torn down inside
            // each store's reset() so we don't leak subscriptions to
            // signed-out users either.
            if case .signedIn = newValue, let route = pendingDeepLink {
                // Auth landed and an external trigger asked for a route
                // earlier. Consume the pending target.
                pendingDeepLink = nil
                nav.push(route)
            }
            if case .signedOut = newValue {
                // Capture the previous user's UUID before any state
                // wipe so we can scope the device_tokens delete.
                let previousUserID: UUID? = {
                    if case .signedIn(let id, _, _) = oldValue { return id }
                    return nil
                }()
                // Synchronous resets first — these clear @Observable
                // state that views are reading right now.
                bookings.reset()
                payments.reset()
                profile.reset()
                artistDetail.reset()
                contracts.reset()
                invitations.reset()
                roster.reset()
                availabilityCheck.reset()
                analytics?.reset()
                push.reset()
                // Routes that referenced the previous user's data are
                // no longer valid; drop them and land on Home.
                nav.clearStack()
                nav.setTab(.home)
                // Async resets — tear down realtime channels. These
                // run on MainActor; the await is just for the
                // unsubscribe network call. Also delete the previous
                // user's device-token row so push fanout doesn't keep
                // delivering to this device for that account.
                Task {
                    await inbox.reset()
                    await notifications.reset()
                    await timeline.reset()
                    if let previousUserID {
                        await push.clearToken(for: previousUserID)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { old, new in
            // Refresh stale data when the app comes back to the
            // foreground. We only kick the user-scoped lists; design
            // system / network mocks / one-shot fetches don't need it.
            // The store-internal `inFlight` guard prevents duplicate
            // fetches if the user opens the app, switches a tab, then
            // backgrounds and re-foregrounds in quick succession.
            guard old != .active, new == .active else { return }
            guard let userID = auth.currentUserID else { return }
            bookings.refresh(for: userID, role: nav.role)
            inbox.refresh(for: userID)
            notifications.refresh(for: userID)
            payments.refresh(for: userID)
            // Resync push permission too — user may have toggled it in
            // Settings while the app was backgrounded.
            Task { await push.refreshAuthorization() }
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
