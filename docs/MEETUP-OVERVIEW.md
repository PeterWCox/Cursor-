# Cursor Metro — Meetup overview

High-level summary of **what the app is**, **what it does**, and **design choices** you can use for a Cursor community talk. Slides can lift sections verbatim or shorten to bullets.

---

## One-liner

**Cursor Metro** is a lightweight, open-source macOS companion that wraps the **Cursor Agent CLI** in a purpose-built UI for “vibe coding”: multiple projects, delegated work as **tasks**, and agent progress at a glance—without the full IDE eating the screen.

---

## Why “Metro”?

The name evokes a **small, fast stop**—like a city metro line or a compact shop: get in, do the essential work, move on. The product goal is the same: **low friction** for spinning up work, checking agent status, and switching context.

---

## Problems it tries to solve

From the product narrative (good slide fodder):

1. **Too many windows** — Multiple Cursor windows and terminals for multiple repos.
2. **Screen real estate** — The IDE dominates; hard to browse or work side-by-side on one display.
3. **Lost context** — Easy to lose track of what each agent tab was doing.
4. **Always-on productivity** — Stay productive without dedicating half the screen to Cursor.
5. **One place for many projects** — Central hub instead of juggling apps per repo.
6. **Lower inertia** — Create and manage projects from a single surface.
7. **Repetitive prompting** — One-tap (or chip) actions for things like **fix build** or **commit & push** instead of retyping the same instructions.

---

## Product pillars (how to frame the demo)

| Pillar | What to say |
|--------|-------------|
| **Always-visible companion** | Menu bar + floating panel; optional **collapsed sidebar** so agent status stays visible while the main content is tucked away. |
| **Multi-project hub** | Projects grouped in the sidebar with **agent tabs**, **terminal tabs**, and a **Tasks** view per project. |
| **Task-first workflow** | Backlog / in-progress tasks per project; **delegate to agent**, track **linked** conversation state on the tab chip, complete when reviewed. |
| **CLI-backed agents** | Runs the real **Cursor agent** (streaming JSON), not a mock chat—same backend behavior as the CLI, with a tailored UI. |
| **Integrated terminal** | Build and run commands next to agent and task management. |
| **Speed paths** | Quick actions, keyboard shortcuts, open repo in Cursor or a browser when you need the full editor or a preview. |

---

## Feature map (high level)

### Shell & windowing

- **Menu bar app** — Icon toggles the panel; secondary click for settings, center window, quit.
- **Floating panel** — Resizable, borderless-style window; **frame persisted** across launches.
- **Expand / collapse** — Shrink to a **narrow sidebar** (tab list + status) vs full composer + transcript.
- **Dock & quit behavior** — State saved on quit; **confirmation if agents are still running** so work isn’t dropped silently.

### Projects & tabs

- **Multiple projects** — Each with its own agent and terminal tabs; clear **workspace / folder** association.
- **Tab persistence** — Restores open projects, tabs, and selection from app support (JSON).
- **Reopen closed tab** — **⌘⇧T** for accidental closes.
- **Workspace picker** — Point projects at the right folder; display names derived from paths.

### Tasks (per project)

- **Task list** — Add, edit, **backlog ↔ in progress**, complete, delete; **trash** with restore / permanent delete.
- **Delegate to agent** — Spawns or focuses an agent tab **linked** to that task.
- **Status on the tab chip** — Visual link between task state and agent run (**open / processing / done / stopped**), including **stop** while running.
- **Task screenshots** — Attach imagery to tasks; thumbnails and flows tied to `.metro` storage.
- **Quick task shortcuts in Tasks** — Chips to add tasks that run **Commit & push** or **Fix build** prompts through the agent.

### Agent conversations

- **Streaming UI** — Thinking, assistant text, **tool calls** with status, placeholders while processing or stopped.
- **Session resume** — Conversation IDs passed to the CLI (`--resume`) so threads survive restarts.
- **Model picker** — Choose model where the CLI exposes options; fallbacks until models are listed.
- **Composer** — Send on Return, newline on Shift-Return, **paste including screenshots** for multimodal context.
- **Follow-up queue** — Queue messages while a run is in flight.
- **Pinned questions / snippets** — Composer affordances for reusable prompts (where enabled in UI).
- **Context / usage hints** — Token and usage-oriented UI constants aligned with how the CLI is used.

