// BookingDetailView.swift — Screen 12
//
// Single-booking detail view. Port of `BookingDetailScreen` at ios-app.jsx
// line 1099. Layout:
//
//   NavHeader("Booking")
//   Hero card     — artist name (display), venue · date line, status tag
//   Facts grid    — fee, event time, set duration, rider confirmed
//   Timeline      — booking events (request sent, signed, etc.)
//   Actions       — Message artist (ghost) · View contract (ghost) ·
//                   View invoice (filled, appears only when status
//                   is completed)
//
// Wave 5.3: timeline reads live from public.booking_events via
// TimelineStore. The store subscribes to a realtime channel filtered
// to this booking_id, so contract signatures + payment confirmations
// appear the moment the trigger writes them — no refresh needed.

import SwiftUI
import DesignSystem

public struct BookingDetailView: View {
    @Bindable var nav: NavigationModel
    @Environment(BookingsStore.self) private var bookings
    @Environment(TimelineStore.self) private var timelineStore
    let bookingID: String

    public init(nav: NavigationModel, bookingID: String) {
        self.nav = nav
        self.bookingID = bookingID
    }

    private var resolvedUUID: UUID? { UUID(uuidString: bookingID) }

    private var row: BookingRow? {
        guard let id = resolvedUUID else { return nil }
        return bookings.detailCache[id]
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Booking", onBack: { nav.pop() })
            ScrollView {
                if let row {
                    VStack(alignment: .leading, spacing: R.S.lg) {
                        hero(for: row)
                        factsGrid(for: row)
                        timeline
                        actions(for: row)
                        Color.clear.frame(height: R.S.xxl)
                    }
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.sm)
                } else {
                    loadingPlaceholder
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.lg)
                }
            }
        }
        .background(R.C.bg0)
        .task {
            if let id = resolvedUUID {
                bookings.fetchDetail(id: id)
                timelineStore.fetch(for: id)
            }
        }
        .onDisappear {
            // Release the realtime channel when the user backs out —
            // only one booking timeline is live at a time.
            Task { await timelineStore.unsubscribe() }
        }
    }

    // MARK: — Hero

    private func hero(for row: BookingRow) -> some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Text(Self.heroDateFormatter.string(from: row.eventDate).uppercased())
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                StatusTag(statusTag(for: row.status))
            }
            Text(row.artistName.uppercased())
                .font(R.F.display(30, weight: .bold))
                .tracking(-1.0)
                .foregroundStyle(R.C.fg1)
            Text(venueSubtitle(for: row))
                .font(R.F.body(13, weight: .medium))
                .foregroundStyle(R.C.fg2)
        }
        .padding(R.S.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    private func venueSubtitle(for row: BookingRow) -> String {
        row.eventName.isEmpty || row.eventName == "Event"
            ? row.venueName
            : "\(row.venueName) · \(row.eventName)"
    }

    // MARK: — Facts grid

    private func factsGrid(for row: BookingRow) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: R.S.sm),
            GridItem(.flexible(), spacing: R.S.sm)
        ], spacing: R.S.sm) {
            FactCell(label: "Fee",        value: row.feeFormatted,          isMono: true)
            FactCell(label: "Date",       value: Self.factDateFormatter.string(from: row.eventDate), isMono: true)
            FactCell(label: "Status",     value: row.status.capitalized,    valueColor: statusColor(row.status))
            FactCell(label: "Currency",   value: row.currency,              isMono: true)
        }
    }

    private func statusColor(_ raw: String) -> Color {
        switch raw {
        case "confirmed", "completed": return R.C.green
        case "pending":                return R.C.amber
        case "cancelled":              return R.C.red
        default:                       return R.C.fg1
        }
    }

    // MARK: — Timeline (live via public.booking_events + realtime)

    private var timeline: some View {
        let events = resolvedUUID.map { timelineStore.events(for: $0) } ?? []
        let activeID = resolvedUUID.flatMap { timelineStore.activeEventID(for: $0) }
        return VStack(alignment: .leading, spacing: R.S.md) {
            Text("Timeline")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            VStack(alignment: .leading, spacing: 0) {
                if events.isEmpty {
                    Text("No events yet.")
                        .font(R.F.body(12, weight: .regular))
                        .foregroundStyle(R.C.fg3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, R.S.xs)
                } else {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        TimelineRow(
                            event: event,
                            isActive: event.id == activeID,
                            isFirst: index == 0,
                            isLast: index == events.count - 1
                        )
                    }
                }
            }
            .padding(R.S.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: R.Rad.card)
        }
    }

    // MARK: — Actions

    private func actions(for row: BookingRow) -> some View {
        VStack(spacing: R.S.sm) {
            PrimaryButton("Message artist", variant: .ghost) {
                nav.push(.thread(threadID: bookingID))
            }
            PrimaryButton("View contract", variant: .ghost) {
                nav.push(.contract(contractID: bookingID))
            }
            // Completed + payment exists → invoice CTA is primary.
            if row.status == "completed" {
                PrimaryButton("View invoice", variant: .filled) {
                    nav.push(.invoice(bookingID: bookingID))
                }
            }
        }
    }

    // MARK: — Loading

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: R.S.lg) {
            RoundedRectangle(cornerRadius: R.Rad.card3, style: .continuous)
                .fill(R.C.glassLo)
                .frame(height: 140)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: R.S.sm),
                GridItem(.flexible(), spacing: R.S.sm)
            ], spacing: R.S.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .fill(R.C.glassLo)
                        .frame(height: 64)
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    // MARK: — Status mapping

    private func statusTag(for raw: String) -> StatusTag.Status {
        switch raw {
        case "confirmed":  return .confirmed
        case "pending":    return .pending
        case "contracted": return .contracted
        case "completed":  return .completed
        case "cancelled":  return .pending
        default:           return .pending
        }
    }

    // MARK: — Formatters

    private static let heroDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM · HH:mm"
        return f
    }()

    private static let factDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()
}

