// PaymentsView.swift — Screen 10
//
// Payment list with stats. Port of `PaymentsScreen` at ios-app.jsx
// line 884. Layout:
//
//   Greeting     — "Payments"
//   KPI cards    — This month · Paid · Outstanding · Scheduled
//   Filter chips — All · Paid · Pending · Scheduled
//   Payment list — per-row: artist, event, date, amount (mono), status
//
// Tapping a row opens the matching booking's invoice (completed
// bookings) or booking detail (pending/scheduled).

import SwiftUI
import DesignSystem

public struct PaymentsView: View {
    @Bindable var nav: NavigationModel
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable {
        case all, paid, pending, scheduled
    }

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: R.S.lg) {
                header
                kpiGrid
                filterRow
                list
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, R.S.lg)
            .padding(.top, R.S.sm)
        }
        .background(R.C.bg0)
    }

    // MARK: — Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Payments")
                .font(R.F.display(30, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(R.C.fg1)
            Text("\(MockData.payments.count) payments this month")
                .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
        }
    }

    // MARK: — KPIs

    private var kpiGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: R.S.sm),
            GridItem(.flexible(), spacing: R.S.sm)
        ], spacing: R.S.sm) {
            KPITile(label: "This month", value: "AED 186K", accent: R.C.fg1)
            KPITile(label: "Paid",        value: "AED 132K", accent: R.C.green)
            KPITile(label: "Outstanding", value: "AED 42K",  accent: R.C.amber)
            KPITile(label: "Scheduled",   value: "AED 12K",  accent: R.C.blue)
        }
    }

    // MARK: — Filter row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: R.S.xs) {
                ForEach(Filter.allCases, id: \.self) { f in
                    FilterChip(label: f.rawValue.capitalized, isActive: filter == f) {
                        filter = f
                    }
                }
            }
        }
    }

    // MARK: — List

    private var list: some View {
        VStack(spacing: R.S.xs) {
            ForEach(filtered) { p in
                Button {
                    if p.status == .paid {
                        nav.push(.invoice(bookingID: p.id))
                    } else {
                        nav.push(.bookingDetail(bookingID: p.id))
                    }
                } label: {
                    PaymentRow(payment: p)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filtered: [MockPayment] {
        switch filter {
        case .all:       return MockData.payments
        case .paid:      return MockData.payments.filter { $0.status == .paid }
        case .pending:   return MockData.payments.filter { $0.status == .pending }
        case .scheduled: return MockData.payments.filter { $0.status == .scheduled }
        }
    }
}

// MARK: - KPI tile

private struct KPITile: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
            Text(value)
                .font(R.F.display(20, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(R.F.mono(10, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(isActive ? R.C.bg0 : R.C.fg2)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: R.Rad.pill, style: .continuous)
                        .fill(isActive ? R.C.fg1 : R.C.glassLo)
                }
                .overlay {
                    if !isActive {
                        RoundedRectangle(cornerRadius: R.Rad.pill, style: .continuous)
                            .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Payment row

private struct PaymentRow: View {
    let payment: MockPayment

    var body: some View {
        HStack(spacing: R.S.md) {
            Cover(seed: payment.artist, size: 40, cornerRadius: R.Rad.md)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.artist)
                    .font(R.F.body(13.5, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(payment.event)
                    .font(R.F.body(11.5, weight: .regular))
                    .foregroundStyle(R.C.fg2)
                    .lineLimit(1)
            }
            Spacer(minLength: R.S.sm)
            VStack(alignment: .trailing, spacing: 4) {
                Text(payment.amount)
                    .font(R.F.mono(11, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(R.C.fg1)
                pill
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }

    private var pill: some View {
        let (label, color): (String, Color) = {
            switch payment.status {
            case .paid:      return ("Paid", R.C.green)
            case .pending:   return ("Pending", R.C.amber)
            case .scheduled: return ("Scheduled", R.C.blue)
            }
        }()
        return Text(label)
            .monoLabel(size: 8.5, tracking: 0.5, color: color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.xs, style: .continuous)
                    .fill(R.C.glassLo)
            }
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.xs, style: .continuous)
                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
    }
}

#if DEBUG
#Preview("PaymentsView") {
    let nav = NavigationModel()
    return PaymentsView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
