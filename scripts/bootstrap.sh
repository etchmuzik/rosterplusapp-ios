#!/usr/bin/env bash
# bootstrap.sh — one-shot setup for a fresh clone.
#
# Installs XcodeGen if missing, generates the Xcode project, and opens
# it. Idempotent — re-run any time project.yml changes.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "› Installing XcodeGen via Homebrew…"
    brew install xcodegen
fi

echo "› Generating RostrPlus.xcodeproj from project.yml…"
xcodegen generate

echo "› Opening Xcode…"
open RostrPlus.xcodeproj

cat <<EOF

✅ Setup complete.

Next:
  • Pick an iPhone 16 simulator in the scheme selector
  • ⌘R to run the app
  • ⌘U (or pick the RostrPlusPackage-Package scheme) to run the 86 unit tests

Re-run scripts/bootstrap.sh after any edit to project.yml.
EOF
