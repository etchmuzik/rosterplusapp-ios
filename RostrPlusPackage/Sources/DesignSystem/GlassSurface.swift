// GlassSurface.swift
//
// The ROSTR+ visual signature. Every card, every pill, every floating
// bar goes through this modifier. Matches the JSX `glass()` helper:
//
//   background: rgba(20,22,26,0.55)
//   backdropFilter: blur(24px) saturate(1.4)
//   border: 0.5px solid rgba(255,255,255,0.08)
//
// SwiftUI equivalents:
//   • Background tint  → .fill(Color.white.opacity(0.04)) over .ultraThinMaterial
//   • Backdrop blur    → .background(.ultraThinMaterial)  (auto-handled by Apple)
//   • Hairline border  → .strokeBorder with 0.5px line
//   • Inner highlight  → LinearGradient from white-6% to clear at top edge
//
// Flat cards break the aesthetic. Always use this modifier — never
// replace with an opaque background color + border.

import SwiftUI

public struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: Intensity
    let showsInnerHighlight: Bool

    public enum Intensity {
        /// Subtle — for inline cards that live inside another glass surface.
        case soft
        /// Default — freestanding cards, detail rows.
        case regular
        /// Strong — floating bars (tab bar, modal chrome).
        case strong
    }

    public init(
        cornerRadius: CGFloat = R.Rad.card,
        intensity: Intensity = .regular,
        showsInnerHighlight: Bool = true
    ) {
        self.cornerRadius = cornerRadius
        self.intensity = intensity
        self.showsInnerHighlight = showsInnerHighlight
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let (material, tint): (Material, Color) = materialFor(intensity)

        content
            .background {
                // Layer 1: Apple's ultra-thin material handles the actual
                // backdrop blur. We don't get explicit blur-radius control
                // like CSS gives us, but .ultraThinMaterial at intensity
                // `regular` matches blur(18–24px) closely enough in practice.
                shape.fill(material)
            }
            .background {
                // Layer 2: the cold-white tint (rgba(255,255,255,0.04) etc)
                // blended over the material. Without this layer the material
                // reads too neutral and loses the slight-warm look.
                shape.fill(tint)
            }
            .overlay {
                // Hairline border. 0.5px on retina = 1 physical pixel, which
                // is what the designer actually drew in the JSX.
                shape.strokeBorder(R.C.borderHair, lineWidth: R.S.hairline)
            }
            .overlay {
                // Inner highlight — a faint top-edge gradient that sells
                // the "slightly lifted" quality. Opt out via init param for
                // surfaces where the highlight reads as noise (e.g. inline
                // stat pills smaller than 32pt tall).
                if showsInnerHighlight {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.00)
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .blendMode(.overlay)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(shape)
    }

    private func materialFor(_ i: Intensity) -> (Material, Color) {
        switch i {
        case .soft:
            return (.thinMaterial, R.C.glassLo)
        case .regular:
            return (.ultraThinMaterial, R.C.glassLo)
        case .strong:
            return (.ultraThinMaterial, R.C.glassMid)
        }
    }
}

public extension View {
    /// Apply the ROSTR+ glass treatment. Default is a card-radius regular
    /// surface with inner highlight — i.e. what 80% of cards want.
    func glassSurface(
        cornerRadius: CGFloat = R.Rad.card,
        intensity: GlassSurface.Intensity = .regular,
        showsInnerHighlight: Bool = true
    ) -> some View {
        modifier(GlassSurface(
            cornerRadius: cornerRadius,
            intensity: intensity,
            showsInnerHighlight: showsInnerHighlight
        ))
    }
}
