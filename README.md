# ROSTR+ iOS

Native iOS app for [ROSTR+ GCC](https://rosterplus.io) — the Gulf region's artist booking platform.

Companion to the web repo at [etchmuzik/rosterplusapp](https://github.com/etchmuzik/rosterplusapp). Same Supabase backend, same brand, different surface.

## Status

**Wave 1 (foundation)** — in progress.

- [x] Workspace + SPM package scaffolding
- [x] Design system (colors, typography, spacing, radii, motion, glass)
- [x] Component primitives (Cover, AvailPill, StatusTag, icons, TabBar)
- [x] NavigationModel (port of the InteractiveDevice nav from the handoff)
- [x] HomeScreen (promoter) — one screen end-to-end to validate the foundation
- [x] Supabase client wired to the same project as web
- [x] Tests for the design system + navigation
- [ ] Wave 2 — core promoter loop (Roster, Artist, Booking wizard, Bookings, Contract, Inbox, Payments)
- [ ] Wave 3 — artist side (Dashboard, Availability, Edit Profile, EPK, Calendar)
- [ ] Wave 4 — surrounding flows (Notifications, Review, Analytics, Claim, Settings)
- [ ] Wave 5 — auth (Onboarding, Sign in)

All 23 screens from the design handoff will ship across these waves.

## Stack

- **iOS 17+** with SwiftUI, Swift 6 strict concurrency
- **@Observable** for view state (not @ObservableObject)
- **Swift Package Manager** — all feature code lives in `RostrPlusPackage/`; the Xcode app target is a thin `@main` wrapper
- **Supabase Swift SDK** for data, realtime, storage
- **Swift Testing** (`@Test`, `#expect`) — not XCTest

## Repository layout

```
rosterplusapp-ios/
├── Config/                         # xcconfig + entitlements
├── RostrPlus/                      # Thin Xcode app shell — @main only
├── RostrPlusPackage/               # Everything else
│   ├── Sources/
│   │   ├── DesignSystem/           # Colors, Typography, Spacing, GlassSurface
│   │   ├── AppCore/                # NavigationModel, Route, AppRoot
│   │   ├── Components/             # Cover, AvailPill, StatusTag, TabBar, Icons
│   │   ├── Stores/                 # @Observable stores + MockData
│   │   ├── SupabaseClient/         # Supabase wrapper + DTOs + RPC wrappers
│   │   └── Features/<Screen>/      # One folder per screen (23 total)
│   └── Tests/                      # Swift Testing
├── RostrPlusUITests/               # UI automation via XCUITest (Wave 2+)
└── README.md
```

## Design system rules

These are non-negotiable (per the design handoff):

1. **Primary CTAs are near-white `#f3f5f8` on black.** Gold `#e9cf92` is reserved for pending states + the review prompt banner. Don't make buttons gold.
2. **Every card is a glass surface.** Flat opaque cards break the visual signature. Use `.glassSurface()` — it wraps `.ultraThinMaterial` with the white-tint + hairline-border + inner-highlight stack.
3. **Chillax + Satoshi + JetBrains Mono are load-bearing.** Bundle the font files under `Sources/DesignSystem/Fonts/` (see the README there for exact names). Don't fall back to SF Pro.
4. **Monochrome everywhere except pending/paid/available dots.** The amber/green/blue/red status colours appear only on pills and status tags, never as fills for CTAs.
5. **Mono font for all metadata.** Timestamps, prices, labels, status strings.

## Running locally

```bash
# Open the workspace
open RostrPlus.xcworkspace

# Or from the SPM package directly — fast iteration on DesignSystem + previews
cd RostrPlusPackage && swift package resolve
```

Xcode previews work for every `View` that has a `#Preview` block. HomeView has one — the foundation screen.

## Testing

```bash
swift test --package-path RostrPlusPackage
# or in Xcode, ⌘U
```

Tests cover the design-system tokens (scale monotonicity, locked hex values) and navigation semantics (push/pop, tab-switch clearing behaviour).

## Font files

The `.otf` and `.ttf` files aren't committed — get them from Fontshare (Chillax + Satoshi) and Google Fonts (JetBrains Mono) and drop them into `RostrPlusPackage/Sources/DesignSystem/Fonts/`. File names are listed in that folder's README.

Until the files are present, previews render in SF Pro and log a DEBUG warning per missing font. The app won't crash — it'll just look unbranded.

## Relationship to the web app

The Supabase project is shared (`vgjmfpryobsuboukbemr`) — RLS policies, RPCs, and edge functions are the same. Don't create duplicate schema from iOS. Anything new (e.g. an iOS-only settings toggle) should be added to the web repo's `supabase/migrations/` directory so the two stay in sync.

## License

Proprietary. Beyond Concierge Events Co. LLC.
