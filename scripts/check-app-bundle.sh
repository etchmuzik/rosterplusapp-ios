#!/usr/bin/env bash
# check-app-bundle.sh — assert the built app bundle contains the
# Info.plist + entitlements keys we depend on at runtime.
#
# Why this exists:
#   Wave-5.8 (2026-04-24) added INFOPLIST_KEY_UIBackgroundModes to
#   Config/Shared.xcconfig. The Swift test suite was all-green for
#   17 days, but Xcode 16's plist synthesizer silently dropped the
#   key — so the live TestFlight build couldn't receive silent push.
#   The 2026-05-11 audit caught it manually. This script makes that
#   class of bug fail CI before it reaches a build.
#
#   None of these checks exercise app behaviour — they assert the
#   build product's *configuration*. Cheaper than a UI test, catches
#   regressions Swift Testing can't see.
#
# What we check:
#   Info.plist:
#     - UIBackgroundModes contains "remote-notification"
#     - CFBundleDisplayName == "ROSTR+"
#     - CFBundleIdentifier == "io.rosterplus.app"
#     - NSPhotoLibraryUsageDescription is non-empty
#     - NSCameraUsageDescription is non-empty
#   Entitlements:
#     - aps-environment is set (push tokens require it)
#     - com.apple.developer.associated-domains contains
#       "applinks:rosterplus.io" (universal links / AASA)
#
# Cost: one Debug-iphonesimulator build (~10-30s warm). Builds into
# a tempdir so it doesn't pollute Xcode's DerivedData.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DERIVED=$(mktemp -d)
trap 'rm -rf "$DERIVED"' EXIT

echo "==> Building RostrPlus.app for plist inspection…"
xcodebuild \
  -project RostrPlus.xcodeproj \
  -scheme RostrPlus \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath "$DERIVED" \
  -quiet \
  build >/dev/null

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/RostrPlus.app"
PLIST="$APP_PATH/Info.plist"
ENTITLEMENTS_BIN="$APP_PATH/RostrPlus"

if [[ ! -f "$PLIST" ]]; then
  echo "❌ $PLIST not found — build produced no app bundle"
  exit 1
fi

FAILURES=0
check() {
  local desc="$1"
  local cmd="$2"
  local expected="$3"
  local actual
  if ! actual=$(eval "$cmd" 2>&1); then
    echo "❌ $desc"
    echo "   command: $cmd"
    echo "   error:   $actual"
    ((FAILURES++)) || true
    return
  fi
  if [[ -n "$expected" && "$actual" != *"$expected"* ]]; then
    echo "❌ $desc"
    echo "   expected to contain: $expected"
    echo "   actual:              $actual"
    ((FAILURES++)) || true
    return
  fi
  echo "✓ $desc"
}

echo
echo "==> Info.plist checks"
check "UIBackgroundModes contains remote-notification" \
  "/usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' '$PLIST'" \
  "remote-notification"
check "CFBundleDisplayName = ROSTR+" \
  "/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' '$PLIST'" \
  "ROSTR+"
check "CFBundleIdentifier = io.rosterplus.app" \
  "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' '$PLIST'" \
  "io.rosterplus.app"
check "NSPhotoLibraryUsageDescription is non-empty" \
  "/usr/libexec/PlistBuddy -c 'Print :NSPhotoLibraryUsageDescription' '$PLIST'" \
  "ROSTR+"
check "NSCameraUsageDescription is non-empty" \
  "/usr/libexec/PlistBuddy -c 'Print :NSCameraUsageDescription' '$PLIST'" \
  "ROSTR+"
# Export-compliance: ROSTR+ uses only iOS-builtin encryption, so this
# is permanently false. Baking it in means App Store Connect never
# prompts for the encryption documentation on a new build. If a
# future build ever links a third-party crypto framework, flip this
# assertion to expect "true" and answer the ASC questionnaire about
# exemption status. See Config/RostrPlus-Info.plist for the rationale.
check "ITSAppUsesNonExemptEncryption = false (no ASC encryption prompt)" \
  "/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' '$PLIST'" \
  "false"

echo
echo "==> Entitlements checks"
# Simulator builds use ad-hoc codesign that doesn't embed entitlements
# in a reliably-readable form (`codesign -d --entitlements -` returns
# an empty <dict/>). For device builds the keys ARE embedded, but we
# don't want to require a device build for the test loop.
#
# Read the source entitlements file referenced by CODE_SIGN_ENTITLEMENTS
# directly. That's what Xcode hands to codesign at signing time — if
# this file has the keys, the signed build will too. The path is set
# in project.yml/xcconfig, so we resolve it via xcodebuild's settings.
ENTITLEMENTS_FILE=$(xcodebuild -project RostrPlus.xcodeproj -scheme RostrPlus \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^[[:space:]]*CODE_SIGN_ENTITLEMENTS = /{print $2; exit}')
if [[ -z "$ENTITLEMENTS_FILE" ]]; then
  echo "❌ CODE_SIGN_ENTITLEMENTS is not set in the build settings"
  ((FAILURES++)) || true
elif [[ ! -f "$ENTITLEMENTS_FILE" ]]; then
  echo "❌ entitlements file not found at $ENTITLEMENTS_FILE"
  ((FAILURES++)) || true
else
  echo "   source: $ENTITLEMENTS_FILE"
  if /usr/libexec/PlistBuddy -c "Print :aps-environment" "$ENTITLEMENTS_FILE" >/dev/null 2>&1; then
    aps=$(/usr/libexec/PlistBuddy -c "Print :aps-environment" "$ENTITLEMENTS_FILE")
    echo "✓ aps-environment = $aps (push tokens enabled)"
  else
    echo "❌ aps-environment missing — silent + alert push will be rejected by APNs"
    ((FAILURES++)) || true
  fi
  # associated-domains is an array of strings; PlistBuddy can't grep
  # array members, so dump the whole array and grep.
  domains=$(/usr/libexec/PlistBuddy -c "Print :com.apple.developer.associated-domains" "$ENTITLEMENTS_FILE" 2>&1 || echo "")
  if echo "$domains" | grep -q "applinks:rosterplus.io"; then
    echo "✓ com.apple.developer.associated-domains includes applinks:rosterplus.io"
  else
    echo "❌ applinks:rosterplus.io missing — universal links won't dispatch to app"
    ((FAILURES++)) || true
  fi
fi

echo
if (( FAILURES > 0 )); then
  echo "❌ $FAILURES check(s) failed"
  exit 1
fi
echo "✓ All app-bundle checks passed"
