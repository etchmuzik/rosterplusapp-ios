// InvoiceView.swift — Screen 23
//
// Tax invoice with line items, VAT, "paid" stamp. Reads live data
// via InvoiceStore (one PaymentDTO per booking_id, RLS-scoped to the
// promoter / artist parties). Renders three states:
//
//   .loading  — neutral skeleton (no booking-specific copy)
//   .failed   — shared FailureCard with retry CTA
//   .loaded   — the real card with totals derived from the payment
//
// Share button (C8) opens the system share sheet with the public
// invoice URL. The web invoice page accepts ?id=<bookingID>.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct InvoiceView: View {
    @Bindable var nav: NavigationModel
    @Environment(InvoiceStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(ProfileStore.self) private var profile
    let bookingID: String

    @State private var showingShareSheet = false

    public init(nav: NavigationModel, bookingID: String) {
        self.nav = nav
        self.bookingID = bookingID
    }

    private var resolvedID: UUID? { UUID(uuidString: bookingID) }

    private var loaded: Invoice? {
        if let id = resolvedID { return store.cache[id] }
        return nil
    }

    private var shareURL: URL? {
        URL(string: "https://rosterplus.io/invoice.html?id=\(bookingID)")
    }

    private var billToName: String {
        if let name = profile.current?.displayName, !name.isEmpty { return name }
        if case .signedIn(_, let email, _) = auth.state, let local = email.split(separator: "@").first {
            return String(local)
        }
        return "Account holder"
    }

    private var billToEmail: String? {
        if let email = profile.current?.email, !email.isEmpty { return email }
        if case .signedIn(_, let email, _) = auth.state, !email.isEmpty { return email }
        return nil
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Invoice", onBack: { nav.pop() }) {
                Button {
                    #if canImport(UIKit)
                    Haptics.tap()
                    #endif
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
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
                .accessibilityLabel("Share invoice")
                .disabled(loaded == nil || shareURL == nil)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                        .padding(R.S.lg)
                    Color.clear.frame(height: R.S.huge)
                }
            }
        }
        .background(R.C.bg0)
        .task {
            if let id = resolvedID {
                store.fetch(bookingID: id, billToName: billToName, billToEmail: billToEmail)
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL, let invoice = loaded {
                let label = invoice.invoiceNumber ?? "ROSTR+ invoice"
                ShareSheet(items: ["\(label) — view your ROSTR+ invoice", url])
            }
        }
        #endif
    }

    // MARK: — Content router

    @ViewBuilder
    private var content: some View {
        if let invoice = loaded {
            invoiceCard(invoice)
        } else if case .failed(let message) = store.state {
            FailureCard(heading: S.State.errorBooking, message: message) {
                if let id = resolvedID {
                    store.fetch(bookingID: id, billToName: billToName, billToEmail: billToEmail)
                }
            }
        } else {
            invoiceSkeleton
        }
    }

    // MARK: — Invoice card

    private func invoiceCard(_ invoice: Invoice) -> some View {
        VStack(alignment: .leading, spacing: R.S.lg) {
            cardHeader(invoice)
            Divider().overlay(R.C.borderSoft)
            fromTo(invoice)
            Divider().overlay(R.C.borderSoft)
            lineItems(invoice)
            Divider().overlay(R.C.borderSoft)
            totals(invoice)
        }
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
        .overlay(alignment: .topTrailing) {
            if invoice.status == .paid { paidStamp }
        }
    }

    // MARK: — Card header

    private func cardHeader(_ invoice: Invoice) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ROSTR+")
                    .font(R.F.display(20, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(R.C.fg1)
                Text("Beyond Concierge Events Co. LLC")
                    .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("INVOICE")
                    .monoLabel(size: 10, tracking: 1.2, color: R.C.fg3)
                Text(invoice.invoiceNumber ?? "—")
                    .font(R.F.mono(12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(R.C.fg1)
                Text(formatDate(invoice.issuedAt ?? invoice.eventDate))
                    .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
            }
        }
    }

    // MARK: — From / To

    private func fromTo(_ invoice: Invoice) -> some View {
        HStack(alignment: .top, spacing: R.S.lg) {
            addressBlock(
                label: "From",
                lines: [
                    "Beyond Concierge Events Co. LLC",
                    "Dubai Design District",
                    "VAT TRN: 100234567800003"
                ]
            )
            addressBlock(
                label: "Bill to",
                lines: [
                    invoice.billToName,
                    invoice.billToEmail ?? "—",
                    invoice.venueName ?? "—"
                ]
            )
        }
    }

    private func addressBlock(label: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
                .padding(.bottom, 3)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: — Line items

    private func lineItems(_ invoice: Invoice) -> some View {
        VStack(spacing: R.S.xs) {
            HStack {
                Text("Description").monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
                Spacer()
                Text("Qty").monoLabel(size: 9, tracking: 0.6, color: R.C.fg3).frame(width: 30)
                Text("Amount").monoLabel(size: 9, tracking: 0.6, color: R.C.fg3).frame(width: 110, alignment: .trailing)
            }
            .padding(.bottom, 4)

            // Single line item — the booking fee. Itemised line-item
            // breakdowns aren't on the payments table yet; keep this
            // honest until the schema grows them.
            Line(
                label: "\(invoice.artistName) — performance",
                qty: "1",
                amount: MoneyFormatter.compact(invoice.amount, currency: invoice.currency)
            )
        }
    }

    // MARK: — Totals

    private func totals(_ invoice: Invoice) -> some View {
        let total = invoice.amount
        return VStack(spacing: R.S.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .monoLabel(size: 11, tracking: 0.8, color: R.C.fg1)
                Spacer()
                Text(MoneyFormatter.compact(total, currency: invoice.currency))
                    .font(R.F.display(22, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(R.C.fg1)
            }
            .padding(.top, R.S.xs)
        }
    }

    // MARK: — Paid stamp

    private var paidStamp: some View {
        Text("PAID")
            .font(R.F.display(28, weight: .bold))
            .tracking(2)
            .foregroundStyle(R.C.green)
            .padding(.horizontal, R.S.md)
            .padding(.vertical, 6)
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.xs, style: .continuous)
                    .strokeBorder(R.C.green, lineWidth: 2)
            }
            .rotationEffect(.degrees(-18))
            .padding(R.S.xxl)
            .opacity(0.75)
    }

    // MARK: — Skeleton

    private var invoiceSkeleton: some View {
        VStack(alignment: .leading, spacing: R.S.lg) {
            HStack {
                RoundedRectangle(cornerRadius: 6).fill(R.C.glassLo).frame(width: 100, height: 22)
                Spacer()
                RoundedRectangle(cornerRadius: 6).fill(R.C.glassLo).frame(width: 80, height: 22)
            }
            Divider().overlay(R.C.borderSoft)
            HStack(spacing: R.S.lg) {
                RoundedRectangle(cornerRadius: 6).fill(R.C.glassLo).frame(height: 64)
                RoundedRectangle(cornerRadius: 6).fill(R.C.glassLo).frame(height: 64)
            }
            Divider().overlay(R.C.borderSoft)
            RoundedRectangle(cornerRadius: 6).fill(R.C.glassLo).frame(height: 32)
        }
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
        .redacted(reason: .placeholder)
    }

    // MARK: — Helpers

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Line

private struct Line: View {
    let label: String
    let qty: String
    let amount: String

    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(R.F.body(12.5, weight: .regular))
                .foregroundStyle(R.C.fg1)
                .lineLimit(2)
            Spacer()
            Text(qty)
                .font(R.F.mono(11, weight: .medium))
                .foregroundStyle(R.C.fg2)
                .frame(width: 30)
            Text(amount)
                .font(R.F.mono(11.5, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(R.C.fg1)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("InvoiceView") {
    let nav = NavigationModel()
    return InvoiceView(nav: nav, bookingID: "00000000-0000-0000-0000-000000000000")
        .environment(InvoiceStore())
        .environment(AuthStore())
        .environment(ProfileStore())
        .preferredColorScheme(.dark)
}
#endif
