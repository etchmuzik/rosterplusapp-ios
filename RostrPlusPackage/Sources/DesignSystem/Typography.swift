// Typography.swift
//
// Three font families power every piece of text in ROSTR+:
//   • Chillax   — display, hero numbers, headings. Aggressive negative tracking.
//   • Satoshi   — body copy, default sans.
//   • JetBrains Mono — all metadata, timestamps, prices, labels.
//
// The mono font is load-bearing. Using body type for a price or a
// timestamp breaks the rhythm of the whole design system. Don't do it.
//
// Font files are bundled in Sources/DesignSystem/Fonts/ and registered
// at package-load time via the static initialiser below. If the files
// haven't been added yet, Font.custom falls back gracefully — previews
// will render in SF Pro but the app won't crash.
//
// Dynamic Type policy (per plan):
//   • Body + mono scale up to .accessibility1 then cap.
//   • Display stays fixed — Chillax's tight tracking breaks visually
//     when scaled past ~1.3×, so we let it opt out of scaling and
//     instead surface the same info via a scaled-body alternative
//     (or just trust the layout to wrap).

// R is declared in Colors.swift. This file only adds the R.F namespace.
import SwiftUI
import CoreText
import OSLog

private let log = Logger(subsystem: "io.rosterplus.app", category: "DesignSystem.Typography")

public extension R {
    enum F {

        // MARK: Family names
        //
        // These are the PostScript names the font files register under
        // after CTFontManager ingests them. If a .otf is swapped for a
        // variable .woff2, re-check these in Font Book.

        public static let displayFamily = "Chillax"
        public static let bodyFamily    = "Satoshi"
        public static let monoFamily    = "JetBrainsMono"

        // MARK: Display — Chillax
        //
        // Tracking values in the design system range from -0.5 to -1.4,
        // expressed here as kerning points (since SwiftUI .tracking() is
        // absolute, not a percentage). Applied per-size on the call site.

        public static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .custom(displayFamily, size: size).weight(weight)
        }

        public static func displayFixed(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            // For hero numbers and big headings that should NOT scale with
            // Dynamic Type (caps protect the aesthetic per plan).
            .custom(displayFamily, fixedSize: size).weight(weight)
        }

        // MARK: Body — Satoshi

        public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(bodyFamily, size: size, relativeTo: .body).weight(weight)
        }

        // MARK: Mono — JetBrains Mono
        //
        // The JetBrains Mono static TTFs register as four separate
        // PostScript families (JetBrainsMono-Regular, -Medium,
        // -SemiBold, -Bold) rather than one family with weight
        // variants. Core Text then can't resolve .weight(.medium) on
        // the base "JetBrainsMono" family. We bypass that by picking
        // the full PostScript name directly per weight.
        //
        // Paired with .tracking() at the call site; most mono labels also
        // set .textCase(.uppercase). Helper builder below handles both.

        public static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .custom(monoPostScriptName(for: weight), size: size, relativeTo: .caption)
        }

        public static func monoFixed(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .custom(monoPostScriptName(for: weight), fixedSize: size)
        }

        /// Pick the JetBrains Mono file whose PostScript name matches
        /// the requested weight. Anything outside our bundled set falls
        /// back to Regular.
        private static func monoPostScriptName(for weight: Font.Weight) -> String {
            switch weight {
            case .bold, .heavy, .black: return "JetBrainsMono-Bold"
            case .semibold:             return "JetBrainsMono-SemiBold"
            case .medium:               return "JetBrainsMono-Medium"
            default:                    return "JetBrainsMono-Regular"
            }
        }
    }
}

// MARK: Monolabel view modifier
//
// Almost every metadata string in the app wants the same treatment:
// uppercase + tracking + mono + fg tertiary. This modifier packages
// those so feature code stays terse.

public struct MonoLabelStyle: ViewModifier {
    let size: CGFloat
    let tracking: CGFloat
    let color: Color

    public func body(content: Content) -> some View {
        content
            .font(R.F.mono(size, weight: .semibold))
            .tracking(tracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

public extension View {
    /// Default mono-label treatment (9pt, .tracking(0.6), .fg3).
    /// Matches the `MONO fontSize:9 letterSpacing:0.6` pattern used
    /// repeatedly in ios-app.jsx for pill labels, tab bar text, etc.
    func monoLabel(
        size: CGFloat = 9,
        tracking: CGFloat = 0.6,
        color: Color = R.C.fg3
    ) -> some View {
        modifier(MonoLabelStyle(size: size, tracking: tracking, color: color))
    }
}

// MARK: Font registration
//
// SPM resources are copied into the package bundle but not automatically
// registered with the Font Manager. Call R.F.registerBundledFonts() once
// at app launch (RostrPlusApp's init) to wire them in.

public extension R.F {
    /// Call once at app launch. Safe to call multiple times — CoreText
    /// deduplicates by file hash internally.
    static func registerBundledFonts() {
        let bundle = Bundle.module
        // We ship .otf files for Chillax + Satoshi and .ttf for JetBrains Mono.
        // List them here so a font that's missing surfaces as a warning rather
        // than a silent fallback at runtime.
        let families: [(family: String, weights: [String], ext: String)] = [
            ("Chillax", ["Regular", "Medium", "Semibold", "Bold"], "otf"),
            ("Satoshi", ["Regular", "Medium", "Bold"], "otf"),
            ("JetBrainsMono", ["Regular", "Medium", "SemiBold", "Bold"], "ttf")
        ]

        for fam in families {
            for weight in fam.weights {
                let name = "\(fam.family)-\(weight)"
                guard let url = bundle.url(forResource: name, withExtension: fam.ext) else {
                    log.warning("Missing font file: \(name, privacy: .public).\(fam.ext, privacy: .public)")
                    continue
                }
                var errorRef: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef)
                // Already-registered errors are expected on re-entry; ignore.
            }
        }
    }
}
