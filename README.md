# Cursor+

**Cursor’s AI agent in your menu bar.** A native macOS app that talks to the Cursor Agent CLI—one floating panel, multiple projects, real-time streaming. No need to switch into the full IDE when you just want to ask the agent something.

---

## What it is

**Cursor+** is an unofficial, native macOS app that gives you quick access to Cursor’s AI agent from the **menu bar**. It uses the same Cursor Agent CLI that powers the IDE, so you get the same models and context—without running the full Cursor app.

Open the panel, pick a project, type a prompt, and watch responses stream in. The window stays where you put it (or collapses to a slim sidebar), so it fits how you work: single monitor, laptop, or multi-screen.

---

## Who it’s for

- **Laptop / single-screen coders** who don’t want the IDE eating half the display—Cursor+ stays out of the way until you need it.
- **Multi-project workflows**—switch repos and workspaces in one window, each with its own conversation and quick actions.
- **Anyone who prefers their main editor** (VS Code, Xcode, Neovim, etc.) but still wants Cursor’s agent on tap from the menu bar.
- **“Vibe coding” and quick iterations**—Fix build, Commit & push, or custom prompts in one click while you stay in flow.

---

## What you get

| Feature | Benefit |
|--------|---------|
| **Menu bar launcher** | Open the agent panel from anywhere; no need to bring Cursor to the front. |
| **Floating panel** | Stays on top and where you place it—or collapse to a sidebar to free space and still see when the agent is done. |
| **Real-time streaming** | See agent output as it’s generated, same as in the IDE. |
| **Multiple projects in one window** | Tabs per workspace; switch repos without opening separate windows. |
| **Quick actions** | One-click **Fix build** and **Commit & push** (and optional project-specific commands) so common tasks stay fast. |
| **Workspace & model picker** | Choose project folder and model (with optional hiding of models you don’t use). |
| **Project rules** | Uses `.cursor/rules` and `AGENTS.md` from your workspace, so the agent knows your project. |
| **History** | Recent questions per tab so you can revisit or re-run prompts. |
| **View in Browser / Debug** | Open your app in the browser or run a debug script from the current workspace. |

---

## Screenshots

| Full view | Collapsed sidebar |
|-----------|-------------------|
| ![Cursor+ full view with Cursor editor](MarketingAssets/metro-dashboard-cursor-split.png) | ![Cursor+ collapsed sidebar](MarketingAssets/cursor-metro-sidebar.png) |

![Cursor+ dashboard / preview](MarketingAssets/metro-dashboard-screenshot.png)

---

## Requirements

Before building and running Cursor+ you need:

| Requirement | Purpose |
|-------------|---------|
| **macOS** | Recent version (Ventura or later recommended). |
| **Xcode** | From the [Mac App Store](https://apps.apple.com/app/xcode/id497799835). Required to compile the Swift app. Xcode Command Line Tools alone are not enough—you need the full Xcode app. |
| **Cursor Agent CLI** | The `agent` binary used to create chats and stream responses. Cursor+ does not work without it. |

---

## Getting started

### 1. Install the Cursor Agent CLI

Cursor+ talks to Cursor through the **Cursor Agent CLI** (`agent`). Install it and log in once:

```bash
curl https://cursor.com/install -fsSL | bash
```

The installer typically puts the `agent` binary in `~/.local/bin`. If that directory isn’t in your PATH, add it (e.g. in `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Log in so the CLI can use your Cursor account:

```bash
agent login
```

---

### 2. Build the app

**Option A — Xcode (simplest)**

1. Open **`CursorMetro.xcodeproj`** in Xcode.
2. Select the **CursorMetro** scheme and your Mac as the run destination.
3. **⌘B** to build, **⌘R** to run.

The first run creates **Cursor+.app** in the build products directory. You can drag it into **Applications** or run it from the project.

**Option B — Terminal**

From the project root:

```bash
./build.sh
```

This builds a Debug **Cursor+.app** at `build/Build/Products/Debug/Cursor+.app`. To build and launch in one step:

```bash
./build-and-run.sh
```

---

### 3. Run Cursor+

- **First time:** Open **Cursor+.app** (from the project folder or from Applications). The Cursor+ icon appears in the **menu bar** (top right).
- **Open the panel:** Click the menu bar icon. A floating panel opens with the composer and conversation.
- **Settings:** Click the **⚙️** icon or use **⌘,** to set your default workspace (project folder).
- **Quit:** Right‑click the menu bar icon → **Quit Cursor+**, or use **⌘Q** when the panel is focused.

---

### 4. First steps

1. Click the menu bar icon to open the panel.
2. If prompted, set your **workspace** (the project folder the agent will use) in Settings (⌘,) or via the workspace picker in the panel.
3. Type a message in the composer and press **Return** (or click Send). The agent reply streams in the conversation area.
4. Use the **sidebar** to switch or add tabs, each with its own conversation and workspace.

---

## Troubleshooting

| Issue | What to try |
|--------|----------------|
| **“Agent not found”** | Install the Cursor Agent CLI (step 1) and ensure `~/.local/bin` is in your `PATH`. Restart Cursor+ after changing PATH. |
| **“Try running ’agent login’”** | In Terminal, run `agent login` and complete the sign-in. Then try again in Cursor+. |
| **Panel doesn’t open** | Allow Cursor+ in **System Settings → Privacy & Security → Accessibility** (required for the floating panel). |
| **Build fails in Xcode** | Use a recent Xcode and macOS. Try **File → Packages → Reset Package Caches** if you see dependency errors. |

---

## Not supported (yet)

- **Billing / usage** — not exposed via the Cursor Agent CLI.
- **File tagging with @** — may or may not be possible via CLI.
- **Running skills with /** — not available in this app.
- **Plan mode** — not available.
- **Agent list on the right** — layout option not implemented.

---

## Planned

- **Terminal per project** — run sessions without leaving Cursor+ (e.g. no need to open iTerm/Ghostty).
- **Open in browser** — improved support.
- **Task lists** — for planning and tracking.
- **Claude Code interoperability** — where supported by the CLI.
- **Rendering improvements** — smoother experience in very long conversations.

---

## For developers

- **Cursor Agent CLI:** See [docs/cursor-agent-cli.md](docs/cursor-agent-cli.md) for what the `agent` CLI can do, its commands and arguments, and how Cursor+ uses it.
- **Source layout:** See [docs/agent-streaming-and-rendering.md](docs/agent-streaming-and-rendering.md) for how streaming and rendering work.
- **Code structure:** The app is split by responsibility: `CursorPlusApp.swift` (app lifecycle, panel, status bar), `PopoutView.swift` (main UI and streaming), `AgentRunner.swift` (Cursor CLI), `ConversationModels.swift` and `AgentTabState.swift` (domain and tab state), plus smaller view and helper modules. MARK comments are used in longer files.