// MARK: - Fact cell

private struct FactCell: View {
    let label: String
    let value: String
    var isMono: Bool = false
    var valueColor: Color = R.C.fg1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
            Text(value)
                .font(isMono
                      ? R.F.mono(14, weight: .semibold)
                      : R.F.body(14, weight: .semibold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Timeline row

private struct TimelineRow: View {
    let event: TimelineEvent
    let isActive: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: R.S.md) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : R.C.borderMid)
                    .frame(width: 1, height: 8)
                Circle()
                    .fill(isActive ? R.C.fg1 : R.C.glassMid)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .strokeBorder(isActive ? R.C.fg1 : R.C.borderMid, lineWidth: 1)
                    }
                Rectangle()
                    .fill(isLast ? Color.clear : R.C.borderMid)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.label)
                    .font(R.F.body(13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? R.C.fg1 : R.C.fg2)
                Text(Self.whenFormatter.string(from: event.createdAt))
                    .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
            }
            .padding(.bottom, isLast ? 0 : R.S.md)
        }
    }

    private static let whenFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM · HH:mm"
        return f
    }()
}

#if DEBUG
#Preview("BookingDetailView") {
    let nav = NavigationModel()
    let bookings = BookingsStore()
    let id = UUID()
    bookings._testLoad(
        upcoming: [
            BookingRow(
                id: id,
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
    let timeline = TimelineStore()
    timeline._testLoad([
        TimelineEvent(id: UUID(), kind: .requestSent,
                      label: "Booking request sent",
                      createdAt: Date().addingTimeInterval(-7 * 86_400)),
        TimelineEvent(id: UUID(), kind: .artistAccepted,
                      label: "Artist accepted",
                      createdAt: Date().addingTimeInterval(-6 * 86_400)),
        TimelineEvent(id: UUID(), kind: .contractCountersigned,
                      label: "Contract countersigned",
                      createdAt: Date().addingTimeInterval(-2 * 86_400))
    ], for: id)
    return BookingDetailView(nav: nav, bookingID: id.uuidString)
        .environment(bookings)
        .environment(timeline)
        .preferredColorScheme(.dark)
}
#endif
