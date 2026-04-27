// AnalyticsStore.swift
//
// There is no `analytics` table server-side — the dashboard is computed
// entirely from public.bookings. This store wraps BookingsStore and
// exposes the three display shapes the Analytics screen needs:
//
//   - monthly revenue totals (bar chart)
//   - genre share (stacked bar)
//   - top artists by gig count + total fee
//
// Everything is Observable-derived from the parent; no separate network
// call. When BookingsStore loads, the dashboard populates automatically.

import Foundation
import Observation

public struct AnalyticsMonth: Identifiable, Hashable, Sendable {
    public var id: String { label }
    public let label: String
    public let value: Double
}

public struct GenreShare: Identifiable, Hashable, Sendable {
    public var id: String { label }
    public let label: String
    public let share: Double
}

public struct TopArtist: Identifiable, Hashable, Sendable {
    public var id: String { stage }
    public let stage: String
    public let bookings: Int
    public let totalFee: String
}

@Observable
@MainActor
public final class AnalyticsStore {

    /// Source of truth for every derivation. Injected at init so tests
    /// and previews can swap in a loaded fixture store.
    public let bookings: BookingsStore

    public init(bookings: BookingsStore) {
        self.bookings = bookings
    }

    private var allBookings: [BookingRow] {
        bookings.upcoming + bookings.past
    }

    // MARK: — Monthly revenue (trailing 12 months)

    /// Returns the last 12 months, oldest → newest, so the bar chart
    /// reads left-to-right. Empty months still appear with value 0.
    public var months: [AnalyticsMonth] {
        let cal = Calendar.current
        let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            return []
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "LLL"

        var buckets: [(Date, String, Double)] = []
        for offset in (0..<12).reversed() {
            guard let d = cal.date(byAdding: .month, value: -offset, to: monthStart) else { continue }
            buckets.append((d, formatter.string(from: d), 0))
        }

        for b in allBookings {
            guard let fee = b.fee, fee > 0 else { continue }
            guard let target = cal.date(from: cal.dateComponents([.year, .month], from: b.eventDate)) else { continue }
            if let idx = buckets.firstIndex(where: { $0.0 == target }) {
                // Values shown in thousands for visual headroom. Bucket
                // is Double for chart rendering — Decimal would be over-
                // engineering here (the chart can't show >2-decimal
                // precision and the totals are tens of thousands at most).
                let thousands = NSDecimalNumber(decimal: fee).doubleValue / 1000
                buckets[idx].2 += thousands
            }
        }

        return buckets.map { AnalyticsMonth(label: $0.1, value: $0.2) }
    }

    // MARK: — Genre share

    /// Share is computed from the artist names embedded in each booking.
    /// We don't have per-booking genre server-side, so until RosterStore
    /// is wired in for cross-reference this ranks by raw artist names.
    /// Top four named buckets + an "Other" rollup.
    public var genreShares: [GenreShare] {
        let names = allBookings.map(\.artistName)
        guard !names.isEmpty else { return [] }
        var counts: [String: Int] = [:]
        for n in names { counts[n, default: 0] += 1 }
        let sorted = counts.sorted { $0.value > $1.value }
        let total = Double(names.count)
        let top = sorted.prefix(4)
        var out = top.map { GenreShare(label: $0.key, share: Double($0.value) / total) }
        if sorted.count > 4 {
            let otherCount = sorted.dropFirst(4).reduce(0) { $0 + $1.value }
            out.append(GenreShare(label: "Other", share: Double(otherCount) / total))
        }
        return out
    }

    // MARK: — Top artists

    /// Top 4 artists by number of bookings, tiebroken by total fee.
    public var topArtists: [TopArtist] {
        let grouped = Dictionary(grouping: allBookings, by: \.artistName)
        let tops = grouped
            .map { (stage, rows) -> (String, Int, Decimal, String) in
                let total: Decimal = rows.reduce(Decimal(0)) { $0 + ($1.fee ?? 0) }
                let ccy = rows.first?.currency ?? "AED"
                return (stage, rows.count, total, ccy)
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.2 > b.2
            }
            .prefix(4)

        return tops.map { stage, count, total, ccy in
            let formatted = MoneyFormatter.compact(total, currency: ccy)
            return TopArtist(stage: stage, bookings: count, totalFee: formatted)
        }
    }
}
