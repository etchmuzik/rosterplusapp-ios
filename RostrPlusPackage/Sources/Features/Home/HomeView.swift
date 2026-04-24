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
    @Environment(BookingsStore.self) private var bookings
    @Environment(AuthStore.self) private var auth

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    /// Derived first-name for the greeting. Falls back to "there"
    /// until the auth session is loaded.
    private var firstName: String {
        guard case .signedIn(_, let email, _) = auth.state else { return "there" }
        // Very small heuristic — pick the email local-part's first token.
        // Real display name lands once we thread through the profile row.
        let local = email.split(separator: "@").first.map(String.init) ?? ""
        if local.isEmpty { return "there" }
        return local.split(separator: ".").first.map { $0.capitalized } ?? "there"
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
                Text(firstName)
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
    //
    // "Tonight" = the next upcoming booking. If none, falls back to a
    // friendlier empty card that nudges promoters to book an artist.

    @ViewBuilder
    private var tonightCard: some View {
        if let next = bookings.upcoming.first {
            tonightCardContent(for: next)
        } else {
            emptyTonightCard
        }
    }

    private func tonightCardContent(for booking: BookingRow) -> some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Text(nextEventLine(booking))
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
                Spacer()
                StatusTag(statusTag(for: booking.status))
            }

            Text(booking.artistName.uppercased())
                .font(R.F.display(36, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(R.C.fg1)
                .padding(.top, 2)

            Text("\(booking.venueName) · \(booking.eventName)")
                .font(R.F.body(13, weight: .medium))
                .foregroundStyle(R.C.fg2)
                .lineLimit(2)

            HStack(spacing: R.S.sm) {
                Button {
                    nav.push(.bookingDetail(bookingID: booking.id.uuidString))
                } label: {
                    Text("Open booking")
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
                    nav.push(.thread(threadID: booking.id.uuidString))
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

    private var emptyTonightCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("No upcoming bookings")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text("Book an artist")
                .font(R.F.display(28, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(R.C.fg1)
            Text("Your next gig will land here the moment you send a request.")
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)

            Button {
                nav.setTab(.roster)
            } label: {
                Text("Browse roster")
                    .font(R.F.mono(10.5, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(R.C.bg0)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .fill(R.C.fg1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, R.S.xs)
        }
        .padding(R.S.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    /// "Tonight · Dubai" when the event is today, otherwise "TUE 24 · venue".
    private func nextEventLine(_ b: BookingRow) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(b.eventDate) { return "Tonight" }
        if cal.isDateInTomorrow(b.eventDate) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: b.eventDate).uppercased()
    }

    private func statusTag(for raw: String) -> StatusTag.Status {
        switch raw {
        case "confirmed":  return .confirmed
        case "contracted": return .contracted
        case "completed":  return .completed
        case "cancelled":  return .cancelled
        default:           return .pending
        }
    }

    // MARK: — Quick stats

    private var quickStatsRow: some View {
        let s = bookings.stats
        return HStack(spacing: R.S.sm) {
            StatTile(label: "Upcoming",   value: formatTwoDigit(s.upcomingCount))
            StatTile(label: "Pending",    value: formatTwoDigit(s.pendingCount), accent: R.C.amber)
            StatTile(label: "This month", value: s.monthTotal, isMonoValue: true)
        }
    }

    /// 01 / 02 / 12 — matches the mono zero-padding in the JSX.
    private func formatTwoDigit(_ n: Int) -> String {
        String(format: "%02d", n)
    }

    // MARK: — Up next

    @ViewBuilder
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

            if bookings.upNext.isEmpty {
                Text("Nothing scheduled yet.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .padding(.horizontal, R.S.lg)
                    .padding(.vertical, R.S.md)
            } else {
                VStack(spacing: R.S.xs) {
                    ForEach(bookings.upNext) { row in
                        UpNextRow(row: row) {
                            nav.push(.bookingDetail(bookingID: row.id.uuidString))
                        }
                    }
                }
                .padding(.horizontal, R.S.lg)
            }
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
    let row: BookingRow
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: R.S.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayLabel)
                        .font(R.F.mono(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(R.C.fg1)
                    Text(timeLabel)
                        .font(R.F.mono(9, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(R.C.fg3)
                }
                .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.artistName)
                        .font(R.F.body(14, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text(row.venueName)
                        .font(R.F.body(11.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                }
                Spacer(minLength: R.S.sm)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(row.feeFormatted)
                        .font(R.F.mono(10.5, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(R.C.fg1)
                    StatusTag(statusTag(for: row.status))
                }
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
        }
        .buttonStyle(.plain)
    }

    /// "TUE 24" — day-of-week + day-of-month in mono caps.
    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f.string(from: row.eventDate).uppercased()
    }

    /// "23:00" when we have an event_time, otherwise the calendar time.
    private var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: row.eventDate)
    }

    private func statusTag(for raw: String) -> StatusTag.Status {
        switch raw {
        case "confirmed":  return .confirmed
        case "contracted": return .contracted
        case "completed":  return .completed
        case "cancelled":  return .cancelled
        default:           return .pending
        }
    }
}

#if DEBUG
#Preview("HomeView — promoter") {
    let nav = NavigationModel()
    let auth = AuthStore()
    let bookings = BookingsStore()
    bookings._testLoad(
        upcoming: [
            BookingRow(
                id: UUID(),
                eventName: "Rooftop Set",
                artistName: "DJ Novak",
                venueName: "Sky Lounge Dubai",
                eventDate: Date().addingTimeInterval(3 * 86_400),
                status: "confirmed",
                feeFormatted: "AED 28K",
                currency: "AED",
                fee: 28_000
            ),
            BookingRow(
                id: UUID(),
                eventName: "Beach Festival",
                artistName: "Orion Kai",
                venueName: "Atlantis Beach",
                eventDate: Date().addingTimeInterval(7 * 86_400),
                status: "pending",
                feeFormatted: "AED 22K",
                currency: "AED",
                fee: 22_000
            )
        ],
        past: []
    )
    return HomeView(nav: nav)
        .environment(nav)
        .environment(auth)
        .environment(bookings)
        .preferredColorScheme(.dark)
}
#endif
