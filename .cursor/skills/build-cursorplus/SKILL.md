---
name: build-cursorplus
description: Build the Cursor+ macOS app using xcodebuild. Use when the user wants to build, compile, or run the Cursor+ app.
disable-model-invocation: true
---

# Build Cursor+

Build the Cursor+ app for macOS.

## Instructions

1. Run this command from the project root:

   ```bash
   xcodebuild -project "Cursor+.xcodeproj" -scheme "Cursor+" -configuration Debug build
   ```

2. Ensure Xcode is set as the active developer directory. If you get "requires Xcode" errors, the user must run:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

3. On success, the built `.app` is in `~/Library/Developer/Xcode/DerivedData/` (or the default build location). Report the build outcome to the user.
