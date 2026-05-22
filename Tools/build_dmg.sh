#!/bin/bash
# Build a polished DMG installer for MacBroom.
# Requires: an already-built MacBroom.app in build/release-derived/Build/Products/Release/

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.5.0"
APP_NAME="MacBroom"
APP_BUNDLE="build/release-derived/Build/Products/Release/${APP_NAME}.app"
VOL_NAME="MacBroom ${VERSION}"
STAGING_DIR="build/dmg-staging-${VERSION}"
TMP_DMG="build/${APP_NAME}-${VERSION}.rw.dmg"
FINAL_DMG="build/${APP_NAME}-${VERSION}.dmg"
BG_PNG="build/dmg-assets/background.png"
BG_PNG_2X="build/dmg-assets/background@2x.png"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "❌ App bundle not found at $APP_BUNDLE"
  echo "   Run: xcodebuild -project MacBroom.xcodeproj -scheme MacBroom -configuration Release -derivedDataPath build/release-derived build"
  exit 1
fi

if [[ ! -f "$BG_PNG" ]]; then
  echo "❌ Background PNG missing. Run: swift Tools/generate_dmg_background.swift"
  exit 1
fi

echo "🧹  Cleaning previous staging…"
rm -rf "$STAGING_DIR" "$TMP_DMG" "$FINAL_DMG"
mkdir -p "$STAGING_DIR"

echo "📦  Staging app + Applications shortcut…"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "🎨  Adding background image…"
mkdir -p "$STAGING_DIR/.background"
cp "$BG_PNG"    "$STAGING_DIR/.background/background.png"
cp "$BG_PNG_2X" "$STAGING_DIR/.background/background@2x.png"

echo "📀  Creating writable DMG…"
hdiutil create -volname "$VOL_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$TMP_DMG"

echo "🔧  Mounting + applying Finder layout…"
MOUNT_POINT=$(hdiutil attach "$TMP_DMG" -nobrowse -noverify -noautoopen | tail -n 1 | awk -F'\t' '{print $NF}')
sleep 2

osascript <<EOF
tell application "Finder"
  tell disk "${VOL_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 200, 860, 620}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.png"
    set position of item "${APP_NAME}.app" of container window to {180, 300}
    set position of item "Applications" of container window to {480, 300}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sleep 1
sync
hdiutil detach "$MOUNT_POINT" -force >/dev/null

echo "🗜  Compressing read-only DMG…"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"
rm -f "$TMP_DMG"

echo "✅  Done: $FINAL_DMG"
ls -lh "$FINAL_DMG"
