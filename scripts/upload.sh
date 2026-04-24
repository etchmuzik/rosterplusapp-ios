#!/usr/bin/env bash
# upload.sh — ship build/export/RostrPlus.ipa to App Store Connect.
#
# Requires an App Store Connect API key stored at ~/.appstoreconnect/
# with an environment prefix set via:
#   export ASC_KEY_ID="XXXXXXXXXX"
#   export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   export ASC_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
#
# Get these from App Store Connect → Users and Access → Keys.

set -euo pipefail

cd "$(dirname "$0")/.."

IPA_PATH="build/export/RostrPlus.ipa"

if [[ ! -f "$IPA_PATH" ]]; then
    echo "❌ No .ipa at $IPA_PATH. Run scripts/archive.sh and scripts/export.sh first."
    exit 1
fi

: "${ASC_KEY_ID:?Set ASC_KEY_ID from App Store Connect → Keys}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID from App Store Connect → Keys}"
: "${ASC_KEY_PATH:?Set ASC_KEY_PATH to the downloaded .p8 file}"

echo "› Uploading $IPA_PATH to App Store Connect…"
xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

echo ""
echo "✅ Upload dispatched."
echo "Processing takes ~5–15 min. Watch App Store Connect → TestFlight."
