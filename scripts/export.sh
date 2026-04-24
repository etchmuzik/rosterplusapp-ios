#!/usr/bin/env bash
# export.sh — produce an .ipa from build/RostrPlus.xcarchive.
#
# Assumes scripts/archive.sh has already run. Output goes to
# build/export/RostrPlus.ipa.

set -euo pipefail

cd "$(dirname "$0")/.."

ARCHIVE_PATH="build/RostrPlus.xcarchive"
EXPORT_PATH="build/export"
OPTIONS_PLIST="scripts/ExportOptions.plist"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "❌ No archive at $ARCHIVE_PATH. Run scripts/archive.sh first."
    exit 1
fi

mkdir -p "$EXPORT_PATH"

echo "› Exporting .ipa (App Store distribution)…"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$OPTIONS_PLIST" \
    -allowProvisioningUpdates

echo ""
echo "✅ .ipa at $EXPORT_PATH/RostrPlus.ipa"
echo "Next: scripts/upload.sh to ship to TestFlight"
