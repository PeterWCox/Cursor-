# Cursor Menu Bar App

A macOS menu bar app that lets you send prompts to Cursor's agent from anywhere, without switching to the IDE.

## Prerequisites

1. **Cursor CLI** — Install and authenticate:
   ```bash
   curl https://cursor.com/install -fsSL | bash
   # Ensure ~/.local/bin is in your PATH (add to ~/.zshrc or ~/.bash_profile)
   agent login
   ```

2. **Xcode** — Required for building (macOS 13+)

## Build & Run

1. Open the project in Xcode:
   ```bash
   open CursorMenuBar.xcodeproj
   ```

2. Select the **CursorMenuBar** scheme and press **⌘R** to build and run.

3. The app icon (chat bubbles) will appear in your menu bar. It does not show in the Dock (menu bar app only).

## Usage

1. Click the menu bar icon
2. Select **Send to Cursor...** to open the prompt popout
3. Type your prompt and press **⌘Return** or click **Send**
4. The agent runs in your configured workspace; output appears in the popout
5. Use **Settings...** to set your repository path (workspace)

## Features

- Menu bar dropdown with "Send to Cursor" option
- Popout window with prompt input, send button, and output area
- Configurable workspace path (via Settings)
- Uses Cursor CLI's `agent -p` non-interactive mode
- Auto-approves commands (`-f`) for headless operation
- Error handling for missing agent, auth issues, and process failures

## Project Structure

- `CursorMenuBarApp.swift` — App entry, MenuBarExtra, panel management
- `PopoutView.swift` — Prompt input UI and output display
- `AgentRunner.swift` — Spawns `agent` process, captures output
- `SettingsView.swift` — Workspace path configuration
- `Info.plist` — LSUIElement (no Dock icon)
