// AnalyticsView.swift — Screen 18
//
// Promoter analytics. Port of `AnalyticsScreen` at ios-app.jsx line 1600.
// Wave 5.1: every number is derived from BookingsStore via AnalyticsStore
// — there's no separate analytics table server-side.
//
// Deliberately SwiftUI-native — no Charts framework dep. The bar chart
// is a custom GeometryReader + RoundedRectangle grid so we control the
// exact visual (no Chart's default axis/legend chrome).

import SwiftUI
import DesignSystem

public struct AnalyticsView: View {
    @Bindable var nav: NavigationModel
    @Environment(AnalyticsStore.self) private var store

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Analytics", onBack: { nav.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.xl) {
                    summaryCard
                    monthlyChartCard
                    genreCard
                    topArtistsCard
                    Color.clear.frame(height: R.S.xxl)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.sm)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last 12 months")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text(totalLabel)
                .font(R.F.display(40, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(R.C.fg1)
            if !store.months.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(R.C.fg3)
                    Text("\(store.months.count) months tracked")
                        .monoLabel(size: 9.5, tracking: 0.5, color: R.C.fg3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    private var totalLabel: String {
        let total = store.months.reduce(0) { $0 + $1.value } // already in thousands
        let ccy = store.bookings.upcoming.first?.currency
            ?? store.bookings.past.first?.currency
            ?? "AED"
        if total >= 1000 {
            return "\(ccy) \(String(format: "%.2fM", total / 1000))"
        }
        if total > 0 {
            return "\(ccy) \(Int(total))K"
        }
        return "\(ccy) —"
    }

    // MARK: — Monthly chart

    private var monthlyChartCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Monthly spend")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("\(currency) thousands")
                    .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            }

            if store.months.isEmpty {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(R.C.glassLo)
                    .frame(height: 160)
                    .overlay {
                        Text("No revenue yet")
                            .monoLabel(size: 9.5, tracking: 0.6, color: R.C.fg3)
                    }
            } else {
                BarChart(months: store.months)
                    .frame(height: 160)
            }

            Divider().overlay(R.C.borderSoft)

            // Peak + average derived from the months array.
            HStack(spacing: R.S.lg) {
                miniFact(label: "Peak",    value: peakFact)
                miniFact(label: "Average", value: averageFact)
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    private var currency: String {
        store.bookings.upcoming.first?.currency ?? store.bookings.past.first?.currency ?? "AED"
    }

    private var peakFact: String {
        guard let top = store.months.max(by: { $0.value < $1.value }), top.value > 0 else {
            return "—"
        }
        return "\(top.label) · \(Int(top.value))K"
    }

    private var averageFact: String {
        let active = store.months.filter { $0.value > 0 }
        guard !active.isEmpty else { return "—" }
        let avg = active.reduce(0) { $0 + $1.value } / Double(active.count)
        return "\(currency) \(Int(avg))K"
    }

    private func miniFact(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .monoLabel(size: 9, tracking: 0.6, color: R.C.fg3)
            Text(value)
                .font(R.F.mono(11, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(R.C.fg1)
        }
    }

    // MARK: — Genre

    private var genreCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            Text("Top performers")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)

            if store.genreShares.isEmpty {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(R.C.glassLo)
                    .frame(height: 10)
            } else {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(Array(store.genreShares.enumerated()), id: \.element.id) { index, g in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(shade(for: index, count: store.genreShares.count))
                                .frame(width: (geo.size.width - CGFloat(max(store.genreShares.count - 1, 0)) * 2) * g.share)
                        }
                    }
                }
                .frame(height: 10)

                VStack(spacing: R.S.xs) {
                    ForEach(Array(store.genreShares.enumerated()), id: \.element.id) { index, g in
                        HStack(spacing: R.S.sm) {
                            Circle()
                                .fill(shade(for: index, count: store.genreShares.count))
                                .frame(width: 8, height: 8)
                            Text(g.label)
                                .font(R.F.body(13, weight: .medium))
                                .foregroundStyle(R.C.fg1)
                            Spacer()
                            Text("\(Int(g.share * 100))%")
                                .monoLabel(size: 10, tracking: 0.4, color: R.C.fg2)
                        }
                    }
                }
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    /// Mono ramp: brightest at index 0, fading for the tail.
    private func shade(for index: Int, count: Int) -> Color {
        let total = max(count - 1, 1)
        let t = 1.0 - (Double(index) / Double(total)) * 0.65
        return Color.white.opacity(t)
    }

    // MARK: — Top artists

    private var topArtistsCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Top artists")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                .padding(.horizontal, R.S.xs)

            if store.topArtists.isEmpty {
                Text("No bookings yet.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .padding(.vertical, R.S.md)
            } else {
                VStack(spacing: R.S.xs) {
                    ForEach(Array(store.topArtists.enumerated()), id: \.element.id) { index, artist in
                        HStack(alignment: .center, spacing: R.S.md) {
                            Text(String(format: "%02d", index + 1))
                                .monoLabel(size: 11, tracking: 0.6, color: R.C.fg3)
                                .frame(width: 22, alignment: .leading)
                            Cover(seed: artist.stage, size: 36, cornerRadius: R.Rad.sm)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(artist.stage)
                                    .font(R.F.body(13.5, weight: .semibold))
                                    .foregroundStyle(R.C.fg1)
                                Text("\(artist.bookings) bookings")
                                    .font(R.F.mono(9.5, weight: .medium))
                                    .tracking(0.5)
                                    .foregroundStyle(R.C.fg3)
                            }
                            Spacer()
                            Text(artist.totalFee)
                                .font(R.F.mono(11, weight: .semibold))
                                .tracking(0.3)
                                .foregroundStyle(R.C.fg1)
                        }
                        .padding(R.S.md)
                        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
                    }
                }
            }
        }
    }
}

