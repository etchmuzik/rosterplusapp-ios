# Ship Guide — ROSTR+ iOS

Everything you need to get from `git clone` to TestFlight.

---

## First-time setup

### 1. Install prerequisites

```bash
xcode-select --install         # Xcode CLI tools (if missing)
brew install xcodegen          # Project generator
```

### 2. Generate the Xcode project + open it

```bash
cd /path/to/rosterplusapp-ios
scripts/bootstrap.sh
```

That script:
- Installs XcodeGen if it's missing
- Runs `xcodegen generate` → produces `RostrPlus.xcodeproj`
- Opens Xcode

The `.xcodeproj` is **intentionally gitignored** — `project.yml` is the source of truth. Re-run `scripts/bootstrap.sh` any time `project.yml` or `Config/*.xcconfig` changes.

### 3. Sign in to your Apple Developer team in Xcode

Xcode → **Settings** → **Accounts** → **+** → sign in with the Apple ID that owns the `io.rosterplus.app` bundle ID.

Once signed in, the `RostrPlus` target in the project will automatically pick up your distribution certificate and provisioning profile via "Automatically manage signing".

---

## Day-to-day

| Task | Command |
|---|---|
| Run the app on a simulator | Open Xcode → pick **iPhone 16** → **⌘R** |
| Run unit tests (86 tests, 18 suites) | `scripts/test.sh` |
| Regenerate project after yml/xcconfig change | `scripts/bootstrap.sh` |
| Ship to TestFlight | `scripts/ship.sh` (see below) |

---

## Ship to TestFlight

### One-time: App Store Connect API key

1. App Store Connect → **Users and Access** → **Keys** → **+**
2. Give it a name (e.g. "ROSTR+ CLI"), access: **App Manager**, click **Generate**
3. Download the `.p8` file and stash it at `~/.appstoreconnect/AuthKey_XXXXXXXXXX.p8` (Apple only lets you download once — keep the file safe).
4. Note the Key ID (10 chars) and Issuer ID (UUID shown at the top of the Keys page).

Add these to your shell profile (`~/.zshrc`):

```bash
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ASC_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
```

### One-time: App record

App Store Connect → **My Apps** → **+** → **New App**
- Platform: **iOS**
- Name: **ROSTR+**
- Primary Language: **English (U.S.)**
- Bundle ID: **io.rosterplus.app** (must match `Config/Shared.xcconfig`)
- SKU: **rosterplus-ios**
- User Access: **Full Access**

### Every release

Bump the version in `Config/Shared.xcconfig`:

```
MARKETING_VERSION = 0.1.0           # user-visible, e.g. 1.0.0
CURRENT_PROJECT_VERSION = 1         # build number, increment every upload
```

Then ship:

```bash
scripts/ship.sh
```

This runs the full pipeline:

1. `scripts/test.sh` — 86 unit tests must pass
2. `scripts/archive.sh` — `xcodebuild archive` into `build/RostrPlus.xcarchive`
3. `scripts/export.sh` — `xcodebuild -exportArchive` into `build/export/RostrPlus.ipa`
4. `scripts/upload.sh` — `xcrun altool --upload-app` to App Store Connect

Processing typically takes 5–15 minutes. Watch App Store Connect → **TestFlight** for the build to appear.

### Distribute to testers

Once processing is done in TestFlight:
- Internal testing (your Apple Developer team): immediate
- External testing (beta groups): Apple review ~24h, then invite-ready

---

## Hooking up APNs (push notifications)

The `send-push` edge function runs in **dry-run mode** until you set four secrets in the Supabase dashboard.

1. Apple Developer → **Certificates, Identifiers & Profiles** → **Keys** → **+**
2. Name it "ROSTR+ APNs", enable **Apple Push Notifications service (APNs)**, confirm, download the `.p8` (one-shot).
3. Note the Key ID (10 chars) and your Team ID (10 chars, visible at the top right).
4. Supabase Dashboard → your project → **Project Settings** → **Edge Functions** → **Secrets** → add:

   | Name | Value |
   |---|---|
   | `APNS_AUTH_KEY` | contents of the `.p8` file (the whole PEM block) |
   | `APNS_KEY_ID` | the 10-char key id |
   | `APNS_TEAM_ID` | your 10-char Apple team id |
   | `APNS_BUNDLE_ID` | `io.rosterplus.app` |

5. Optionally for TestFlight sandbox:

   | Name | Value |
   |---|---|
   | `APNS_HOST` | `https://api.sandbox.push.apple.com` |

`send-push` flips out of dry-run automatically — no redeploy needed.

---

## Supabase dashboard items

Two settings can't be automated via MCP — they need your operator session:

1. **Leaked-password protection**
   Dashboard → **Authentication** → **Policies** → toggle **"Enable password protection against leaked passwords"**. One click. Closes the security advisor WARN.

2. **APNs secrets** — see above.

---

## Web app deploy

The web app lives at `/Users/etch/Downloads/rosterplus-deploy` and is deployed to Hostinger at [rosterplus.io](https://rosterplus.io).

### To update

1. Edit the HTML or `assets/js/app.js` directly
2. Hostinger → **File Manager** (or SFTP) → upload the changed files to `public_html/`
3. Bump the `CACHE_NAME` version in `sw.js` so the service worker cache busts:

   ```js
   const CACHE_NAME = 'rostr-v2';   // was 'rostr-v1'
   ```

4. Commit locally:

   ```bash
   cd /Users/etch/Downloads/rosterplus-deploy
   git add -A
   git commit -m "feat: <describe change>"
   ```

The web app shares the same Supabase project (`vgjmfpryobsuboukbemr`) as iOS — schema changes made via the iOS MCP session land live on both surfaces immediately.

---

## Troubleshooting

**"No account for team" on archive**
→ Xcode → Settings → Accounts → re-sign in. Then Project → target RostrPlus → Signing & Capabilities → tick "Automatically manage signing".

**Upload fails with "ITMS-90076: Missing push notification entitlement"**
→ Apple Developer → Identifiers → `io.rosterplus.app` → edit → tick Push Notifications → save. Xcode regenerates the provisioning profile automatically on next archive.

**XcodeGen spec warnings about unused paths**
→ Harmless — `project.yml` is intentionally minimal. Only fails the build if generation itself errors.

**Tests pass locally but fail in CI**
→ CI isn't set up yet; when you add it, ensure the runner has Xcode 16+, the same simulator (`iPhone 16`), and `xcodegen` preinstalled.

---

## Repo layout

```
rosterplusapp-ios/
├── project.yml                    # XcodeGen spec — source of truth
├── Config/                        # .xcconfig + entitlements (hand-edited)
├── RostrPlus/                     # Thin app shell (RostrPlusApp.swift, Assets)
├── RostrPlusPackage/              # Feature code — stores, DTOs, views, tests
│   ├── Package.swift
│   ├── Sources/
│   └── Tests/
├── RostrPlusUITests/              # XCUITest smoke tests
├── scripts/                       # bootstrap, test, archive, export, upload, ship
├── SHIP.md                        # ← you are here
└── README.md                      # Project overview
```

The generated `RostrPlus.xcodeproj` (gitignored) is rebuilt from `project.yml` any time `scripts/bootstrap.sh` runs.
