// BookingsView.swift — Screen 08
//
// Bookings list with upcoming + past groups, plus an inline review-
// prompt banner that appears on recent completed bookings where the
// promoter hasn't rated the artist yet. Port of `BookingsScreen` at
// ios-app.jsx line 642.
//
// Chart icon in the header pushes to analytics (Wave 4 — stubbed for
// now but the nav call is wired).

import SwiftUI
import DesignSystem

public struct BookingsView: View {
    @Bindable var nav: NavigationModel

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.sm)
                reviewPromptBanner
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.md)
                section(title: "Upcoming", bookings: MockData.upcoming)
                    .padding(.top, R.S.lg)
                section(title: "Past", bookings: MockData.past, isPast: true)
                    .padding(.top, R.S.xl)
                Color.clear.frame(height: 100)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bookings")
                    .font(R.F.display(30, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(R.C.fg1)
                Text("\(MockData.upcoming.count) upcoming · \(MockData.past.count) past")
                    .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
            }
            Spacer()
            Button {
                nav.push(.analytics)
            } label: {
                ChartIcon(size: 18, color: R.C.fg1)
                    .frame(width: 36, height: 36)
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
            .accessibilityLabel("View analytics")
        }
    }

    // MARK: — Review prompt banner

    private var reviewPromptBanner: some View {
        Button {
            nav.push(.review(bookingID: "karima-n"))
        } label: {
            HStack(spacing: R.S.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                        .fill(R.C.amber.opacity(0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(R.C.amber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rate KARIMA-N")
                        .font(R.F.body(13, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text("Event wrapped SAT 20 · Leave a rating")
                        .font(R.F.mono(9.5, weight: .medium))
                        .tracking(0.4)
                        .foregroundStyle(R.C.fg3)
                }
                Spacer()
                ChevronRightIcon(size: 12, color: R.C.amber)
            }
            .padding(R.S.md)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(LinearGradient(
                        colors: [R.C.amber.opacity(0.10), R.C.amber.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .strokeBorder(R.C.amber.opacity(0.24), lineWidth: R.S.hairline)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: — Section

    private func section(title: String, bookings: [MockBooking], isPast: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text(title)
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                .padding(.horizontal, R.S.lg)
            VStack(spacing: R.S.xs) {
                ForEach(bookings) { b in
                    BookingRow(booking: b, isPast: isPast) {
                        nav.push(.bookingDetail(bookingID: b.id))
                    }
                }
            }
            .padding(.horizontal, R.S.lg)
        }
    }
}

// MARK: - Row

private struct BookingRow: View {
    let booking: MockBooking
    let isPast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: R.S.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.day)
                        .font(R.F.mono(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(isPast ? R.C.fg2 : R.C.fg1)
                    Text(booking.time)
                        .font(R.F.mono(9, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(R.C.fg3)
                }
                .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.artist)
                        .font(R.F.body(14, weight: .semibold))
                        .foregroundStyle(isPast ? R.C.fg2 : R.C.fg1)
                    Text(booking.venue)
                        .font(R.F.body(11.5, weight: .regular))
                        .foregroundStyle(R.C.fg3)
                }
                Spacer(minLength: R.S.sm)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(booking.fee)
                        .font(R.F.mono(10.5, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(isPast ? R.C.fg2 : R.C.fg1)
                    if !isPast {
                        StatusTag(statusTag(for: booking.status))
                    } else {
                        StatusTag(.completed)
                    }
                }
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
            .opacity(isPast ? 0.85 : 1.0)
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
#Preview("BookingsView") {
    let nav = NavigationModel()
    return BookingsView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
