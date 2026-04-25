# ROSTR+ iOS

Native iOS app for [ROSTR+ GCC](https://rosterplus.io) — the Gulf region's artist booking platform.

Companion to the web repo at [etchmuzik/rosterplusapp](https://github.com/etchmuzik/rosterplusapp). Same Supabase backend, same brand, different surface.

The data contract both clients share — Supabase types, the RPC catalog with caller lists per platform, and schema notes — lives in [etchmuzik/rosterplus-shared](https://github.com/etchmuzik/rosterplus-shared). **Cross-check `RPC_CONTRACT.md` there before adding any new `.rpc(` / `.from(` / `.functions.invoke(` call** so iOS and web don't drift apart at the data layer.

For a one-page snapshot of where the platform stands today (live deploy state, parity status, outstanding follow-ups): [`STATUS.md`](https://github.com/etchmuzik/rosterplus-shared/blob/main/STATUS.md) in the shared repo.

## Status

**TestFlight-ready.** Auth is live, every primary store hits Supabase, the package builds clean under Swift 6 strict concurrency, and `scripts/ship.sh` archives + uploads in one command.

- All 23 screens shipped (Waves 1–5)
- Sign in with Apple + email/password + forgot password — all wired
- Live data on every primary surface (Roster, Bookings, BookingDetail, Contracts, Inbox, Thread, ProfileEdit, Availability, Reviews, Notifications, Push)
- 97 tests / 20 suites passing in ~3 s
- XcodeGen + ship automation — one command to TestFlight

### Recent ships (last 14 days)

- `b67f126` docs: link README to `rosterplus-shared` contract repo
- `336fc94` feat(audit): wire Reviews to Supabase + write `onboarding_complete`
- `f9f4687` fix(swift6): clear actor-isolation errors and realtime deprecations
- `1deb615` feat(invitations): iOS Roster gets an Invite button (Tier B parity)
- `d91a274` feat(contracts): iOS Sign + Send goes live — closes parity gap with web
- `b1e8647` fix(auth): wire the signup flow — root cause of "auth doesn't work"
- `9bccad2` fix(submit): resolve App Store Connect validator errors
- `85ca444` fix(push): aps-environment now config-aware
- `8bd98e2` feat: XcodeGen + ship automation — one command to TestFlight
- `3d3f79c` feat: forgot-password flow goes live on iOS
- `847c5eb` chore: post-audit cleanup — mock debt + stale comments

## Stack

- **iOS 18+** with SwiftUI, **Swift 6.1+** strict concurrency
- **@Observable** for view state (not @ObservableObject); MV pattern, no ViewModels
- **Swift Package Manager** — all feature code lives in `RostrPlusPackage/`; the Xcode app target is a thin `@main` wrapper
- **Supabase Swift SDK** for data, realtime, storage, auth
- **Swift Testing** (`@Test`, `#expect`) — not XCTest
- **XcodeGen** drives the project file from `Config/Shared.xcconfig`

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
│   │   ├── Stores/                 # @Observable stores, all Supabase-backed
│   │   ├── SupabaseClient/         # Supabase wrapper + DTOs + RPC wrappers
│   │   └── Features/<Screen>/      # One folder per screen (23 total)
│   └── Tests/                      # Swift Testing
├── RostrPlusUITests/               # UI automation via XCUITest
├── scripts/
│   ├── ship.sh                     # XcodeGen → archive → export → upload
│   ├── test.sh                     # Run the package test suite (97/20)
│   └── bootstrap.sh                # First-time setup
└── README.md
```

## Stores (all Supabase-backed)

| Store | Tables / RPCs |
|---|---|
| `AuthStore` | `auth.users`, `signup` + `send-password-reset` edge functions, Sign in with Apple |
| `RosterStore` | `artists` (filtered, paginated) |
| `ArtistDetailStore` | `artists` + joined `profiles` |
| `BookingsStore` | `bookings` (insert + list + status updates) |
| `AvailabilityCheckStore` | `check_availability` RPC |
| `ContractsStore` | `contracts` (read + sign) |
| `InboxStore` | `messages` (list, send, realtime) |
| `TimelineStore` | `booking_events` (read + realtime) |
| `NotificationsStore` | `notifications` (list, realtime, mark-read) |
| `PushStore` | `device_tokens` (register, refresh) |
| `ProfileStore` | `profiles` (load, update, `markOnboardingComplete`) |
| `ReviewStore` | `create_review` RPC |
| `InvitationsStore` | `invitations` + `send-email` edge function |
| `PaymentsStore` | `payments` (read-only — payment-create is web-only) |
| `AnalyticsStore` | `bookings` (aggregated client-side) |

Cross-check call sites in [rosterplus-shared/RPC_CONTRACT.md](https://github.com/etchmuzik/rosterplus-shared/blob/main/RPC_CONTRACT.md).

## Design system rules

These are non-negotiable (per the design handoff):

1. **Primary CTAs are near-white `#f3f5f8` on black.** The "gold" tokens (`--gold`, `--gold-text`, `--border-gold`) now alias to a near-white accent — same name, mono palette. Don't introduce a real gold value.
2. **Every card is a glass surface.** Flat opaque cards break the visual signature. Use `.glassSurface()` — wraps `.ultraThinMaterial` with white-tint + hairline-border + inner-highlight.
3. **Chillax + Satoshi + JetBrains Mono are load-bearing.** Bundle the font files under `Sources/DesignSystem/Fonts/` (see that folder's README for exact names). Don't fall back to SF Pro.
4. **Monochrome everywhere except status pills.** The amber/green/blue/red status colours appear only on pills and status tags, never as fills for CTAs.
5. **Mono font for all metadata.** Timestamps, prices, labels, status strings.

## Running locally

```bash
# Open the workspace
open RostrPlus.xcworkspace

# Or work in the SPM package directly — fast iteration on previews
cd RostrPlusPackage && swift package resolve
```

Xcode previews work for every `View` that has a `#Preview` block.

## Testing

```bash
bash scripts/test.sh
# or in Xcode, ⌘U
```

97 tests / 20 suites in ~3 s. Tests cover design-system tokens (scale monotonicity, locked hex values), navigation semantics, and the Supabase-backed stores (with mock client injection).

## Shipping to TestFlight

```bash
bash scripts/ship.sh
```

Runs XcodeGen → `xcodebuild archive` → `xcodebuild -exportArchive` → `xcrun altool --upload-package`. Configures from `Config/Shared.xcconfig` + `Config/Release.xcconfig`. Apple Developer credentials come from environment / keychain (see `scripts/bootstrap.sh`).

## Font files

The `.otf` and `.ttf` files aren't committed — pull them from Fontshare (Chillax + Satoshi) and Google Fonts (JetBrains Mono) and drop them into `RostrPlusPackage/Sources/DesignSystem/Fonts/`. File names are listed in that folder's README.

Until the files are present, previews render in SF Pro and log a DEBUG warning per missing font. The app won't crash — it'll just look unbranded.

## Relationship to the web app

The Supabase project is shared (`vgjmfpryobsuboukbemr`) — RLS policies, RPCs, edge functions are the same. **Don't create duplicate schema from iOS.** Anything new (e.g. an iOS-only setting) should be added to the web repo's `supabase/migrations/` directory so the two stay in sync, then surfaced here.

The 2026-04-25 audit ([web repo](https://github.com/etchmuzik/rosterplusapp), `AUDIT-2026-04-25.md` in the user's `~/Developer`) caught the historical drift between iOS and web RPC sets and drove the creation of [rosterplus-shared](https://github.com/etchmuzik/rosterplus-shared). Read that catalog before adding a new `.rpc(` / `.from(` / `.functions.invoke(` call.

## License

Proprietary. Beyond Concierge Events Co. LLC.
