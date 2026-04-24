// EPKView.swift — Screen 13
//
// The Electronic Press Kit — a polished, shareable artist profile.
// Port of `EpkScreen` at ios-app.jsx line 1189.
//
// Wave 5.1: reads live data from ArtistDetailStore. The JSONB fields
// `press_quotes` + `past_performances` on public.artists carry the
// display-ready payloads; we just decode and render.
//
// When artistID == "me" we fall back to the current user's artist row
// via their auth user id (the ArtistDashboard flow already warms that
// cache; in the self-service case we fetch on demand).

import SwiftUI
import DesignSystem

public struct EPKView: View {
    @Bindable var nav: NavigationModel
    @Environment(ArtistDetailStore.self) private var detail
    let artistID: String

    public init(nav: NavigationModel, artistID: String) {
        self.nav = nav
        self.artistID = artistID
    }

    private var resolvedID: UUID? { UUID(uuidString: artistID) }

    private var loaded: ArtistDetail? {
        if let id = resolvedID { return detail.cache[id] }
        return nil
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
                if let artist = loaded {
                    VStack(alignment: .leading, spacing: R.S.xl) {
                        coverHero(artist)
                        metaRow(artist)
                            .padding(.horizontal, R.S.lg)
                        bioCard(artist)
                            .padding(.horizontal, R.S.lg)
                        performancesSection(artist)
                            .padding(.horizontal, R.S.lg)
                        pressSection(artist)
                            .padding(.horizontal, R.S.lg)
                        Color.clear.frame(height: 120)
                    }
                    .padding(.top, R.S.sm)
                } else {
                    loadingPlaceholder
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.xl)
                }
            }
            contactCTA
        }
        .background(R.C.bg0)
        .task {
            if let id = resolvedID { detail.fetch(id: id) }
        }
    }

    // MARK: — Cover hero

    private func coverHero(_ artist: ArtistDetail) -> some View {
        Cover(seed: artist.stageName, size: nil, cornerRadius: 0)
            .frame(height: 260)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Electronic Press Kit")
                        .monoLabel(size: 9.5, tracking: 1.2, color: R.C.fg3)
                    Text(artist.stageName)
                        .font(R.F.display(44, weight: .bold))
                        .tracking(-1.4)
                        .foregroundStyle(R.C.fg1)
                    Text(subtitle(for: artist))
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

    private func subtitle(for artist: ArtistDetail) -> String {
        let genre = artist.genres.first ?? "Artist"
        let city  = artist.citiesActive.first ?? "GCC"
        return "\(genre) · \(city)"
    }

    // MARK: — Meta row

    private func metaRow(_ artist: ArtistDetail) -> some View {
        HStack(spacing: R.S.sm) {
            MetaTile(label: "Rating",    value: artist.rating > 0 ? String(format: "%.1f", artist.rating) : "—")
            MetaTile(label: "Bookings",  value: "\(artist.totalBookings)")
            MetaTile(label: "Base fee",  value: artist.baseFee.map { "\(artist.currency) \(Int($0 / 1000))K" } ?? "—")
        }
    }

    // MARK: — Bio card

    private func bioCard(_ artist: ArtistDetail) -> some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Text("About")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text(bioText(for: artist))
                .font(R.F.body(14, weight: .regular))
                .foregroundStyle(R.C.fg1.opacity(0.86))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    /// Fallback bio when the server-side `bio` isn't part of our DTO yet.
    /// Wave 5.2 pulls the full profiles.bio column via a join.
    private func bioText(for artist: ArtistDetail) -> String {
        let cities = artist.citiesActive.joined(separator: ", ")
        let genreList = artist.genres.prefix(3).joined(separator: ", ")
        var parts: [String] = []
        if !cities.isEmpty { parts.append("Active in \(cities).") }
        if !genreList.isEmpty { parts.append("Plays \(genreList).") }
        if artist.verified { parts.append("Verified on ROSTR+.") }
        return parts.isEmpty
            ? "A ROSTR+ artist, available for bookings across the GCC."
            : parts.joined(separator: " ")
    }

    // MARK: — Past performances

    private func performancesSection(_ artist: ArtistDetail) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Past performances")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            if artist.pastPerformances.isEmpty {
                Text("No past performances listed yet.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .padding(.vertical, R.S.sm)
            } else {
                VStack(spacing: R.S.xs) {
                    ForEach(artist.pastPerformances) { pp in
                        PerfRow(perf: pp)
                    }
                }
            }
        }
    }

    // MARK: — Press

    private func pressSection(_ artist: ArtistDetail) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Press")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            if artist.pressQuotes.isEmpty {
                Text("No press quotes yet.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .padding(.vertical, R.S.sm)
            } else {
                VStack(spacing: R.S.sm) {
                    ForEach(artist.pressQuotes) { q in
                        QuoteCard(quote: q)
                    }
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

    // MARK: — Loading

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: R.S.lg) {
            RoundedRectangle(cornerRadius: R.Rad.card3, style: .continuous)
                .fill(R.C.glassLo)
                .frame(height: 260)
            HStack(spacing: R.S.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .fill(R.C.glassLo)
                        .frame(height: 64)
                }
            }
        }
        .redacted(reason: .placeholder)
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
    let perf: ArtistDTO.PastPerformance

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(perf.venue)
                    .font(R.F.body(13.5, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(subtitle)
                    .font(R.F.mono(9.5, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(R.C.fg3)
            }
            Spacer()
            Text(perf.date ?? "—")
                .monoLabel(size: 9.5, tracking: 0.6, color: R.C.fg2)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }

    private var subtitle: String {
        switch (perf.city, perf.crowd) {
        case let (city?, crowd?): return "\(city) · \(crowd)"
        case let (city?, nil):    return city
        case let (nil, crowd?):   return crowd
        default:                  return ""
        }
    }
}

// MARK: - Quote card

private struct QuoteCard: View {
    let quote: ArtistDTO.PressQuote

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
    let store = ArtistDetailStore()
    let id = UUID()
    store._testLoad(
        ArtistDetail(
            id: id,
            stageName: "DJ NOVAK",
            genres: ["Tech House"],
            citiesActive: ["Dubai"],
            baseFee: 28_000,
            currency: "AED",
            rating: 4.9,
            totalBookings: 32,
            verified: true,
            epkURL: nil,
            pressQuotes: [
                .init(outlet: "MixMag ME", quote: "A controlled burn of a set — leaves the room breathing heavy."),
                .init(outlet: "Time Out Dubai", quote: "The house selector you didn't know you needed.")
            ],
            pastPerformances: [
                .init(venue: "WHITE Dubai", city: "Dubai", date: "12 Apr", crowd: "1,400 people"),
                .init(venue: "Blu Dahlia",  city: "Riyadh", date: "28 Mar", crowd: "800 people")
            ],
            social: nil
        )
    )
    return EPKView(nav: nav, artistID: id.uuidString)
        .environment(store)
        .preferredColorScheme(.dark)
}
#endif
