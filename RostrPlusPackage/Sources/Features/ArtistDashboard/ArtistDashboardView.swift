// ArtistDashboardView.swift — Screen 11
//
// Artist-side home. Port of `ArtistDashboardScreen` at ios-app.jsx
// line 796. Role switch on Home toggles between HomeView (promoter)
// and this view.
//
// Layout top → bottom:
//
//   1. Greeting row    — "Hi, NOVAK" + role switch back to promoter + bell
//   2. Earnings card   — This month total (display font hero)
//                        + last month delta pill
//                        + progress ring showing % of monthly target
//   3. Quick action chips — Availability · EPK · Edit profile
//   4. Incoming requests — vertical list, Accept + Decline inline
//   5. Upcoming         — compact upcoming list (re-uses promoter
//                         mock data, since the artist sees the same
//                         bookings from the other side)

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ArtistDashboardView: View {
    @Bindable var nav: NavigationModel

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                greetingRow
                earningsCard
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.lg)
                quickActions
                    .padding(.top, R.S.lg)
                requestsSection
                    .padding(.top, R.S.xxl)
                upcomingSection
                    .padding(.top, R.S.xxl)
                Color.clear.frame(height: 100) // tab bar clearance
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Greeting

    private var greetingRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hi, Novak")
                    .font(R.F.display(26, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(R.C.fg1)
                Text("3 requests waiting")
                    .monoLabel(size: 10, tracking: 0.6, color: R.C.amber)
            }
            Spacer()
            roleSwitch
            bellButton
                .padding(.leading, R.S.sm)
        }
        .padding(.horizontal, R.S.lg)
        .padding(.top, R.S.sm)
    }

    private var roleSwitch: some View {
        HStack(spacing: 3) {
            ForEach([Role.promoter, .artist], id: \.self) { r in
                Button {
                    nav.setRole(r)
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    Text(r == .promoter ? "Promoter" : "Artist")
                        .font(R.F.mono(9.5, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(nav.role == r ? R.C.bg0 : R.C.fg2)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background {
                            RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                                .fill(nav.role == r ? R.C.fg1 : .clear)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                .fill(R.C.glassLo)
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
        }
    }

    private var bellButton: some View {
        Button {
            nav.push(.notifications)
        } label: {
            ZStack(alignment: .topTrailing) {
                BellIcon(size: 18, color: R.C.fg1)
                    .frame(width: 36, height: 36)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .fill(R.C.glassLo)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                    }
                Circle()
                    .fill(R.C.amber)
                    .frame(width: 7, height: 7)
                    .overlay { Circle().strokeBorder(R.C.bg0, lineWidth: 1.5) }
                    .offset(x: 10, y: -9)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
    }

    // MARK: — Earnings card

    private var earningsCard: some View {
        HStack(alignment: .center, spacing: R.S.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("This month")
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
                Text("AED 92K")
                    .font(R.F.display(36, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(R.C.fg1)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(R.C.green)
                    Text("24% vs last month")
                        .monoLabel(size: 9.5, tracking: 0.5, color: R.C.green)
                }
            }
            Spacer()
            ProgressRing(progress: 0.72, label: "72%", sub: "of target")
                .frame(width: 80, height: 80)
        }
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    // MARK: — Quick actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: R.S.xs) {
                ActionChip(icon: "calendar", label: "Availability") {
                    nav.push(.availability)
                }
                ActionChip(icon: "calendar.badge.clock", label: "Calendar") {
                    nav.push(.calendar)
                }
                ActionChip(icon: "doc.richtext", label: "EPK") {
                    nav.push(.epk(artistID: "me"))
                }
                ActionChip(icon: "pencil", label: "Edit profile") {
                    nav.push(.profileEdit)
                }
                ActionChip(icon: "checkmark.seal", label: "Claim") {
                    nav.push(.claim)
                }
            }
            .padding(.horizontal, R.S.lg)
        }
    }

    // MARK: — Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Text("Booking requests")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("\(MockData.incomingRequests.count) waiting")
                    .monoLabel(size: 9.5, tracking: 0.6, color: R.C.amber)
            }
            .padding(.horizontal, R.S.lg)

            VStack(spacing: R.S.xs) {
                ForEach(MockData.incomingRequests) { request in
                    RequestRow(request: request) {
                        nav.push(.bookingDetail(bookingID: request.id))
                    }
                }
            }
            .padding(.horizontal, R.S.lg)
        }
    }

    // MARK: — Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Text("Upcoming gigs")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Button {
                    nav.setTab(.bookings)
                } label: {
                    HStack(spacing: 4) {
                        Text("All")
                            .monoLabel(size: 9.5, tracking: 0.6, color: R.C.fg2)
                        ChevronRightIcon(size: 10, color: R.C.fg2)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, R.S.lg)

            VStack(spacing: R.S.xs) {
                ForEach(MockData.upcoming) { booking in
                    UpcomingRow(booking: booking) {
                        nav.push(.bookingDetail(bookingID: booking.id))
                    }
                }
            }
            .padding(.horizontal, R.S.lg)
        }
    }
}

// MARK: - Progress ring

private struct ProgressRing: View {
    let progress: Double
    let label: String
    let sub: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(R.C.glassMid, lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(R.C.fg1, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(label)
                    .font(R.F.display(18, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(R.C.fg1)
                Text(sub)
                    .monoLabel(size: 7.5, tracking: 0.5, color: R.C.fg3)
            }
        }
    }
}

// MARK: - Action chip

private struct ActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(label)
                    .font(R.F.mono(10, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(R.C.fg1)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.pill, style: .continuous)
                    .fill(R.C.glassLo)
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.pill, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Request row

private struct RequestRow: View {
    let request: MockIncomingRequest
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.who)
                        .font(R.F.body(14, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text("\(request.date) · \(request.venue)")
                        .font(R.F.body(11.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                }
                Spacer()
                Text(request.time)
                    .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            }

            HStack(alignment: .center, spacing: R.S.sm) {
                Text(request.fee)
                    .font(R.F.mono(13, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(R.C.fg1)
                Spacer()
                Button {
                    // Wave 4: wire decline RPC
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    Text("Decline")
                        .font(R.F.mono(9.5, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(R.C.fg2)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background {
                            RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                                .fill(R.C.glassLo)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    // Wave 4: wire accept RPC + success haptic
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                    onTap()
                } label: {
                    Text("Accept")
                        .font(R.F.mono(9.5, weight: .bold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(R.C.bg0)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background {
                            RoundedRectangle(cornerRadius: R.Rad.sm, style: .continuous)
                                .fill(R.C.fg1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2)
        .contentShape(Rectangle())
    }
}

// MARK: - Upcoming row

private struct UpcomingRow: View {
    let booking: MockBooking
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: R.S.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.day)
                        .font(R.F.mono(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(R.C.fg1)
                    Text(booking.time)
                        .font(R.F.mono(9, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(R.C.fg3)
                }
                .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.venue)
                        .font(R.F.body(14, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text(booking.artist)
                        .font(R.F.body(11.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                }
                Spacer(minLength: R.S.sm)
                Text(booking.fee)
                    .font(R.F.mono(10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(R.C.fg1)
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("ArtistDashboardView") {
    let nav = NavigationModel()
    nav.setRole(.artist)
    return ArtistDashboardView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
