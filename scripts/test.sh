#!/usr/bin/env bash
# test.sh — run the full test suite against the iPhone 16 simulator.
#
# Mirrors what CI will do. Exits non-zero on any test failure.

set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild test \
    -scheme RostrPlusPackage-Package \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -skipPackagePluginValidation \
    2>&1 | grep -E "Test run with|error:|\*\* TEST"
