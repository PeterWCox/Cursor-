---
name: build-cursormenubar
description: Build the Cursor Menu Bar macOS app using xcodebuild. Use when the user wants to build, compile, or run the CursorMenuBar app.
disable-model-invocation: true
---

# Build CursorMenuBar

Build the Cursor Menu Bar app for macOS.

## Instructions

1. Run this command from the project root (`/Users/petercox/dev/cursor-macosapp`):

   ```bash
   xcodebuild -project CursorMenuBar.xcodeproj -scheme CursorMenuBar -configuration Debug build
   ```

2. Ensure Xcode is set as the active developer directory. If you get "requires Xcode" errors, the user must run:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

3. On success, the built `.app` is in `~/Library/Developer/Xcode/DerivedData/` (or the default build location). Report the build outcome to the user.
