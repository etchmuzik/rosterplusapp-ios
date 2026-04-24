#!/usr/bin/env bash
# archive.sh — build a TestFlight-ready .xcarchive.
#
# Requires: Xcode signed in to your Apple Developer team, and a valid
# distribution certificate + App Store provisioning profile in Keychain.
#
# Output: build/RostrPlus.xcarchive (then .ipa via export.sh)

set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVE_PATH="build/RostrPlus.xcarchive"
mkdir -p build

echo "› Regenerating project to pick up any yml/xcconfig changes…"
xcodegen generate

echo "› Archiving RostrPlus (Release configuration)…"
xcodebuild archive \
    -project RostrPlus.xcodeproj \
    -scheme RostrPlus \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -skipPackagePluginValidation \
    -allowProvisioningUpdates

echo ""
echo "✅ Archive at $ARCHIVE_PATH"
echo "Next: scripts/export.sh to produce a .ipa for upload"
