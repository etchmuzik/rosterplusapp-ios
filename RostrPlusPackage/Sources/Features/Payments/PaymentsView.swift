// PaymentsView.swift — Screen 10
//
// Payment list with stats. Port of `PaymentsScreen` at ios-app.jsx
// line 884. Wave 5.1: backed by PaymentsStore (public.payments via
// bookings relation — RLS scopes to the signed-in user).

import SwiftUI
import DesignSystem

public struct PaymentsView: View {
    @Bindable var nav: NavigationModel
    @Environment(PaymentsStore.self) private var store
    @Environment(AuthStore.self) private var auth
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
                content
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, R.S.lg)
            .padding(.top, R.S.sm)
        }
        .background(R.C.bg0)
        .refreshable {
            guard let userID = auth.currentUserID else { return }
            store.refresh(for: userID)
        }
    }

    // MARK: — Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Payments")
                .font(R.F.display(30, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(R.C.fg1)
            Text("\(store.items.count) payments")
                .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
        }
    }

    // MARK: — KPIs

    private var kpiGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: R.S.sm),
            GridItem(.flexible(), spacing: R.S.sm)
        ], spacing: R.S.sm) {
            KPITile(label: "This month", value: formatMoney(store.monthTotal, ccy: monthCurrency), accent: R.C.fg1)
            KPITile(label: "Paid",        value: formatMoney(sumAmount(store.paid), ccy: firstCcy(store.paid)), accent: R.C.green)
            KPITile(label: "Outstanding", value: formatMoney(sumAmount(store.pending), ccy: firstCcy(store.pending)), accent: R.C.amber)
            KPITile(label: "Scheduled",   value: formatMoney(sumAmount(store.scheduled), ccy: firstCcy(store.scheduled)), accent: R.C.blue)
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

    // MARK: — Content

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            loadingSkeleton
        case .failed(let message):
            failureCard(message)
        case .loaded:
            if filtered.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var list: some View {
        VStack(spacing: R.S.xs) {
            ForEach(filtered) { p in
                Button {
                    if p.status == .paid {
                        nav.push(.invoice(bookingID: p.id.uuidString))
                    } else {
                        nav.push(.bookingDetail(bookingID: p.id.uuidString))
                    }
                } label: {
                    PaymentCell(payment: p)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filtered: [PaymentRow] {
        switch filter {
        case .all:       return store.items
        case .paid:      return store.paid
        case .pending:   return store.pending
        case .scheduled: return store.scheduled
        }
    }

    // MARK: — States

    private var loadingSkeleton: some View {
        VStack(spacing: R.S.xs) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(R.C.glassLo)
                    .frame(height: 64)
            }
        }
        .redacted(reason: .placeholder)
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("No payments here yet")
                .font(R.F.body(14, weight: .semibold))
                .foregroundStyle(R.C.fg1)
            Text("Paid bookings show up the moment the transfer lands.")
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, R.S.xxl)
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Couldn't load payments")
                .font(R.F.body(13, weight: .semibold))
                .foregroundStyle(R.C.fg1)
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
    }

    // MARK: — Helpers

    private func sumAmount(_ rows: [PaymentRow]) -> Decimal {
        rows.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func firstCcy(_ rows: [PaymentRow]) -> String {
        rows.first?.currency ?? store.items.first?.currency ?? "AED"
    }

    private var monthCurrency: String {
        store.items.first?.currency ?? "AED"
    }

    private func formatMoney(_ amount: Decimal, ccy: String) -> String {
        MoneyFormatter.compact(amount, currency: ccy)
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

// MARK: - Payment cell

private struct PaymentCell: View {
    let payment: PaymentRow

    var body: some View {
        HStack(spacing: R.S.md) {
            Cover(seed: payment.artistName, size: 40, cornerRadius: R.Rad.md)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.artistName)
                    .font(R.F.body(13.5, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(payment.eventLabel)
                    .font(R.F.body(11.5, weight: .regular))
                    .foregroundStyle(R.C.fg2)
                    .lineLimit(1)
            }
            Spacer(minLength: R.S.sm)
            VStack(alignment: .trailing, spacing: 4) {
                Text(payment.amountFormatted)
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
            case .paid:      return ("Paid",      R.C.green)
            case .pending:   return ("Pending",   R.C.amber)
            case .scheduled: return ("Scheduled", R.C.blue)
            case .failed:    return ("Failed",    R.C.red)
            case .refunded:  return ("Refunded",  R.C.fg3)
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
    let store = PaymentsStore()
    store._testLoad([
        PaymentRow(id: UUID(), artistName: "DJ NOVAK",  eventLabel: "WHITE Dubai · Tue 24",
                   amount: 28_000, currency: "AED", amountFormatted: "AED 28K",
                   status: .paid, eventDate: Date(), paidAt: Date()),
        PaymentRow(id: UUID(), artistName: "ORION KAI", eventLabel: "Blu Dahlia · Fri 27",
                   amount: 42_000, currency: "SAR", amountFormatted: "SAR 42K",
                   status: .pending, eventDate: Date().addingTimeInterval(86400 * 3), paidAt: nil)
    ])
    return PaymentsView(nav: nav)
        .environment(store)
        .preferredColorScheme(.dark)
}
#endif
