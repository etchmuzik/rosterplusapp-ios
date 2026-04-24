#!/usr/bin/env bash
# ship.sh — one command to test, archive, export, and upload.
#
# Run from a clean working tree with:
#   ASC_KEY_ID + ASC_ISSUER_ID + ASC_KEY_PATH env vars set.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "── Step 1 / 4 — Run tests ─────────────────────"
scripts/test.sh

echo ""
echo "── Step 2 / 4 — Archive ───────────────────────"
scripts/archive.sh

echo ""
echo "── Step 3 / 4 — Export .ipa ───────────────────"
scripts/export.sh

echo ""
echo "── Step 4 / 4 — Upload to TestFlight ──────────"
scripts/upload.sh

echo ""
echo "🚀  Ship complete."
