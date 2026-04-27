// BookingsView.swift — Screen 08
//
// Bookings list with upcoming + past groups, plus an inline review-
// prompt banner that appears on recent completed bookings where the
// promoter hasn't rated the artist yet. Port of `BookingsScreen` at
// ios-app.jsx line 642.
//
// Track 2 pass 2: reads live data from BookingsStore. AppRoot is
// responsible for the refresh call on sign-in; this view just watches
// the store's derived `upcoming` + `past` arrays.
//
// Chart icon in the header pushes to analytics.

import SwiftUI
import DesignSystem

public struct BookingsView: View {
    @Bindable var nav: NavigationModel
    @Environment(BookingsStore.self) private var bookings
    @Environment(AuthStore.self) private var auth

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.sm)

                // Review-prompt banner only appears when we have a
                // recently-completed booking that still needs a rating.
                if let recent = reviewCandidate {
                    reviewPromptBanner(for: recent)
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.md)
                }

                switch bookings.state {
                case .idle, .loading:
                    loadingSkeleton
                        .padding(.top, R.S.lg)

                case .failed(let message):
                    failureCard(message)
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.lg)

                case .loaded:
                    section(title: "Upcoming", rows: bookings.upcoming)
                        .padding(.top, R.S.lg)
                    section(title: "Past", rows: bookings.past, isPast: true)
                        .padding(.top, R.S.xl)
                }

                Color.clear.frame(height: 100)
            }
        }
        .background(R.C.bg0)
        .refreshable {
            guard let userID = auth.currentUserID else { return }
            bookings.refresh(for: userID, role: nav.role)
        }
    }

    // MARK: — Derived

    /// A completed booking from the last 14 days, for the review prompt.
    private var reviewCandidate: BookingRow? {
        let cutoff = Date().addingTimeInterval(-14 * 86_400)
        return bookings.past.first { $0.eventDate >= cutoff && $0.status == "completed" }
    }

    // MARK: — Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bookings")
                    .font(R.F.display(30, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(R.C.fg1)
                Text("\(bookings.upcoming.count) upcoming · \(bookings.past.count) past")
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

    private func reviewPromptBanner(for row: BookingRow) -> some View {
        Button {
            nav.push(.review(bookingID: row.id.uuidString))
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
                    Text("Rate \(row.artistName.uppercased())")
                        .font(R.F.body(13, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text("Event wrapped \(Self.bannerDateFormatter.string(from: row.eventDate)) · Leave a rating")
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

    private func section(title: String, rows: [BookingRow], isPast: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text(title)
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                .padding(.horizontal, R.S.lg)
            if rows.isEmpty {
                Text(isPast ? "No past bookings yet." : "No upcoming bookings.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .padding(.horizontal, R.S.lg)
                    .padding(.vertical, R.S.md)
            } else {
                VStack(spacing: R.S.xs) {
                    ForEach(rows) { row in
                        BookingListRow(row: row, isPast: isPast) {
                            nav.push(.bookingDetail(bookingID: row.id.uuidString))
                        }
                    }
                }
                .padding(.horizontal, R.S.lg)
            }
        }
    }

    // MARK: — Loading / failure

    private var loadingSkeleton: some View {
        VStack(spacing: R.S.xs) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(R.C.glassLo)
                    .frame(height: 68)
                    .overlay {
                        RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                            .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                    }
            }
        }
        .padding(.horizontal, R.S.lg)
        .redacted(reason: .placeholder)
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack(spacing: R.S.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(R.C.red)
                Text("Couldn't load bookings")
                    .font(R.F.body(13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
            }
            Text(message)
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg2)
        }
        .padding(R.S.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .fill(R.C.red.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                .strokeBorder(R.C.red.opacity(0.25), lineWidth: R.S.hairline)
        }
    }

    // MARK: — Formatters

    private static let bannerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f
    }()
}

// MARK: - Row

private struct BookingListRow: View {
    let row: BookingRow
    let isPast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: R.S.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dayFormatter.string(from: row.eventDate).uppercased())
                        .font(R.F.mono(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(isPast ? R.C.fg2 : R.C.fg1)
                    Text(Self.timeFormatter.string(from: row.eventDate))
                        .font(R.F.mono(9, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(R.C.fg3)
                }
                .frame(width: 54, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.artistName)
                        .font(R.F.body(14, weight: .semibold))
                        .foregroundStyle(isPast ? R.C.fg2 : R.C.fg1)
                    Text(row.venueName)
                        .font(R.F.body(11.5, weight: .regular))
                        .foregroundStyle(R.C.fg3)
                }
                Spacer(minLength: R.S.sm)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(row.feeFormatted)
                        .font(R.F.mono(10.5, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(isPast ? R.C.fg2 : R.C.fg1)
                    StatusTag(statusTag(for: row.status, isPast: isPast))
                }
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
            .opacity(isPast ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func statusTag(for raw: String, isPast: Bool) -> StatusTag.Status {
        if isPast { return .completed }
        switch raw {
        case "confirmed":  return .confirmed
        case "pending":    return .pending
        case "contracted": return .contracted
        case "completed":  return .completed
        case "cancelled":  return .pending // closest neutral-warning mapping
        default:           return .pending
        }
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
#Preview("BookingsView") {
    let nav = NavigationModel()
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
            )
        ],
        past: []
    )
    return BookingsView(nav: nav)
        .environment(bookings)
        .preferredColorScheme(.dark)
}
#endif
