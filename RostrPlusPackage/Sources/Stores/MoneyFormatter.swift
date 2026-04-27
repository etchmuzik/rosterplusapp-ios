// MoneyFormatter.swift
//
// Single home for the "AED 28K" / "AED 28,000" rendering used across
// PaymentsView, BookingsView, ArtistView, and InvoiceView.
//
// Money is `Decimal` end-to-end — never `Double`. `Decimal` arithmetic
// is exact for any sum of base-10 values, which matters for invoice
// totals, scheduled-vs-paid splits, and tax exports. A `Double`-based
// formatter sums "AED 28,000" + "AED 28,000" + "AED 28,000" to
// 84_000.000000000003 in the worst case and surfaces wrong totals;
// `Decimal` is the safe default.

import Foundation

public enum MoneyFormatter {

    /// Compact display: "AED 28K", "AED 28.5K", "AED 999". Used in
    /// list cells where vertical density matters.
    public static func compact(_ amount: Decimal, currency: String) -> String {
        let ccy = currency.isEmpty ? "AED" : currency
        let abs = amount.magnitude
        if abs >= 1000 {
            let thousands = amount / 1000
            // Whole-thousand → "28K". Otherwise one decimal → "28.5K".
            let isWhole = (thousands - thousands.rounded(0, .down)) == 0
            if isWhole {
                return "\(ccy) \(Self.intString(thousands))K"
            }
            return "\(ccy) \(Self.fixedString(thousands, fractionDigits: 1))K"
        }
        return "\(ccy) \(Self.intString(amount))"
    }

    /// Full display: "AED 28,500" with thousands separators. Used on
    /// invoice + booking-detail screens where the exact amount matters.
    public static func full(_ amount: Decimal, currency: String) -> String {
        let ccy = currency.isEmpty ? "AED" : currency
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        let n = NSDecimalNumber(decimal: amount)
        let body = f.string(from: n) ?? "\(amount)"
        return "\(ccy) \(body)"
    }

    // MARK: — Private helpers

    /// Truncate a Decimal to its integer string. Avoids the
    /// Decimal → Double → Int hop which loses precision on large values.
    private static func intString(_ d: Decimal) -> String {
        var v = d
        var rounded = Decimal()
        NSDecimalRound(&rounded, &v, 0, .down)
        return NSDecimalNumber(decimal: rounded).stringValue
    }

    private static func fixedString(_ d: Decimal, fractionDigits: Int) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        return f.string(from: NSDecimalNumber(decimal: d)) ?? "\(d)"
    }
}

private extension Decimal {
    /// Convenience: round-to-N-places returning a new value, mirroring
    /// `Double.rounded(_:)`. We need this in MoneyFormatter without
    /// reaching for NSDecimalRound at every callsite.
    func rounded(_ scale: Int, _ mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var v = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &v, scale, mode)
        return rounded
    }
}
