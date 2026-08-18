#!/usr/bin/env bash
# test.sh — run the full test suite against an iPhone simulator
# (auto-detected; override with SIM_NAME="iPhone 17 Pro").
#
# Mirrors what CI will do. Exits non-zero on any failure.
#
# Two stages:
#   1. check-app-bundle.sh — builds the app target and asserts the
#      Info.plist + entitlements contain the keys we depend on at
#      runtime (UIBackgroundModes, aps-environment, etc). This catches
#      the class of bug where Xcode silently drops a key during plist
#      synthesis — Swift Testing can't see those bugs because the
#      package test bundle has its own plist.
#   2. xcodebuild test — runs Swift Testing tests in the package.
#      We `cd` into the package directory so xcodebuild picks up the
#      auto-generated `RostrPlusPackage-Package` scheme (which lives
#      next to Package.swift, not next to the app .xcodeproj).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Simulator to run against. Override with SIM_NAME=... ; otherwise pick
# the first available iPhone (Xcode 26 ships iPhone 17 / 16 Plus, not
# "iPhone 16", so a hard-coded name rots with every Xcode release).
SIM_NAME="${SIM_NAME:-$(xcrun simctl list devices available 2>/dev/null \
  | grep -oE 'iPhone [0-9][^(]*' | sed 's/ *$//' | head -1)}"
: "${SIM_NAME:?No available iPhone simulator found — install one in Xcode › Settings › Components}"

# Stage 1 — build product configuration
bash "$SCRIPT_DIR/check-app-bundle.sh"

# Stage 2 — Swift Testing suite
cd "$SCRIPT_DIR/../RostrPlusPackage"

xcodebuild test \
    -scheme RostrPlusPackage-Package \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -skipPackagePluginValidation \
    2>&1 | grep -E "Test run with|error:|\*\* TEST"
