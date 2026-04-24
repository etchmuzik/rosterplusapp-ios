// ArtistDashboardView.swift — Screen 11
//
// Artist-side home. Port of `ArtistDashboardScreen` at ios-app.jsx
// line 796. Role switch on Home toggles between HomeView (promoter)
// and this view.
//
// Wave 5.2: incoming booking requests + upcoming gigs are fully live.
// BookingsStore.pendingRequests filters for status == inquiry|pending;
// Accept/Decline buttons call BookingsStore.respond(to:with:) which
// optimistically moves the row out of the list and mirrors a PATCH to
// public.bookings (RLS gates the write to the booking's artist).
//
// Earnings hero is derived from the artist's confirmed + completed
// bookings. No new store — we reuse BookingsStore + BookingsStore.stats
// for the monthly total.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ArtistDashboardView: View {
    @Bindable var nav: NavigationModel
    @Environment(AuthStore.self) private var auth
    @Environment(BookingsStore.self) private var bookings

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

    private var firstName: String {
        guard case .signedIn(_, let email, _) = auth.state else { return "artist" }
        let local = email.split(separator: "@").first.map(String.init) ?? "artist"
        let token = local.split(separator: ".").first.map(String.init) ?? local
        return token.prefix(1).uppercased() + token.dropFirst()
    }

    private var greetingRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hi, \(firstName)")
                    .font(R.F.display(26, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(R.C.fg1)
                Text(requestsSubtitle)
                    .monoLabel(size: 10, tracking: 0.6, color: bookings.pendingRequests.isEmpty ? R.C.fg3 : R.C.amber)
            }
            Spacer()
            roleSwitch
            bellButton
                .padding(.leading, R.S.sm)
        }
        .padding(.horizontal, R.S.lg)
        .padding(.top, R.S.sm)
    }

    private var requestsSubtitle: String {
        let count = bookings.pendingRequests.count
        switch count {
        case 0: return "All caught up"
        case 1: return "1 request waiting"
        default: return "\(count) requests waiting"
        }
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
                if !bookings.pendingRequests.isEmpty {
                    Circle()
                        .fill(R.C.amber)
                        .frame(width: 7, height: 7)
                        .overlay { Circle().strokeBorder(R.C.bg0, lineWidth: 1.5) }
                        .offset(x: 10, y: -9)
                }
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
                Text(bookings.stats.monthTotal)
                    .font(R.F.display(36, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(R.C.fg1)
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(R.C.fg3)
                    Text("\(bookings.stats.upcomingCount) upcoming")
                        .monoLabel(size: 9.5, tracking: 0.5, color: R.C.fg3)
                }
            }
            Spacer()
            ProgressRing(
                progress: targetProgress,
                label: "\(Int(targetProgress * 100))%",
                sub: "of target"
            )
            .frame(width: 80, height: 80)
        }
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    /// Fraction of the default monthly target reached. Target defaults
    /// to 100K of whatever currency the bookings are in — a minimal
    /// heuristic until profiles carries a user-set goal.
    private var targetProgress: Double {
        let total = bookings.upcoming.reduce(0.0) { $0 + ($1.fee ?? 0) }
        let target = 100_000.0
        return min(max(total / target, 0), 1)
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
                    if case .signedIn(let userID, _, _) = auth.state {
                        nav.push(.epk(artistID: userID.uuidString))
                    }
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
                Text("\(bookings.pendingRequests.count) waiting")
                    .monoLabel(size: 9.5, tracking: 0.6, color: bookings.pendingRequests.isEmpty ? R.C.fg3 : R.C.amber)
            }
            .padding(.horizontal, R.S.lg)

            if bookings.pendingRequests.isEmpty {
                emptyRequestsRow
                    .padding(.horizontal, R.S.lg)
            } else {
                VStack(spacing: R.S.xs) {
                    ForEach(bookings.pendingRequests) { row in
                        RequestRow(
                            row: row,
                            onTap: { nav.push(.bookingDetail(bookingID: row.id.uuidString)) },
                            onAccept: {
                                #if canImport(UIKit)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                #endif
                                bookings.respond(to: row.id, with: .accept)
                            },
                            onDecline: {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                bookings.respond(to: row.id, with: .decline)
                            }
                        )
                    }
                }
                .padding(.horizontal, R.S.lg)
            }
        }
    }

    private var emptyRequestsRow: some View {
        HStack(spacing: R.S.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(R.C.green)
            Text("No requests pending. Browse opportunities from the roster side.")
                .font(R.F.body(12.5, weight: .regular))
                .foregroundStyle(R.C.fg2)
            Spacer()
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
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

            if confirmedUpcoming.isEmpty {
                Text("No upcoming gigs booked yet.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .padding(.horizontal, R.S.lg)
                    .padding(.vertical, R.S.sm)
            } else {
                VStack(spacing: R.S.xs) {
                    ForEach(confirmedUpcoming) { row in
                        UpcomingRow(row: row) {
                            nav.push(.bookingDetail(bookingID: row.id.uuidString))
                        }
                    }
                }
                .padding(.horizontal, R.S.lg)
            }
        }
    }

    /// Upcoming filtered to the already-confirmed/contracted/completed
    /// statuses — anything still in inquiry/pending appears in the
    /// requests section above, so avoid surfacing it twice.
    private var confirmedUpcoming: [BookingRow] {
        bookings.upcoming.filter { row in
            row.status == "confirmed" || row.status == "contracted" || row.status == "completed"
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
    let row: BookingRow
    let onTap: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Button(action: onTap) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.venueName)
                            .font(R.F.body(14, weight: .semibold))
                            .foregroundStyle(R.C.fg1)
                        Text("\(Self.dateFormatter.string(from: row.eventDate)) · \(row.eventName)")
                            .font(R.F.body(11.5, weight: .regular))
                            .foregroundStyle(R.C.fg2)
                    }
                    Spacer()
                    Text(row.status.uppercased())
                        .monoLabel(size: 8.5, tracking: 0.5, color: row.status == "pending" ? R.C.amber : R.C.fg3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(alignment: .center, spacing: R.S.sm) {
                Text(row.feeFormatted)
                    .font(R.F.mono(13, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(R.C.fg1)
                Spacer()
                Button(action: onDecline) {
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
                .accessibilityLabel("Decline booking request")

                Button(action: onAccept) {
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
                .accessibilityLabel("Accept booking request")
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()
}

// MARK: - Upcoming row

private struct UpcomingRow: View {
    let row: BookingRow
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: R.S.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dayFormatter.string(from: row.eventDate).uppercased())
                        .font(R.F.mono(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(R.C.fg1)
                    Text(Self.timeFormatter.string(from: row.eventDate))
                        .font(R.F.mono(9, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(R.C.fg3)
                }
                .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.venueName)
                        .font(R.F.body(14, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text(row.artistName)
                        .font(R.F.body(11.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                }
                Spacer(minLength: R.S.sm)
                Text(row.feeFormatted)
                    .font(R.F.mono(10.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(R.C.fg1)
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
        }
        .buttonStyle(.plain)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

#if DEBUG
#Preview("ArtistDashboardView") {
    let nav = NavigationModel()
    nav.setRole(.artist)
    let auth = AuthStore()
    let bookings = BookingsStore()
    bookings._testLoad(
        upcoming: [
            BookingRow(id: UUID(), eventName: "Summer Set", artistName: "DJ Novak",
                       venueName: "Soho Garden",
                       eventDate: Date().addingTimeInterval(86_400 * 6),
                       status: "pending",
                       feeFormatted: "AED 28K", currency: "AED", fee: 28_000),
            BookingRow(id: UUID(), eventName: "Rooftop", artistName: "DJ Novak",
                       venueName: "WHITE Dubai",
                       eventDate: Date().addingTimeInterval(86_400 * 12),
                       status: "confirmed",
                       feeFormatted: "AED 32K", currency: "AED", fee: 32_000)
        ],
        past: []
    )
    return ArtistDashboardView(nav: nav)
        .environment(nav)
        .environment(auth)
        .environment(bookings)
        .preferredColorScheme(.dark)
}
#endif
