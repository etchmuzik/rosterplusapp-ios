// OnboardView.swift — Screen 01
//
// First-run carousel + role pick. Port of `OnboardScreen` at
// ios-app.jsx line 722.
//
// Flow (per plan): OnboardView → SignInView → HomeView. A UserDefaults
// flag `rostr.onboardCompleted` gates whether OnboardView ever shows
// again. The plan locked "first launch only, role picked here, then
// SignIn".
//
// Layout: paging TabView with 3 slides, final slide is the role picker.
// Dots indicator + Skip in top-right.

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct OnboardView: View {
    @Bindable var nav: NavigationModel
    @State private var page: Int = 0
    @State private var chosenRole: Role = .promoter

    /// Fired when onboarding is complete — set from the parent if it
    /// wants to persist a UserDefaults flag + route into SignIn. The
    /// default behaviour here just pushes .signIn.
    var onComplete: ((Role) -> Void)?

    public init(nav: NavigationModel, onComplete: ((Role) -> Void)? = nil) {
        self.nav = nav
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack(alignment: .top) {
            R.C.bg0.ignoresSafeArea()

            TabView(selection: $page) {
                slide1.tag(0)
                slide2.tag(1)
                roleSlide.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            topBar

            dots
                .padding(.bottom, 120)
                .frame(maxHeight: .infinity, alignment: .bottom)

            footer
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: — Top bar

    private var topBar: some View {
        HStack {
            Text("ROSTR+")
                .font(R.F.display(16, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(R.C.fg1)
            Spacer()
            if page < 2 {
                Button {
                    withAnimation(R.M.easeOut) { page = 2 }
                } label: {
                    Text("Skip")
                        .monoLabel(size: 10, tracking: 0.6, color: R.C.fg2)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 12)
                        .background { Capsule().fill(R.C.glassLo) }
                        .overlay { Capsule().strokeBorder(R.C.borderSoft, lineWidth: R.S.hairline) }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, R.S.lg)
        .padding(.top, R.S.xs)
    }

    // MARK: — Slides

    private var slide1: some View {
        Slide(
            eyebrow: "Tonight, not someday",
            headline: "Book the GCC's\nloudest nights.",
            body: "Thousands of artists across Dubai, Riyadh, Abu Dhabi, Doha, and Jeddah — one roster.",
            illustration: {
                GradientPanel(seed: "slide1", tall: true)
            }
        )
    }

    private var slide2: some View {
        Slide(
            eyebrow: "Contracts + payments, built-in",
            headline: "No more\nWhatsApp math.",
            body: "E-sign, invoice, pay. Your whole season lives in one place — with audit logs promoters and artists can trust.",
            illustration: {
                GradientPanel(seed: "slide2", tall: false)
            }
        )
    }

    private var roleSlide: some View {
        VStack(alignment: .leading, spacing: R.S.xl) {
            Spacer(minLength: 60)
            VStack(alignment: .leading, spacing: 8) {
                Text("Final step")
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
                Text("You're here as…")
                    .font(R.F.display(30, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(R.C.fg1)
                Text("You can switch at any time from Home.")
                    .font(R.F.body(13, weight: .regular))
                    .foregroundStyle(R.C.fg2)
            }

            VStack(spacing: R.S.sm) {
                roleCard(
                    role: .promoter,
                    title: "A promoter",
                    body: "I book artists for venues, events, or a brand.",
                    glyph: "megaphone.fill"
                )
                roleCard(
                    role: .artist,
                    title: "An artist",
                    body: "I perform — DJ, live act, or headliner.",
                    glyph: "music.mic"
                )
            }
            Spacer()
        }
        .padding(.horizontal, R.S.lg)
        .padding(.bottom, 160)
    }

    private func roleCard(role: Role, title: String, body: String, glyph: String) -> some View {
        let isSelected = chosenRole == role
        return Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            withAnimation(R.M.easeOutFast) { chosenRole = role }
        } label: {
            HStack(alignment: .top, spacing: R.S.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                        .fill(isSelected ? R.C.fg1 : R.C.glassMid)
                    Image(systemName: glyph)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? R.C.bg0 : R.C.fg1)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(R.F.body(15, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text(body)
                        .font(R.F.body(12.5, weight: .regular))
                        .foregroundStyle(R.C.fg2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                }
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.card)
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.card, style: .continuous)
                    .strokeBorder(isSelected ? R.C.fg1.opacity(0.35) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: — Dots + footer

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(i == page ? R.C.fg1 : R.C.glassMid)
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(R.M.easeOutFast, value: page)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            PrimaryButton(
                page == 2 ? "Continue" : "Next",
                variant: .filled
            ) {
                if page == 2 {
                    nav.setRole(chosenRole)
                    if let onComplete = onComplete {
                        onComplete(chosenRole)
                    } else {
                        nav.push(.signIn)
                    }
                } else {
                    withAnimation(R.M.easeOut) { page += 1 }
                }
            }
            .padding(.horizontal, R.S.lg)
            .padding(.bottom, R.S.xl)
        }
        .background {
            LinearGradient(
                colors: [R.C.bg0.opacity(0), R.C.bg0.opacity(0.95), R.C.bg0],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Slide

private struct Slide<Illustration: View>: View {
    let eyebrow: String
    let headline: String
    let body: String
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        VStack(alignment: .leading, spacing: R.S.xl) {
            Spacer(minLength: 60)
            illustration()
                .frame(height: 280)
                .padding(.horizontal, R.S.lg)
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow)
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.amber)
                Text(headline)
                    .font(R.F.display(34, weight: .bold))
                    .tracking(-1.0)
                    .foregroundStyle(R.C.fg1)
                Text(body)
                    .font(R.F.body(14, weight: .regular))
                    .foregroundStyle(R.C.fg2)
                    .lineSpacing(3)
            }
            .padding(.horizontal, R.S.lg)
            Spacer(minLength: 160)
        }
    }
}

// MARK: - Gradient panel illustration

private struct GradientPanel: View {
    let seed: String
    let tall: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Cover(seed: seed, size: nil, cornerRadius: R.Rad.card3)
                // Overlay some mock "glass cards" to evoke the app's
                // actual surfaces.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        glassRect(w: geo.size.width * 0.55, h: 52)
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        Spacer()
                        glassRect(w: geo.size.width * 0.6, h: 40)
                    }
                    glassRect(w: geo.size.width * 0.8, h: 44)
                    Spacer()
                }
                .padding(R.S.lg)
            }
        }
    }

    private func glassRect(w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
            .fill(R.C.glassMid)
            .overlay {
                RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                    .strokeBorder(R.C.borderHair, lineWidth: R.S.hairline)
            }
            .frame(width: w, height: h)
    }
}

#if DEBUG
#Preview("OnboardView") {
    let nav = NavigationModel()
    return OnboardView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
