#!/bin/zsh
# Builds a release version of the app and packages it as build/Video Editing Tool.app
# Usage: scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Video Editing Tool.app"

swift build -c release --product VideoEditingTool
BIN="$(swift build -c release --product VideoEditingTool --show-bin-path)/VideoEditingTool"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VideoEditingTool"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# App icon (redraw it with: swift scripts/make-icon.swift)
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough to run on this Mac (no Apple developer account needed).
codesign --force --sign - "$APP"

# Tell Finder about the app's file types (project packages).
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" || true

echo "Built: $APP"
