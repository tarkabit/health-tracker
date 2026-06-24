#!/bin/bash
# Builds Health Tracker in release mode and assembles a double-clickable .app bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Health Tracker"
BUNDLE="${APP_NAME}.app"
BUNDLE_ID="com.bala.healthtracker"

echo "▸ Building release binary…"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/HealthTracker"

echo "▸ Assembling ${BUNDLE}…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$BUNDLE/Contents/MacOS/${APP_NAME}"
chmod +x "$BUNDLE/Contents/MacOS/${APP_NAME}"

# App icon — regenerate the .icns if missing, then bundle it.
if [ ! -f AppIcon.icns ]; then
    echo "▸ Generating app icon…"
    swift Tools/makeicon.swift AppIcon.iconset
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
fi
cp AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>      <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>LSApplicationCategoryType</key> <string>public.app-category.healthcare-fitness</string>
</dict>
</plist>
PLIST

echo "▸ Ad-hoc code signing…"
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || echo "  (codesign skipped)"

echo "✓ Built ${BUNDLE}"
echo "  Run:  open \"${BUNDLE}\""
echo "  Install:  cp -R \"${BUNDLE}\" /Applications/"
