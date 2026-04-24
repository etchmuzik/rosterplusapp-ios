// Cover.swift
//
// Deterministic monochrome gradient avatar, seeded from a string (usually
// the artist's stage name). Matches the JSX `<Cover>` component at
// ios-app.jsx line 90 — same hash function, same HSL ranges, same
// radial highlight overlay.
//
// Used everywhere an artist needs a placeholder before they've uploaded
// their real avatar. In production we'll show `artist.avatar_url` when
// it's set and fall back to this.

import SwiftUI
import DesignSystem

public struct Cover: View {
    let seed: String
    let size: CGFloat?
    let cornerRadius: CGFloat

    /// Seeded gradient tile. Pass `size: nil` to let the caller control
    /// sizing via `.frame(...)` — used by RosterView's 2-column grid
    /// which wants a fluid-width square.
    public init(seed: String, size: CGFloat? = 44, cornerRadius: CGFloat = R.Rad.md) {
        self.seed = seed
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let (h1, h2, l1, l2) = hash(seed: seed)
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: h1 / 360, saturation: 0.08, brightness: l1 / 100),
                        Color(hue: h2 / 360, saturation: 0.10, brightness: l2 / 100)
                    ],
                    startPoint: UnitPoint(x: 0.15, y: 0.0),
                    endPoint: UnitPoint(x: 0.85, y: 1.0)
                )
            )
            .overlay {
                // Subtle top-left highlight — same effect as the JSX's
                // radial-gradient(circle at 30% 20%, rgba(255,255,255,0.10), transparent 60%).
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.0)
                            ],
                            center: UnitPoint(x: 0.3, y: 0.2),
                            startRadius: 0,
                            // Fallback radius when size is nil (caller-driven frame).
                            // 120 matches the largest common cover size on EPK.
                            endRadius: (size ?? 120) * 0.6
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(R.C.borderHair, lineWidth: R.S.hairline)
            }
            .frame(width: size, height: size)
            // When size == nil, consumer drives the frame.
    }

    // MARK: Hash

    /// Port of the JSX's `split('').reduce((a,c)=>a+c.charCodeAt(0), 0)`.
    /// Returns four doubles in the same numeric ranges as the original
    /// (h1: 215–234, h2: 210–239, l1: 6–11, l2: 18–31).
    private func hash(seed: String) -> (Double, Double, Double, Double) {
        let sum = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let h1 = Double(215 + (sum % 20))
        let h2 = Double(210 + ((sum * 3) % 30))
        let l1 = Double(6 + (sum % 6))
        let l2 = Double(18 + ((sum * 7) % 14))
        return (h1, h2, l1, l2)
    }
}

#if DEBUG
#Preview("Cover — three sizes") {
    HStack(spacing: R.S.lg) {
        Cover(seed: "DJ NOVAK", size: 44)
        Cover(seed: "ORION KAI", size: 72, cornerRadius: 14)
        Cover(seed: "KARIMA-N", size: 120, cornerRadius: 20)
    }
    .padding()
    .background(R.C.bg0)
    .preferredColorScheme(.dark)
}
#endif
