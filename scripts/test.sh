#!/usr/bin/env bash
# test.sh — run the full test suite against the iPhone 16 simulator.
#
# Mirrors what CI will do. Exits non-zero on any test failure.
#
# We `cd` into the package directory so xcodebuild picks up the
# auto-generated `RostrPlusPackage-Package` scheme (which lives next
# to Package.swift, not next to the app .xcodeproj).

set -euo pipefail

cd "$(dirname "$0")/../RostrPlusPackage"

xcodebuild test \
    -scheme RostrPlusPackage-Package \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -skipPackagePluginValidation \
    2>&1 | grep -E "Test run with|error:|\*\* TEST"
