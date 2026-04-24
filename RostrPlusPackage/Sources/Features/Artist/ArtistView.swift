// ArtistView.swift — Screen 04
//
// Public artist profile. Port of `ArtistScreen` at ios-app.jsx line 396.
// Structure top → bottom:
//
//   Header:       NavHeader("Back")
//   Cover hero:   160pt gradient with stage name + genre + city overlay
//   Facts row:    rating · base fee · response time · avail pill
//   Bio:          3-line blurb
//   Availability: 7-day strip of dots/circles (avail/busy/booked)
//   Recent sets:  2-row list (venue · date)
//   Sticky CTAs:  Message (ghost) · Request booking (filled)

import SwiftUI
import DesignSystem

public struct ArtistView: View {
    @Bindable var nav: NavigationModel
    let artist: MockArtist

    public init(nav: NavigationModel, artist: MockArtist) {
        self.nav = nav
        self.artist = artist
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Profile", onBack: { nav.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.xl) {
                    coverHero
                        .padding(.horizontal, R.S.lg)
                        .padding(.top, R.S.sm)
                    factsRow
                        .padding(.horizontal, R.S.lg)
                    bioCard
                        .padding(.horizontal, R.S.lg)
                    availabilityStrip
                        .padding(.horizontal, R.S.lg)
                    recentSets
                        .padding(.horizontal, R.S.lg)
                    Color.clear.frame(height: 120) // sticky CTA clearance
                }
            }
            stickyCTAs
        }
        .background(R.C.bg0)
    }

    // MARK: — Cover hero

    private var coverHero: some View {
        Cover(seed: artist.stage, size: nil, cornerRadius: R.Rad.card3)
            .frame(height: 220)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.stage)
                        .font(R.F.display(34, weight: .bold))
                        .tracking(-1.2)
                        .foregroundStyle(R.C.fg1)
                    Text("\(artist.genre) · \(artist.city)")
                        .font(R.F.body(13, weight: .medium))
                        .foregroundStyle(R.C.fg2)
                }
                .padding(R.S.lg)
            }
            .overlay(alignment: .topTrailing) {
                AvailPill(availFor(artist.avail))
                    .padding(R.S.md)
            }
    }

    // MARK: — Facts row

    private var factsRow: some View {
        HStack(spacing: R.S.sm) {
            Fact(label: "Rating",   value: String(format: "%.1f", artist.rating), icon: "star.fill", iconColor: R.C.amber)
            Fact(label: "Base fee", value: "AED 28K", icon: nil)
            Fact(label: "Reply",    value: "~2h", icon: nil)
        }
    }

    // MARK: — Bio card

    private var bioCard: some View {
        VStack(alignment: .leading, spacing: R.S.xs) {
            Text("About")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text("Tech-leaning house selector with residencies in Dubai + Riyadh. Known for long build-up sets and a rider that arrives on time.")
                .font(R.F.body(14, weight: .regular))
                .foregroundStyle(R.C.fg1.opacity(0.86))
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }

    // MARK: — Availability strip

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
        // Deterministic mock pattern — first two days busy, rest varied.
        switch i {
        case 0: return (R.C.green, "FREE")
        case 1: return (R.C.red,   "BOOKED")
        case 2: return (R.C.green, "FREE")
        case 3: return (R.C.amber, "TIGHT")
        case 4: return (R.C.red,   "BOOKED")
        case 5: return (R.C.green, "FREE")
        default: return (R.C.green, "FREE")
        }
    }

    // MARK: — Recent sets

    private var recentSets: some View {
        VStack(alignment: .leading, spacing: R.S.sm) {
            Text("Recent sets")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            VStack(spacing: R.S.xs) {
                SetRow(venue: "WHITE Dubai",  date: "12 Apr · 02:00–04:00")
                SetRow(venue: "Blu Dahlia",   date: "05 Apr · 23:30–02:00")
                SetRow(venue: "Cavalli Club", date: "28 Mar · 01:00–03:30")
            }
        }
    }

    // MARK: — Sticky CTAs

    private var stickyCTAs: some View {
        HStack(spacing: R.S.sm) {
            PrimaryButton("Message", variant: .ghost) {
                nav.push(.thread(threadID: String(artist.id)))
            }
            PrimaryButton("Request booking", variant: .filled) {
                nav.push(.booking(artistID: String(artist.id)))
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

    private func availFor(_ a: MockArtist.Avail) -> AvailPill.State {
        switch a {
        case .avail: return .avail
        case .busy: return .busy
        case .booked: return .booked
        }
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
    return ArtistView(nav: nav, artist: MockData.artists[0])
        .preferredColorScheme(.dark)
}
#endif
