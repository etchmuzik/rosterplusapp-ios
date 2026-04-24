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
// Invoice CTA gated per plan: completed + any payment exists. The mock
// data here hardcodes a "completed" booking so the button shows.

import SwiftUI
import DesignSystem

public struct BookingDetailView: View {
    @Bindable var nav: NavigationModel
    let bookingID: String

    public init(nav: NavigationModel, bookingID: String) {
        self.nav = nav
        self.bookingID = bookingID
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Booking", onBack: { nav.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.lg) {
                    hero
                    factsGrid
                    timeline
                    actions
                    Color.clear.frame(height: R.S.xxl)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.sm)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack {
                Text("TUE 24 APR · 23:00")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                StatusTag(.completed)
            }
            Text("DJ NOVAK")
                .font(R.F.display(30, weight: .bold))
                .tracking(-1.0)
                .foregroundStyle(R.C.fg1)
            Text("WHITE Dubai · Dubai, UAE")
                .font(R.F.body(13, weight: .medium))
                .foregroundStyle(R.C.fg2)
        }
        .padding(R.S.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    // MARK: — Facts grid

    private var factsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: R.S.sm),
            GridItem(.flexible(), spacing: R.S.sm)
        ], spacing: R.S.sm) {
            FactCell(label: "Fee",        value: "AED 28,000", isMono: true)
            FactCell(label: "Set length", value: "4h 00m",      isMono: true)
            FactCell(label: "Rider",      value: "Confirmed",   valueColor: R.C.green)
            FactCell(label: "Contract",   value: "Signed",      valueColor: R.C.fg1)
        }
    }

    // MARK: — Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            Text("Timeline")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(MockData.bookingTimeline.enumerated()), id: \.element.id) { index, event in
                    TimelineRow(
                        event: event,
                        isFirst: index == 0,
                        isLast: index == MockData.bookingTimeline.count - 1
                    )
                }
            }
            .padding(R.S.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: R.Rad.card)
        }
    }

    // MARK: — Actions

    private var actions: some View {
        VStack(spacing: R.S.sm) {
            PrimaryButton("Message artist", variant: .ghost) {
                nav.push(.thread(threadID: bookingID))
            }
            PrimaryButton("View contract", variant: .ghost) {
                nav.push(.contract(contractID: bookingID))
            }
            // Completed + payment exists → invoice CTA is primary.
            PrimaryButton("View invoice", variant: .filled) {
                nav.push(.invoice(bookingID: bookingID))
            }
        }
    }
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
    let event: MockTimelineEvent
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: R.S.md) {
            VStack(spacing: 0) {
                // Top connector
                Rectangle()
                    .fill(isFirst ? Color.clear : R.C.borderMid)
                    .frame(width: 1, height: 8)
                Circle()
                    .fill(event.isActive ? R.C.fg1 : R.C.glassMid)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .strokeBorder(event.isActive ? R.C.fg1 : R.C.borderMid, lineWidth: 1)
                    }
                // Bottom connector
                Rectangle()
                    .fill(isLast ? Color.clear : R.C.borderMid)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.label)
                    .font(R.F.body(13, weight: event.isActive ? .semibold : .regular))
                    .foregroundStyle(event.isActive ? R.C.fg1 : R.C.fg2)
                Text(event.when)
                    .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
            }
            .padding(.bottom, isLast ? 0 : R.S.md)
        }
    }
}

#if DEBUG
#Preview("BookingDetailView") {
    let nav = NavigationModel()
    return BookingDetailView(nav: nav, bookingID: "demo")
        .preferredColorScheme(.dark)
}
#endif
