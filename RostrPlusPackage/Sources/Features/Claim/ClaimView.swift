// ClaimView.swift — Screen 19
//
// Artist claim-profile verification checklist. Port of `ClaimScreen`
// at ios-app.jsx line 1693.
//
// Three steps to unlock full booking privileges:
//   1. Verify email
//   2. Link a social profile (IG / SoundCloud / Spotify)
//   3. Add a payout method
//
// Each step is a card with a rounded-square glyph, status pill, and
// either a "Verify" button or a completed check. The progress bar at
// the top shows "N of 3 complete".

import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

public struct ClaimView: View {
    @Bindable var nav: NavigationModel

    // Local state for Wave 4; wires to Supabase + edge fns in prod.
    @State private var emailVerified = true
    @State private var socialLinked = false
    @State private var payoutAdded = false

    public init(nav: NavigationModel) {
        self.nav = nav
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Claim profile", onBack: { nav.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.lg) {
                    hero
                    progressCard
                    stepsStack
                    helpCard
                    Color.clear.frame(height: R.S.xxl)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.sm)
            }
        }
        .background(R.C.bg0)
    }

    // MARK: — Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Three quick checks")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text("Claim your profile to accept bookings.")
                .font(R.F.display(22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(R.C.fg1)
            Text("Takes about two minutes. Promoters see a verified badge on your roster card once you're done.")
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    // MARK: — Progress

    private var progressCard: some View {
        let steps = [emailVerified, socialLinked, payoutAdded]
        let done = steps.filter { $0 }.count
        return HStack(alignment: .center, spacing: R.S.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(done) of 3 complete")
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(done == 3 ? "Verified — you're all set." : "Keep going — \(3 - done) left.")
                    .monoLabel(size: 9.5, tracking: 0.5, color: R.C.fg3)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < done ? R.C.green : R.C.glassMid)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .strokeBorder(i < done ? R.C.green.opacity(0.4) : R.C.borderSoft, lineWidth: R.S.hairline)
                        }
                }
            }
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card, intensity: .soft)
    }

    // MARK: — Steps

    private var stepsStack: some View {
        VStack(spacing: R.S.sm) {
            StepCard(
                index: 1,
                glyph: "envelope",
                title: "Verify email",
                body: "We'll send a 6-digit code to hesham@beyondmngmt.ae.",
                isDone: emailVerified,
                ctaLabel: "Verified",
                action: {
                    withAnimation(R.M.easeOut) { emailVerified = true }
                }
            )
            StepCard(
                index: 2,
                glyph: "link",
                title: "Link a social profile",
                body: "Pick one: Instagram, SoundCloud, or Spotify. Promoters see these on your EPK.",
                isDone: socialLinked,
                ctaLabel: "Link",
                action: {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(R.M.easeOut) { socialLinked = true }
                }
            )
            StepCard(
                index: 3,
                glyph: "creditcard",
                title: "Add a payout method",
                body: "IBAN or card. Payments land directly after each event.",
                isDone: payoutAdded,
                ctaLabel: "Add",
                action: {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(R.M.easeOut) { payoutAdded = true }
                }
            )
        }
    }

    // MARK: — Help card

    private var helpCard: some View {
        HStack(alignment: .top, spacing: R.S.sm) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(R.C.fg2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Stuck on a step?")
                    .font(R.F.body(13, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text("Message support — we respond within a few hours.")
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg2)
            }
            Spacer()
        }
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

// MARK: - Step card

private struct StepCard: View {
    let index: Int
    let glyph: String
    let title: String
    let body: String
    let isDone: Bool
    let ctaLabel: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: R.S.md) {
            ZStack {
                RoundedRectangle(cornerRadius: R.Rad.md, style: .continuous)
                    .fill(isDone ? R.C.green.opacity(0.14) : R.C.glassMid)
                Image(systemName: isDone ? "checkmark" : glyph)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isDone ? R.C.green : R.C.fg1)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: R.S.xs) {
                    Text("Step \(index)")
                        .monoLabel(size: 8.5, tracking: 0.6, color: R.C.fg3)
                    if isDone {
                        Text("Done")
                            .monoLabel(size: 8.5, tracking: 0.6, color: R.C.green)
                    }
                }
                Text(title)
                    .font(R.F.body(14, weight: .semibold))
                    .foregroundStyle(R.C.fg1)
                Text(body)
                    .font(R.F.body(12, weight: .regular))
                    .foregroundStyle(R.C.fg3)
                    .lineSpacing(2)

                if !isDone {
                    Button(action: action) {
                        Text(ctaLabel)
                            .font(R.F.mono(10, weight: .bold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(R.C.bg0)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                            .background { Capsule().fill(R.C.fg1) }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.card)
    }
}

#if DEBUG
#Preview("ClaimView") {
    let nav = NavigationModel()
    return ClaimView(nav: nav)
        .preferredColorScheme(.dark)
}
#endif
