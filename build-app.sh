#!/bin/bash
set -e

# Get script directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Cursor+..."
xcodebuild -project "Cursor+.xcodeproj" -scheme "Cursor+" -configuration Release -derivedDataPath build clean build

APP_SOURCE="$SCRIPT_DIR/build/Build/Products/Release/Cursor+.app"
APP_DEST="$SCRIPT_DIR/Cursor+.app"

if [[ -d "$APP_SOURCE" ]]; then
    echo "Copying Cursor+.app to source directory..."
    rm -rf "$APP_DEST"
    cp -R "$APP_SOURCE" "$APP_DEST"
    echo "Done! Cursor+.app is at $APP_DEST"
else
    echo "Error: Build succeeded but app not found at $APP_SOURCE"
    exit 1
fi
