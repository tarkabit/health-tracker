#!/bin/bash
# Builds the universal app and packages it into a distributable .dmg under dist/.
# The app is ad-hoc signed (not notarized), so recipients must clear the quarantine
# flag once — see the printed instructions / README.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Health Tracker"
BUNDLE="${APP_NAME}.app"

# Build a fresh universal .app
./build.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${BUNDLE}/Contents/Info.plist" 2>/dev/null || echo 1.0)"

echo "▸ Packaging DMG…"
STAGING="$(mktemp -d)/Health Tracker"
mkdir -p "$STAGING"
cp -R "$BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"   # drag-to-install target

mkdir -p dist
DMG="dist/Health Tracker ${VERSION}.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

echo "✓ Created ${DMG}"
echo
echo "Send that .dmg to anyone. Since it isn't notarized, tell them to allow it once:"
echo "  1. Open the .dmg, drag Health Tracker to Applications."
echo "  2. In Terminal, run:"
echo "       xattr -dr com.apple.quarantine \"/Applications/Health Tracker.app\""
echo "     then open the app normally. (Or: System Settings ▸ Privacy & Security ▸ Open Anyway.)"
