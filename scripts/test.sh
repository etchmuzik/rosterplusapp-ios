#!/usr/bin/env bash
# test.sh — run the full test suite against the iPhone 16 simulator.
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

# Stage 1 — build product configuration
bash "$SCRIPT_DIR/check-app-bundle.sh"

# Stage 2 — Swift Testing suite
cd "$SCRIPT_DIR/../RostrPlusPackage"

xcodebuild test \
    -scheme RostrPlusPackage-Package \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -skipPackagePluginValidation \
    2>&1 | grep -E "Test run with|error:|\*\* TEST"
