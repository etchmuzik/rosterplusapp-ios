// HomeView.swift
//
// Screen 02 of the 23 — the promoter-side home. Port of `HomeScreen` at
// ios-app.jsx line 165. Structure top to bottom:
//
//   1. Greeting row     — "Good evening," + promoter/artist role switch + bell
//   2. Tonight card     — tonight's gig (large glass card with hero data)
//   3. Quick stats      — 3-column grid (upcoming · pending · this month)
//   4. Up next          — compact list of the next 3 upcoming bookings
//
// Artist role lands on ArtistDashboardView; this file only renders the
// promoter variant.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct HomeView: View {
    @Bindable var nav: NavigationModel

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                greetingRow
                tonightCard
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.lg)
                quickStatsRow
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.lg)
                upNextSection
                    .padding(.top, R.S.xxl)
                // Spacer so the floating tab bar doesn't cover the last row.
                Color.clear.frame(height: 100)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Greeting row

    private var greetingRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good evening,")
                    .font(R.F.body(13, weight: .regular))
                    .foregroundStyle(R.C.fg2)
                Text("Hesham")
                    .font(R.F.display(26, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(R.C.fg1)
            }
            Spacer()
            roleSwitch
            bellButton
                .padding(.leading, R.S.sm)
        }
        .padding(.horizontal, R.S.lg)
        .padding(.top, R.S.sm)
    }

    @ViewBuilder
    private var roleSwitch: some View {
        HStack(spacing: 3) {
            ForEach([Role.promoter, .artist], id: \.self) { r in
                Button {
                    nav.setRole(r)
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
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
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
                // Unread dot — gold accent, ringed against the dark bg
                // so it reads as a notification badge, not an error state.
                Circle()
                    .fill(R.C.amber)
                    .frame(width: 7, height: 7)
                    .overlay {
                        Circle().strokeBorder(R.C.bg0, lineWidth: 1.5)
                    }
                    .offset(x: 10, y: -9)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
    }

    // MARK: — Tonight card

    private var tonightCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Text("Tonight · Dubai")
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
                Spacer()
                StatusTag(.confirmed)
            }

            Text("DJ NOVAK")
                .font(R.F.display(36, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(R.C.fg1)
                .padding(.top, 2)

            Text("WHITE Dubai · 23:00–03:00")
                .font(R.F.body(13, weight: .medium))
                .foregroundStyle(R.C.fg2)

            HStack(spacing: R.S.sm) {
                Button {
                    // Placeholder: open runsheet
                } label: {
                    Text("Open runsheet")
                        .font(R.F.mono(10.5, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(R.C.bg0)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                                .fill(R.C.fg1)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    nav.push(.thread(threadID: "dj-novak"))
                } label: {
                    Text("Message")
                        .font(R.F.mono(10.5, weight: .semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(R.C.fg1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                                .fill(R.C.glassLo)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                                .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, R.S.xs)
        }
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    // MARK: — Quick stats

    private var quickStatsRow: some View {
        HStack(spacing: R.S.sm) {
            StatTile(label: "Upcoming", value: "12")
            StatTile(label: "Pending",  value: "03", accent: R.C.amber)
            StatTile(label: "This month", value: "AED 186K", isMonoValue: true)
        }
    }

    // MARK: — Up next

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Text("Up next")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Button {
                    nav.setTab(.bookings)
                } label: {
                    HStack(spacing: 4) {
                        Text("All bookings")
                            .monoLabel(size: 9.5, tracking: 0.6, color: R.C.fg2)
                        ChevronRightIcon(size: 10, color: R.C.fg2)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, R.S.lg)

            VStack(spacing: R.S.xs) {
                ForEach(MockData.upcoming) { booking in
                    UpNextRow(booking: booking) {
                        nav.push(.bookingDetail(bookingID: booking.id))
                    }
                }
            }
            .padding(.horizontal, R.S.lg)
        }
    }
}

// MARK: - Stat tile

private struct StatTile: View {
    let label: String
    let value: String
    var accent: Color = R.C.fg1
    var isMonoValue: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Text(label)
                .monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
            Text(value)
                .font(isMonoValue
                      ? R.F.mono(15, weight: .semibold)
                      : R.F.display(22, weight: .bold))
                .tracking(isMonoValue ? 0.2 : -0.4)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Up-next row

private struct UpNextRow: View {
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
                    Text(booking.artist)
                        .font(R.F.body(14, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text(booking.venue)
                        .font(R.F.body(11.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                }
                Spacer(minLength: R.S.sm)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(booking.fee)
                        .font(R.F.mono(10.5, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(R.C.fg1)
                    StatusTag(statusTag(for: booking.status))
                }
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
        }
        .buttonStyle(.plain)
    }

    private func statusTag(for s: MockBooking.Status) -> StatusTag.Status {
        switch s {
        case .confirmed:  return .confirmed
        case .pending:    return .pending
        case .contracted: return .contracted
        }
    }
}

#if DEBUG
#Preview("HomeView — promoter") {
    let nav = NavigationModel()
    return HomeView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
