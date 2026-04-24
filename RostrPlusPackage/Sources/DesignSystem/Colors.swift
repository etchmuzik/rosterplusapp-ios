// Colors.swift
//
// Every color used in the ROSTR+ iOS app, translated from the `C` object
// at the top of the handoff's `ios-app.jsx`. Single source of truth —
// do not hardcode hex values in feature code.
//
// Defaults locked per the plan conversation:
//   • Primary CTAs use .fg1 (near-white), NOT gold.
//   • Gold (.amber) is reserved for pending/review/warning states only.
//   • Base bg is .bg0 (#08090b) matching the web brand — not the
//     slightly-darker #050608 from the JSX, which drifts without reason.

import SwiftUI

public enum R {
    public enum C {
        // MARK: Surfaces

        /// App background — the deepest layer. Everything sits on this.
        public static let bg0 = Color(hex: 0x08090b)

        /// A touch lighter than base. Used for structural dividers in rare
        /// cases; most surfaces should be a glass overlay over .bg0, not
        /// an opaque second tier. Kept for legacy parity with the JSX.
        public static let bg1 = Color(hex: 0x0a0b0e)

        /// Slightly lifted surface. Again, prefer glass overlays.
        public static let bg2 = Color(hex: 0x0f1114)

        // MARK: Glass overlays
        //
        // These are alpha-on-white, blended over .bg0 by the GlassSurface
        // modifier. Don't use them as raw solids.

        public static let glassLo     = Color.white.opacity(0.04)
        public static let glassMid    = Color.white.opacity(0.07)
        public static let glassHi     = Color.white.opacity(0.10)
        public static let borderHair  = Color.white.opacity(0.08)
        public static let borderSoft  = Color.white.opacity(0.06)
        public static let borderMid   = Color.white.opacity(0.12)

        // MARK: Foreground

        /// Primary text. Also the monochrome CTA fill.
        public static let fg1 = Color(white: 1.0, opacity: 0.96)

        /// Secondary text — labels, captions, subdued content.
        public static let fg2 = Color(white: 1.0, opacity: 0.62)

        /// Tertiary — metadata, timestamps, dimmed states.
        public static let fg3 = Color(white: 1.0, opacity: 0.38)

        // MARK: Status accents
        //
        // Used sparingly. Gold is NOT a primary; it's a warning/pending
        // accent. The JSX confirms this: every primary CTA renders with
        // fg1 on black, never gold.

        /// Pending, review prompts, "almost" states. Gold.
        public static let amber = Color(hex: 0xe9cf92)

        /// Confirmed, paid, available. Green.
        public static let green = Color(hex: 0x8ee6b5)

        /// Contracted, informational, "in progress". Muted blue.
        public static let blue  = Color(hex: 0xa6c5ea)

        /// Destructive, booked, overdue. Muted red.
        public static let red   = Color(hex: 0xf3a0a0)
    }
}

// MARK: Color(hex:) — convenience init
//
// SwiftUI's native Color(red:green:blue:) is 0…1 doubles which is
// readable for new code but noisy to translate from a palette already
// expressed in hex. This init does the 0xRRGGBB conversion inline so
// the palette file reads top-to-bottom like the JSX it came from.

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
