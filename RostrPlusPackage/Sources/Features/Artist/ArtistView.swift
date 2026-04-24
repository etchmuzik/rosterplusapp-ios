// ArtistView.swift — Screen 04
//
// Public artist profile. Port of `ArtistScreen` at ios-app.jsx line 396.
// Reads live data from ArtistDetailStore (keyed by artist id). Shows
// a loading placeholder until the detail cache warms up.

import SwiftUI
import DesignSystem

public struct ArtistView: View {
    @Bindable var nav: NavigationModel
    @Environment(ArtistDetailStore.self) private var store
    let artistID: UUID

    public init(nav: NavigationModel, artistID: UUID) {
        self.nav = nav
        self.artistID = artistID
    }

    private var loaded: ArtistDetail? { store.cache[artistID] }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Profile", onBack: { nav.pop() })
            ScrollView {
                if let artist = loaded {
                    VStack(alignment: .leading, spacing: R.S.xl) {
                        coverHero(artist)
                            .padding(.horizontal, R.S.lg)
                            .padding(.top, R.S.sm)
                        factsRow(artist)
                            .padding(.horizontal, R.S.lg)
                        bioCard(artist)
                            .padding(.horizontal, R.S.lg)
                        availabilityStrip
                            .padding(.horizontal, R.S.lg)
                        recentSets(artist)
                            .padding(.horizontal, R.S.lg)
                        Color.clear.frame(height: 120)
                    }
                } else {
                    loadingPlaceholder
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.xl)
                }
            }
            stickyCTAs
        }
        .background(R.C.bg0)
        .task {
            store.fetch(id: artistID)
        }
    }

    // MARK: — Cover hero

    private func coverHero(_ artist: ArtistDetail) -> some View {
        Cover(seed: artist.stageName, size: nil, cornerRadius: R.Rad.card3)
            .frame(height: 220)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.stageName)
                        .font(R.F.display(34, weight: .bold))
                        .tracking(-1.2)
                        .foregroundStyle(R.C.fg1)
                    Text(subtitle(for: artist))
                        .font(R.F.body(13, weight: .medium))
                        .foregroundStyle(R.C.fg2)
                }
                .padding(R.S.lg)
            }
            .overlay(alignment: .topTrailing) {
                if artist.verified {
                    AvailPill(.avail)
                        .padding(R.S.md)
                }
            }
    }

    private func subtitle(for artist: ArtistDetail) -> String {
        let genre = artist.genres.first ?? "Artist"
        let city  = artist.citiesActive.first ?? "GCC"
        return "\(genre) · \(city)"
    }

    // MARK: — Facts row

    private func factsRow(_ artist: ArtistDetail) -> some View {
        HStack(spacing: R.S.sm) {
            Fact(
                label: "Rating",
                value: artist.rating > 0 ? String(format: "%.1f", artist.rating) : "—",
                icon: "star.fill",
                iconColor: R.C.amber
            )
            Fact(
                label: "Base fee",
                value: artist.baseFee.map { "\(artist.currency) \(Int($0 / 1000))K" } ?? "—",
                icon: nil
            )
            Fact(label: "Bookings", value: "\(artist.totalBookings)", icon: nil)
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
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

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

    // MARK: — Availability strip (placeholder — server schema lands later)

    private var availabilityStrip: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack {
                Text("Next 7 days")
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
                Spacer()
                Text("Tap to request")
                    .monoLabel(size: 8.5, tracking: 0.5, color: R.C.fg3)
            }
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let state: (Color, String) = stateFor(i)
                    VStack(spacing: 6) {
                        Text(["MON","TUE","WED","THU","FRI","SAT","SUN"][i])
                            .monoLabel(size: 8, tracking: 0.6, color: R.C.fg3)
                        Circle()
                            .fill(state.0)
                            .frame(width: 10, height: 10)
                        Text(state.1)
                            .monoLabel(size: 7.5, tracking: 0.4, color: state.0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, R.S.xs)
                    .background {
                        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                            .fill(R.C.glassLo)
                    }
                }
            }
        }
    }

    private func stateFor(_ i: Int) -> (Color, String) {
        // Until artists.blocked_dates is wired through a derivation,
        // show a neutral "FREE" pattern so the strip doesn't feel noisy.
        switch i {
        case 1: return (R.C.amber, "TIGHT")
        case 4: return (R.C.red,   "BOOKED")
        default: return (R.C.green, "FREE")
        }
    }

    // MARK: — Recent sets (derived from past_performances JSONB)

    private func recentSets(_ artist: ArtistDetail) -> some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Recent sets")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            if artist.pastPerformances.isEmpty {
                Text("No recent performances listed.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .padding(.vertical, R.S.sm)
            } else {
                VStack(spacing: R.S.xs) {
                    ForEach(artist.pastPerformances.prefix(3)) { perf in
                        SetRow(venue: perf.venue, date: perf.date ?? "—")
                    }
                }
            }
        }
    }

    // MARK: — Sticky CTAs

    private var stickyCTAs: some View {
        HStack(spacing: R.S.sm) {
            PrimaryButton("Message", variant: .ghost) {
                nav.push(.thread(threadID: artistID.uuidString))
            }
            PrimaryButton("Request booking", variant: .filled) {
                nav.push(.booking(artistID: artistID.uuidString))
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, R.S.lg)
        .padding(.vertical, R.S.md)
        .background {
            LinearGradient(
                colors: [R.C.bg0.opacity(0.0), R.C.bg0.opacity(0.95), R.C.bg0],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }

    // MARK: — Loading

    private var loadingPlaceholder: some View {
        VStack(spacing: R.S.lg) {
            RoundedRectangle(cornerRadius: R.Rad.card3, style: .continuous)
                .fill(R.C.glassLo)
                .frame(height: 220)
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

// MARK: - Facts tile

private struct Fact: View {
    let label: String
    let value: String
    let icon: String?
    var iconColor: Color = R.C.fg2

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .monoLabel(size: 8.5, tracking: 0.6, color: R.C.fg3)
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                Text(value)
                    .font(R.F.display(16, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(R.C.fg1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Set row

private struct SetRow: View {
    let venue: String
    let date: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(venue)
                    .font(R.F.body(13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(date)
                    .font(R.F.mono(9.5, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(R.C.fg3)
            }
            Spacer()
            ChevronRightIcon(size: 11, color: R.C.fg3)
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

#if DEBUG
#Preview("ArtistView") {
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
            pressQuotes: [],
            pastPerformances: [
                .init(venue: "WHITE Dubai", city: "Dubai", date: "12 Apr", crowd: "1,400")
            ],
            social: nil
        )
    )
    return ArtistView(nav: nav, artistID: id)
        .environment(store)
        .preferredColorScheme(.dark)
}
#endif
