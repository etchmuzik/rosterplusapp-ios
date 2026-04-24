// AnalyticsView.swift — Screen 18
//
// Promoter analytics. Port of `AnalyticsScreen` at ios-app.jsx line
// 1600. Three sections:
//
//   1. 12-month bar chart of monthly spend (display font totals, mono
//      axis labels, active-month bar in fg1, others in glass)
//   2. Genre breakdown — horizontal stacked bar split by share, below
//      it a legend list with each genre's %
//   3. Top artists — ranked list of the promoter's top 4 artists by
//      total fee, with booking count
//
// Deliberately SwiftUI-native — no Charts framework dep. The bar chart
// is a custom GeometryReader + RoundedRectangle grid so we control the
// exact visual (no Chart's default axis/legend chrome).

import SwiftUI
import DesignSystem

public struct AnalyticsView: View {
    @Bindable var nav: NavigationModel

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
            Text("AED 1.24M")
                .font(R.F.display(40, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(R.C.fg1)
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(R.C.green)
                Text("18% vs prior year")
                    .monoLabel(size: 9.5, tracking: 0.5, color: R.C.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    // MARK: — Monthly chart

    private var monthlyChartCard: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Monthly spend")
                    .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("AED thousands")
                    .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            }

            BarChart(months: MockData.analyticsMonths)
                .frame(height: 160)

            Divider().overlay(R.C.borderSoft)

            // Mini facts row — peak + average.
            HStack(spacing: R.S.lg) {
                miniFact(label: "Peak",    value: "Apr · 186K")
                miniFact(label: "Average", value: "AED 103K")
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
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
            Text("Genre breakdown")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)

            // Stacked horizontal bar.
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(MockData.genreShares.enumerated()), id: \.element.id) { index, g in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(shade(for: index))
                            .frame(width: (geo.size.width - CGFloat(MockData.genreShares.count - 1) * 2) * g.share)
                    }
                }
            }
            .frame(height: 10)

            // Legend list.
            VStack(spacing: R.S.xs) {
                ForEach(Array(MockData.genreShares.enumerated()), id: \.element.id) { index, g in
                    HStack(spacing: R.S.sm) {
                        Circle()
                            .fill(shade(for: index))
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
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    /// Mono ramp: brightest at index 0, fading to fg3 for "Other".
    private func shade(for index: Int) -> Color {
        let total = max(MockData.genreShares.count - 1, 1)
        let t = 1.0 - (Double(index) / Double(total)) * 0.65  // 1.0 → 0.35
        return Color.white.opacity(t)
    }

    // MARK: — Top artists

    private var topArtistsCard: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Top artists")
                .monoLabel(size: 10, tracking: 0.8, color: R.C.fg3)
                .padding(.horizontal, R.S.xs)

            VStack(spacing: R.S.xs) {
                ForEach(Array(MockData.topArtists.enumerated()), id: \.element.id) { index, artist in
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

// MARK: - Bar chart

private struct BarChart: View {
    let months: [MockAnalyticsMonth]

    private var peak: Double {
        max(months.map(\.value).max() ?? 1, 1)
    }

    /// Last month is "current" — highlights brighter than the rest, to
    /// mirror the JSX chart's active-bar treatment.
    private var activeIndex: Int { months.count - 1 }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let chartHeight = h - 18  // leave room for the x-axis label row
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
    return AnalyticsView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
