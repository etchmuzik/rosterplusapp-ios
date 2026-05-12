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

# If ASC API key env vars are set, pass them through to xcodebuild so
# `-allowProvisioningUpdates` can fetch the distribution certificate
# from App Store Connect headlessly. Without this, the export step
# falls back to whatever Xcode has cached locally — and if no
# "Apple Distribution" cert is in the keychain, the export fails with
# "No signing certificate iOS Distribution found".
#
# Same three env vars upload.sh already requires.
ASC_FLAGS=()
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
    ASC_FLAGS=(
        -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
        -authenticationKeyPath "$ASC_KEY_PATH"
    )
    echo "  (using ASC API key for headless cert provisioning)"
fi

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$OPTIONS_PLIST" \
    -allowProvisioningUpdates \
    "${ASC_FLAGS[@]}"

echo ""
echo "✅ .ipa at $EXPORT_PATH/RostrPlus.ipa"
echo "Next: scripts/upload.sh to ship to TestFlight"
