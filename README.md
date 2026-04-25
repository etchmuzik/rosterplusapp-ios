# ROSTR+ iOS

Native iOS app for [ROSTR+ GCC](https://rosterplus.io) — the Gulf region's artist booking platform.

Companion to the web repo at [etchmuzik/rosterplusapp](https://github.com/etchmuzik/rosterplusapp). Same Supabase backend, same brand, different surface.

The data contract both clients share — Supabase types, the RPC catalog with caller lists per platform, and schema notes — lives in [etchmuzik/rosterplus-shared](https://github.com/etchmuzik/rosterplus-shared). **Cross-check `RPC_CONTRACT.md` there before adding any new `.rpc(` / `.from(` / `.functions.invoke(` call** so iOS and web don't drift apart at the data layer.

## Status

**All 23 screens shipped.** The design handoff is fully realised in SwiftUI.

- [x] Wave 1 — foundation (design system + Home)
- [x] Wave 2 — promoter core loop (Roster, Artist, Booking, Bookings, Contract, Inbox, Thread, Payments, BookingDetail, Invoice)
- [x] Wave 3 — artist side (ArtistDashboard, Availability, ProfileEdit, EPK, Calendar)
- [x] Wave 4 — surrounding flows (Notifications, Review, Analytics, Claim, Settings)
- [x] Wave 5 — auth (Onboarding, SignIn)

### What's left before TestFlight

- [ ] Apple Developer team ID + provisioning profiles (you supply)
- [ ] Real Supabase session wiring in `AuthStore.loadSession()` and `Auth.signIn(with:)`
- [ ] Replace `MockData` with live DTO fetches as each screen's backend RPC comes online
- [ ] Xcode project file — currently the SPM package drives previews; a `.xcodeproj` needs to be generated from `Config/Shared.xcconfig` to produce an archivable binary
- [ ] Font files dropped into `Sources/DesignSystem/Fonts/` (see that folder's README)

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