### Quick actions

- **Configurable buttons** — Default **Fix build** and **Commit & push**; users can add/edit commands (title, prompt, icon, global vs project scope).
- **Composer integration** — Run a quick action in the current tab or spin a new tab (e.g. fix build in a fresh agent).

### Terminal

- **Embedded terminal tabs** — Per-project shells alongside agents.
- **Preferred external terminal** — Setting for which app to use when opening externally.

### Git & repo affordances

- **Git branch picker** — Switch context without leaving the panel (with branch-creation flow where supported).
- **⌘G** — Focus Git-related UI for the current project (as documented in Settings → Shortcuts).

### Open elsewhere

- **⌘O — Open in Browser** — When a URL is configured, or fallbacks like Finder / onboarding flows as implemented.
- **⌘. — Open in Cursor** — Jump from Metro into the full Cursor IDE for the current project.

### Settings & preferences

- **Settings** — Projects root, terminal preferences, model visibility, keyboard shortcut reference (read-only list in app).
- **Per-project settings** — Stored under **`.metro/`** alongside tasks.

### Data & storage (trust / privacy talking point)

- **App support** — Tab and window state.
- **Per-repo `.metro/`** — Tasks JSON, screenshots, project settings—**colocated with the repo** (good for backup, gitignore, and “what lives where”).

---

## Design & engineering choices (for the “why we built it this way” slide)

### Hybrid SwiftUI + AppKit

- **SwiftUI** for most of the UI and state-driven updates.
- **AppKit** for **menu bar item**, **floating `NSPanel`**, and **embedded terminal / text editing** where AppKit integration is stronger or required.

### Observable, granular state

- **`TabManager`** as the hub for projects, tabs, and selection.
- **`AgentTab` / `TerminalTab`** as **`ObservableObject`** instances so **sidebar chips and transcript** update without redrawing the whole window—important for smooth streaming.

### Design system: `CursorTheme`

- **Single source of truth** for semantic colors (light/dark), spacing scale, typography sizes, radii, and brand accents.
- **Goal**: Cursor-adjacent **visual consistency** and fast iteration (change tokens once, UI follows).

### Agent integration

- **`AgentRunner`** owns process spawn, **stream-json** parsing, and error surfaces (auth, CLI missing, etc.).
- UI models (**turns**, **segments**, **tool call status**) are **decoupled** from raw CLI lines—easier to test and to evolve if the stream format changes.

### Safety & ergonomics

- **Quit guard** when agents are running.
- **Shortcuts** documented in-app (Settings) for discoverability: **⌘T** new task, **⌘B/⌘S** collapse, **⌃C** stop agent, etc.

---

## Tech stack (one slide)

- **Language / UI**: Swift, SwiftUI, AppKit bridges.
- **Agent backend**: **Cursor Agent CLI** (local process, streaming).
- **Persistence**: JSON + UserDefaults + `.metro/` per project.
- **Platform**: macOS (menu bar + floating window).

---

## Roadmap hooks (from README — honest “what’s next”)

- **Project creation / scaffolding**
- **Remote agents**
- **Claude Code** (or broader) **interoperability**

Use these to invite contributors and feedback.

---

## Suggested talk arc (15–20 min)

1. **Hook** — “I love Cursor, but my screen and my brain were full of windows.”
2. **Demo** — Menu bar → panel → **two projects** → **task → delegate → chip shows running** → **collapse sidebar** while something runs.
3. **Deep cut** — Quick action **commit & push** or **fix build** without typing the prompt.
4. **Design** — Always-on companion, task-linked agents, `CursorTheme`, hybrid stack.
5. **Open source** — CLI dependency, build from Xcode / script, **`.metro`** data model.
6. **Q&A** — Roadmap, security (local CLI, repo-local data), comparison to full Cursor.

---

## Assets you already have

- **README.md** — Problem list, screenshots (`docs/img*.jpeg`, `docs/im2.jpg`), build prerequisites (Xcode, Cursor Agent CLI), `build-and-run.sh`.
- **docs/OOP-STRUCTURE.md** — Deeper architecture if someone asks “how is it structured?”
- **docs/task-three-dot-menus.md** — Detail on task UX if the audience cares about state machines.

---

*Document generated for meetup use; product behavior may evolve—verify against the latest README and Settings → Shortcuts before presenting.*
