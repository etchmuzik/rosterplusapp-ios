// RosterView.swift — Screen 03
//
// Browse artists with search + genre filter chips. Mirrors `RosterScreen`
// at ios-app.jsx line 306. Layout:
//
//   1. Search field
//   2. Horizontal scroll of filter chips (All · Tech House · Deep · …)
//   3. 2-column card grid — each card: Cover, stage name, genre · city,
//      rating row, availability pill
//
// Tapping a card pushes .artist(artistID:) onto the nav stack.

import SwiftUI
import DesignSystem

public struct RosterView: View {
    @Bindable var nav: NavigationModel
    @State private var search: String = ""
    @State private var genreFilter: String = "All"

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchField
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.md)
                filterChips
                    .padding(.top, R.S.md)
                grid
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.lg)
                Color.clear.frame(height: 100) // tab-bar clearance
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Roster")
                .font(R.F.display(30, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(R.C.fg1)
            Text("\(filtered.count) artists · live roster")
                .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, R.S.lg)
        .padding(.top, R.S.sm)
    }

    // MARK: — Search

    private var searchField: some View {
        HStack(spacing: R.S.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(R.C.fg3)
            TextField("", text: $search, prompt: Text("Search artists").foregroundStyle(R.C.fg3))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(R.C.fg1)
                .font(R.F.body(14))
        }
        .padding(.horizontal, R.S.md)
        .padding(.vertical, 11)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft, showsInnerHighlight: false)
    }

    // MARK: — Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: R.S.xs) {
                ForEach(genres, id: \.self) { g in
                    Chip(label: g, isActive: genreFilter == g) {
                        genreFilter = g
                    }
                }
            }
            .padding(.horizontal, R.S.lg)
        }
    }

    private var genres: [String] {
        ["All"] + Array(Set(MockData.artists.map(\.genre))).sorted()
    }

    // MARK: — Grid

    private var grid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: R.S.sm),
            GridItem(.flexible(), spacing: R.S.sm)
        ], spacing: R.S.sm) {
            ForEach(filtered) { artist in
                Button {
                    nav.push(.artist(artistID: String(artist.id)))
                } label: {
                    ArtistCard(artist: artist)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filtered: [MockArtist] {
        MockData.artists.filter { a in
            (genreFilter == "All" || a.genre == genreFilter) &&
            (search.isEmpty ||
             a.stage.localizedCaseInsensitiveContains(search) ||
             a.genre.localizedCaseInsensitiveContains(search) ||
             a.city.localizedCaseInsensitiveContains(search))
        }
    }
}

// MARK: - Chip

private struct Chip: View {
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

// MARK: - Artist card

private struct ArtistCard: View {
    let artist: MockArtist

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Cover(seed: artist.stage, size: nil, cornerRadius: R.Rad.button2)
                .frame(height: 140)
                .overlay(alignment: .topTrailing) {
                    if artist.featured {
                        Text("Featured")
                            .monoLabel(size: 8, tracking: 0.6, color: R.C.amber)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 7)
                            .background {
                                RoundedRectangle(cornerRadius: R.Rad.xs, style: .continuous)
                                    .fill(Color.black.opacity(0.4))
                            }
                            .padding(R.S.xs)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    AvailPill(availFor(artist.avail))
                        .padding(R.S.xs)
                }

            Text(artist.stage)
                .font(R.F.body(13, weight: .semibold))
                .foregroundStyle(R.C.fg1)
                .lineLimit(1)
            Text("\(artist.genre) · \(artist.city)")
                .font(R.F.mono(9, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(R.C.fg3)
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(R.C.amber)
                Text(String(format: "%.1f", artist.rating))
                    .font(R.F.mono(10, weight: .semibold))
                    .foregroundStyle(R.C.fg2)
            }
        }
        .padding(R.S.xs)
        .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
    }

    private func availFor(_ a: MockArtist.Avail) -> AvailPill.State {
        switch a {
        case .avail:  return .avail
        case .busy:   return .busy
        case .booked: return .booked
        }
    }
}

#if DEBUG
#Preview("RosterView") {
    let nav = NavigationModel()
    return RosterView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
