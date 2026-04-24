// InvoiceView.swift — Screen 23
//
// Tax invoice with line items, VAT, "paid" stamp. Port of
// `InvoiceScreen` at ios-app.jsx line 2147. Layout:
//
//   NavHeader("Invoice")
//   Card header  — ROSTR+ brand mark, "INVOICE", number, date
//   From / To    — two-column company + artist blocks
//   Line items   — table with label, qty, rate, total
//   Totals       — subtotal, VAT (5%), total (display font, large)
//   Paid stamp   — green rotated 18° overlay when status = paid
//   Share CTA    — triggers system share sheet (stubbed)

import SwiftUI
import DesignSystem

public struct InvoiceView: View {
    @Bindable var nav: NavigationModel
    let bookingID: String

    public init(nav: NavigationModel, bookingID: String) {
        self.nav = nav
        self.bookingID = bookingID
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Invoice", onBack: { nav.pop() }) {
                Button {
                    // Share sheet wires in later wave
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
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    invoiceCard
                        .padding(R.S.lg)
                    Color.clear.frame(height: R.S.huge)
                }
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Invoice card

    private var invoiceCard: some View {
        VStack(alignment: .leading, spacing: R.S.lg) {
            cardHeader
            Divider().overlay(R.C.borderSoft)
            fromTo
            Divider().overlay(R.C.borderSoft)
            lineItems
            Divider().overlay(R.C.borderSoft)
            totals
        }
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
        .overlay(alignment: .topTrailing) {
            paidStamp
        }
    }

    // MARK: — Card header

    private var cardHeader: some View {
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
                Text("RP-2026-0124")
                    .font(R.F.mono(12, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(R.C.fg1)
                Text("24 Apr 2026")
                    .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
            }
        }
    }

    // MARK: — From / To

    private var fromTo: some View {
        HStack(alignment: .top, spacing: R.S.lg) {
            addressBlock(
                label: "From",
                lines: ["Beyond Concierge Events Co. LLC", "Dubai Design District", "VAT TRN: 100234567800003"]
            )
            addressBlock(
                label: "Bill to",
                lines: ["DJ NOVAK / Artist", "Self-billed", "Dubai, UAE"]
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

    private var lineItems: some View {
        VStack(spacing: R.S.xs) {
            // Column headers
            HStack {
                Text("Description").monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
                Spacer()
                Text("Qty").monoLabel(size: 9, tracking: 0.6, color: R.C.fg3).frame(width: 30)
                Text("Amount").monoLabel(size: 9, tracking: 0.6, color: R.C.fg3).frame(width: 90, alignment: .trailing)
            }
            .padding(.bottom, 4)

            Line(label: "DJ Performance — 4 hours", qty: "1", amount: "AED 25,000")
            Line(label: "Rider (hospitality)",       qty: "1", amount: "AED 1,500")
            Line(label: "Travel + accommodation",    qty: "1", amount: "AED 1,500")
        }
    }

    // MARK: — Totals

    private var totals: some View {
        VStack(spacing: R.S.xs) {
            totalRow(label: "Subtotal", value: "AED 28,000")
            totalRow(label: "VAT (5%)", value: "AED 1,400")
            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .monoLabel(size: 11, tracking: 0.8, color: R.C.fg1)
                Spacer()
                Text("AED 29,400")
                    .font(R.F.display(22, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(R.C.fg1)
            }
            .padding(.top, R.S.xs)
        }
    }

    private func totalRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
            Spacer()
            Text(value)
                .font(R.F.mono(12, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(R.C.fg2)
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
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("InvoiceView") {
    let nav = NavigationModel()
    return InvoiceView(nav: nav, bookingID: "demo")
        .preferredColorScheme(.dark)
}
#endif
