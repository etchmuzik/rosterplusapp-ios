// EPKView.swift — Screen 13
//
// The Electronic Press Kit — a polished, shareable artist profile.
// Port of `EpkScreen` at ios-app.jsx line 1189. Layout:
//
//   NavHeader("EPK") with share button
//   Full-bleed cover hero (240pt) with stage name overlay
//   Bio card
//   Past performances list (4 rows)
//   Press quotes — italic text with outlet label
//   Contact CTA — "Book via ROSTR+" (pushes to booking wizard)
//
// Anyone can view the EPK with a public link; promoters inside the
// app see the same page with the Contact CTA active.

import SwiftUI
import DesignSystem

public struct EPKView: View {
    @Bindable var nav: NavigationModel
    let artistID: String

    public init(nav: NavigationModel, artistID: String) {
        self.nav = nav
        self.artistID = artistID
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "EPK", onBack: { nav.pop() }) {
                Button {
                    // Share sheet — wires to UIActivityViewController in a later wave
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
                .accessibilityLabel("Share EPK")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.xl) {
                    coverHero
                    metaRow
                        .padding(.horizontal, R.S.lg)
                    bioCard
                        .padding(.horizontal, R.S.lg)
                    performancesSection
                        .padding(.horizontal, R.S.lg)
                    pressSection
                        .padding(.horizontal, R.S.lg)
                    Color.clear.frame(height: 120)
                }
                .padding(.top, R.S.sm)
            }
            contactCTA
        }
        .background(R.C.bg0)
    }

    // MARK: — Cover hero

    private var coverHero: some View {
        Cover(seed: artistName, size: nil, cornerRadius: 0)
            .frame(height: 260)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Electronic Press Kit")
                        .monoLabel(size: 9.5, tracking: 1.2, color: R.C.fg3)
                    Text(artistName)
                        .font(R.F.display(44, weight: .bold))
                        .tracking(-1.4)
                        .foregroundStyle(R.C.fg1)
                    Text("Tech House · Dubai")
                        .font(R.F.body(14, weight: .medium))
                        .foregroundStyle(R.C.fg2)
                }
                .padding(R.S.lg)
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, R.C.bg0.opacity(0.9)],
                    startPoint: .center, endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
    }

    // MARK: — Meta row

    private var metaRow: some View {
        HStack(spacing: R.S.sm) {
            MetaTile(label: "Residencies", value: "3")
            MetaTile(label: "Avg. crowd",  value: "1,350")
            MetaTile(label: "Since",       value: "2019")
        }
    }

    // MARK: — Bio card

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Text("About")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text("Dubai-based tech-house selector with residencies across WHITE, Soho Garden, and Blu Dahlia. Known for long, patient builds and an open-format back-to-back style. 5 years of regional touring, now playing the GCC + Cairo circuit. Rider arrives on time. Flights included.")
                .font(R.F.body(14, weight: .regular))
                .foregroundStyle(R.C.fg1.opacity(0.86))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Past performances

    private var performancesSection: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Past performances")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            VStack(spacing: R.S.xs) {
                ForEach(MockData.pastPerformances) { pp in
                    PerfRow(perf: pp)
                }
            }
        }
    }

    // MARK: — Press

    private var pressSection: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Press")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            VStack(spacing: R.S.sm) {
                ForEach(MockData.pressQuotes) { q in
                    QuoteCard(quote: q)
                }
            }
        }
    }

    // MARK: — Contact CTA

    private var contactCTA: some View {
        PrimaryButton("Book via ROSTR+", variant: .filled) {
            nav.push(.booking(artistID: artistID))
        }
        .padding(.horizontal, R.S.lg)
        .padding(.vertical, R.S.md)
        .background {
            LinearGradient(
                colors: [R.C.bg0.opacity(0), R.C.bg0.opacity(0.95), R.C.bg0],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }

    // MARK: — Derived

    private var artistName: String {
        // "me" signals the logged-in-artist EPK; otherwise look up by id.
        if artistID == "me" { return "NOVAK" }
        return MockData.artists.first { String($0.id) == artistID }?.stage ?? "NOVAK"
    }
}

// MARK: - Meta tile

private struct MetaTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            Text(value)
                .font(R.F.display(18, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(R.C.fg1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Performance row

private struct PerfRow: View {
    let perf: MockPastPerformance

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(perf.venue)
                    .font(R.F.body(13.5, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text("\(perf.city) · \(perf.crowd)")
                    .font(R.F.mono(9.5, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(R.C.fg3)
            }
            Spacer()
            Text(perf.date)
                .monoLabel(size: 9.5, tracking: 0.6, color: R.C.fg2)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Quote card

private struct QuoteCard: View {
    let quote: MockPressQuote

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Text("\u{201C}\(quote.quote)\u{201D}")
                .font(R.F.body(14, weight: .regular).italic())
                .foregroundStyle(R.C.fg1)
                .lineSpacing(3)
            Text(quote.outlet)
                .monoLabel(size: 9, tracking: 0.6, color: R.C.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
    }
}

#if DEBUG
#Preview("EPKView") {
    let nav = NavigationModel()
    return EPKView(nav: nav, artistID: "me")
        .preferredColorScheme(.dark)
}
#endif
