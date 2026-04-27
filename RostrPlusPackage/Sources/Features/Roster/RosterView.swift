// RosterView.swift — Screen 03
//
// Browse artists with search + genre filter chips. Mirrors `RosterScreen`
// at ios-app.jsx line 306.
//
// Track 2 update: backed by RosterStore. When the store hasn't loaded
// yet (first launch) we show a skeleton list of glass cards. Failures
// surface an inline retry banner. Mock data only seeds the preview.

import SwiftUI
import DesignSystem

public struct RosterView: View {
    @Bindable var nav: NavigationModel
    @Environment(RosterStore.self) private var store

    /// Drives the invite-artist sheet. Promoter-only; gated below.
    @State private var showingInvite = false

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        let bindable = Bindable(store)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchField(store: bindable)
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.md)
                filterChips(store: bindable)
                    .padding(.top, R.S.md)
                content
                    .padding(.horizontal, R.S.lg)
                    .padding(.top, R.S.lg)
                Color.clear.frame(height: 100) // tab-bar clearance
            }
        }
        .refreshable { store.refresh() }
        .background(R.C.bg0)
        .onAppear {
            if case .idle = store.state { store.refresh() }
        }
        .sheet(isPresented: $showingInvite) {
            InviteSheet()
        }
    }

    // MARK: — Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Roster")
                    .font(R.F.display(30, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(R.C.fg1)
                Text(headerSubtitle)
                    .monoLabel(size: 10, tracking: 0.6, color: R.C.fg3)
            }
            Spacer()
            // Promoter-only — artists don't issue invites today.
            // (Server-side RLS doesn't restrict, but the UX makes
            // sense only for the booking side of the marketplace.)
            if nav.role == .promoter {
                inviteButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, R.S.lg)
        .padding(.top, R.S.sm)
    }

    private var inviteButton: some View {
        Button {
            showingInvite = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Invite")
                    .font(R.F.mono(10, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
            }
            .foregroundStyle(R.C.fg1)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background {
                Capsule().fill(R.C.glassLo)
            }
            .overlay {
                Capsule().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invite an artist")
    }

    private var headerSubtitle: String {
        switch store.state {
        case .idle, .loading: return "Loading live roster…"
        case .failed:         return "Couldn't load roster"
        case .loaded:         return "\(store.visible.count) artists · live roster"
        }
    }

    // MARK: — Search

    private func searchField(store: Bindable<RosterStore>) -> some View {
        HStack(spacing: R.S.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(R.C.fg3)
            TextField(
                "",
                text: store.search,
                prompt: Text("Search artists").foregroundStyle(R.C.fg3)
            )
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

    private func filterChips(store: Bindable<RosterStore>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: R.S.xs) {
                ForEach(store.wrappedValue.genres, id: \.self) { g in
                    Chip(label: g, isActive: store.wrappedValue.genreFilter == g) {
                        store.wrappedValue.genreFilter = g
                    }
                }
            }
            .padding(.horizontal, R.S.lg)
        }
    }

    // MARK: — Content

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            SkeletonGrid()
        case .failed(let message):
            FailureCard(message: message) { store.refresh() }
        case .loaded:
            grid
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: R.S.sm),
            GridItem(.flexible(), spacing: R.S.sm)
        ], spacing: R.S.sm) {
            ForEach(store.visible) { artist in
                Button {
                    nav.push(.artist(artistID: artist.id.uuidString))
                } label: {
                    ArtistCard(artist: artist)
                }
                .buttonStyle(.plain)
            }
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

// MARK: - Artist card (live)

private struct ArtistCard: View {
    let artist: RosterArtist

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Cover(seed: artist.stage, size: nil, cornerRadius: R.Rad.button2)
                .frame(height: 140)
                .overlay(alignment: .topTrailing) {
                    if artist.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(R.C.amber)
                            .padding(6)
                            .background {
                                Circle().fill(Color.black.opacity(0.4))
                            }
                            .padding(R.S.xs)
                    }
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
        }
        .padding(R.S.xs)
        .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
    }
}

// MARK: - Skeleton grid

private struct SkeletonGrid: View {
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: R.S.sm),
            GridItem(.flexible(), spacing: R.S.sm)
        ], spacing: R.S.sm) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: R.S.xs) {
                    RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                        .fill(R.C.glassLo)
                        .frame(height: 140)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(R.C.glassLo)
                        .frame(height: 14)
                        .padding(.trailing, 40)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(R.C.glassLo)
                        .frame(height: 10)
                        .padding(.trailing, 80)
                }
                .padding(R.S.xs)
                .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
                .redacted(reason: .placeholder)
            }
        }
    }
}

// MARK: - Failure card

private struct FailureCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            HStack(spacing: R.S.sm) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(R.C.red)
                Text("Couldn't load the roster")
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
            }
            Text(message)
                .font(R.F.body(12, weight: .regular))
                .foregroundStyle(R.C.fg3)
                .lineLimit(3)
            PrimaryButton("Try again", variant: .ghost) {
                retry()
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }
}

#if DEBUG
#Preview("RosterView") {
    let nav = NavigationModel()
    let store = RosterStore()
    return RosterView(nav: nav)
        .environment(store)
        .preferredColorScheme(.dark)
}
#endif
