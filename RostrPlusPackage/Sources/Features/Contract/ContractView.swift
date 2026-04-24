// ContractView.swift — Screen 09
//
// E-signable contract view. Port of `ContractScreen` at ios-app.jsx
// line 959. Layout:
//
//   NavHeader("Contract")
//   Title card      — event + artist + contract number
//   Body            — long-form terms (rider, cancellation, payment)
//   Signature panel — dashed outline, "Awaiting signature" until tapped
//   CTAs            — Decline (ghost destructive) + Sign contract (filled)

import SwiftUI
import DesignSystem

public struct ContractView: View {
    @Bindable var nav: NavigationModel
    let contractID: String
    @State private var signed: Bool = false

    public init(nav: NavigationModel, contractID: String) {
        self.nav = nav
        self.contractID = contractID
    }

    public var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Contract", onBack: { nav.pop() })
            ScrollView {
                VStack(alignment: .leading, spacing: R.S.lg) {
                    header
                    body_
                    signature
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, R.S.lg)
                .padding(.top, R.S.sm)
            }
            actions
        }
        .background(R.C.bg0)
    }

    // MARK: — Title card

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Performance agreement")
                .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
            Text("DJ NOVAK at WHITE Dubai")
                .font(R.F.display(24, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(R.C.fg1)
            Text("Contract #RP-2026-0124")
                .font(R.F.mono(10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(R.C.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.lg)
        .glassSurface(cornerRadius: R.Rad.card3)
    }

    // MARK: — Body

    private var body_: some View {
        VStack(alignment: .leading, spacing: R.S.md) {
            Clause(
                title: "1. Engagement",
                text: "The Artist (DJ NOVAK) agrees to perform a 4-hour DJ set on Tuesday, 24 April 2026 at WHITE Dubai. Call time 22:30. Performance 23:00–03:00."
            )
            Clause(
                title: "2. Fee",
                text: "Total fee is AED 28,000, inclusive of the Artist's agent commission. Payable within 7 days of performance via bank transfer."
            )
            Clause(
                title: "3. Rider",
                text: "Technical and hospitality rider attached as Schedule A. The Promoter confirms that all requirements will be in place by 22:00 on performance day."
            )
            Clause(
                title: "4. Cancellation",
                text: "Cancellation by either party within 14 days of the event forfeits 50% of the fee. Within 72 hours, 100%. Force majeure excepted."
            )
            Clause(
                title: "5. Governing law",
                text: "This agreement is governed by the laws of the Dubai International Financial Centre."
            )
        }
    }

    // MARK: — Signature panel

    @ViewBuilder
    private var signature: some View {
        if signed {
            // Signed-state — solid glass with green dot.
            HStack(spacing: R.S.sm) {
                Circle().fill(R.C.green).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed by Hesham · Promoter")
                        .font(R.F.body(13, weight: .semibold))
                        .foregroundStyle(R.C.fg1)
                    Text("24 Apr 2026 · 14:22 GST")
                        .monoLabel(size: 9, tracking: 0.5, color: R.C.fg3)
                }
                Spacer()
            }
            .padding(R.S.md)
            .glassSurface(cornerRadius: R.Rad.button2)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Signature")
                    .monoLabel(size: 9.5, tracking: 0.8, color: R.C.fg3)
                Text("Awaiting signature")
                    .font(R.F.body(13, weight: .medium))
                    .foregroundStyle(R.C.amber)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(R.S.md)
            .background {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                    .foregroundStyle(R.C.amber.opacity(0.4))
            }
            .background {
                RoundedRectangle(cornerRadius: R.Rad.button2, style: .continuous)
                    .fill(R.C.amber.opacity(0.04))
            }
        }
    }

    // MARK: — Actions

    private var actions: some View {
        HStack(spacing: R.S.sm) {
            PrimaryButton("Decline", variant: .destructive) {
                nav.pop()
            }
            PrimaryButton(
                signed ? "Signed" : "Sign contract",
                variant: .filled,
                isEnabled: !signed
            ) {
                withAnimation(R.M.easeOut) { signed = true }
            }
            .layoutPriority(1)
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
}

// MARK: - Clause

private struct Clause: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(R.F.body(13, weight: .semibold))
                .foregroundStyle(R.C.fg1)
            Text(text)
                .font(R.F.body(13, weight: .regular))
                .foregroundStyle(R.C.fg2)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(R.S.md)
        .glassSurface(cornerRadius: R.Rad.button2, intensity: .soft)
    }
}

#if DEBUG
#Preview("ContractView") {
    let nav = NavigationModel()
    return ContractView(nav: nav, contractID: "demo")
        .preferredColorScheme(.dark)
}
#endif