// MARK: - Bar chart

private struct BarChart: View {
    let months: [AnalyticsMonth]

    private var peak: Double {
        max(months.map(\.value).max() ?? 1, 1)
    }

    /// Last month is "current" — highlights brighter than the rest.
    private var activeIndex: Int { months.count - 1 }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let chartHeight = h - 18
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(months.enumerated()), id: \.element.id) { index, m in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == activeIndex ? R.C.fg1 : R.C.glassMid)
                            .frame(height: max(4, chartHeight * (m.value / peak)))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
                            }
                        Text(m.label)
                            .monoLabel(size: 8.5, tracking: 0.4, color: index == activeIndex ? R.C.fg1 : R.C.fg3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#if DEBUG
#Preview("AnalyticsView") {
    let nav = NavigationModel()
    let bookings = BookingsStore()
    let analytics = AnalyticsStore(bookings: bookings)
    bookings._testLoad(
        upcoming: [
            BookingRow(id: UUID(), eventName: "A", artistName: "DJ NOVAK",  venueName: "V1",
                       eventDate: Date(), status: "confirmed",
                       feeFormatted: "AED 28K", currency: "AED", fee: 28_000)
        ],
        past: [
            BookingRow(id: UUID(), eventName: "B", artistName: "DJ NOVAK",  venueName: "V2",
                       eventDate: Date().addingTimeInterval(-30 * 86_400), status: "completed",
                       feeFormatted: "AED 24K", currency: "AED", fee: 24_000),
            BookingRow(id: UUID(), eventName: "C", artistName: "MIRELA",    venueName: "V3",
                       eventDate: Date().addingTimeInterval(-60 * 86_400), status: "completed",
                       feeFormatted: "AED 18K", currency: "AED", fee: 18_000)
        ]
    )
    return AnalyticsView(nav: nav)
        .environment(analytics)
        .preferredColorScheme(.dark)
}
#endif
