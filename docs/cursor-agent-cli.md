# Cursor Agent CLI reference

The **Cursor Agent CLI** is the `agent` binary that powers Cursor’s AI agent from the terminal (and is what Cursor Metro uses under the hood). This doc summarizes what it can do, its arguments, and commands.

## Installation

Install with:

```bash
curl https://cursor.com/install -fsSL | bash
```

The binary is usually installed to `~/.local/bin/agent`. If that directory isn’t in your PATH, add it (e.g. in `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage overview

```text
agent [options] [command] [prompt...]
```

- **Without a command:** Start the agent with an optional initial prompt. Options control workspace, model, resume, etc.
- **With a command:** Run a subcommand (e.g. `login`, `create-chat`, `models`).

---

## Commands

| Command | Description |
|--------|-------------|
| `login` | Authenticate with Cursor. Set `NO_OPEN_BROWSER` to disable opening the browser. |
| `logout` | Sign out and clear stored authentication. |
| `status` / `whoami` | View authentication status. |
| `create-chat` | Create a new empty chat and return its ID (stdout). Used so follow-up messages can use `--resume <id>`. |
| `models` | List available models for your account. |
| `list-models` | (Option) List available models and exit. |
| `about` | Display version, system, and account information. |
| `update` | Update Cursor Agent to the latest version. |
| `mcp` | Manage MCP servers. |
| `generate-rule` / `rule` | Generate a new Cursor rule with interactive prompts. |
| `install-shell-integration` | Install shell integration to `~/.zshrc`. |
| `uninstall-shell-integration` | Remove shell integration from `~/.zshrc`. |
| `ls` | Resume a chat session (list/pick). |
| `resume` | Resume the latest chat session. |
| `help [command]` | Display help for the main CLI or a specific command. |

---

## Options (main agent)

When running the agent (with or without a prompt), these options apply.

### Prompt / output

| Option | Description |
|--------|-------------|
| `prompt` | Positional argument(s): initial prompt for the agent. |
| `-p` / `--print` | Print responses to console (non-interactive). Gives access to all tools (write, shell, etc.). Default: `false`. |
| `--output-format <format>` | Only with `--print`. One of: `text`, `json`, `stream-json`. Default: `text`. |
| `--stream-partial-output` | Only with `--print` and `stream-json`. Stream partial output as individual text deltas. Default: `false`. |

### Session

| Option | Description |
|--------|-------------|
| `--resume [chatId]` | Resume an existing chat. If `chatId` is omitted, you can select a session. |
| `--continue` | Continue the previous session. |

### Model

| Option | Description |
|--------|-------------|
| `--model <model>` | Model to use (e.g. `gpt-5`, `sonnet-4`, `sonnet-4-thinking`). |
| `--list-models` | List available models and exit. Default: `false`. |

### Workspace and execution

| Option | Description |
|--------|-------------|
| `--workspace <path>` | Workspace directory (defaults to current working directory). |
| `-w` / `--worktree [name]` | Start in an isolated git worktree at `~/.cursor/worktrees/<reponame>/<name>`. If name is omitted, one is generated. |
| `--worktree-base <branch>` | Branch or ref to base the new worktree on. Default: current HEAD. |
| `--skip-worktree-setup` | Skip worktree setup scripts from `.cursor/worktrees.json`. Default: `false`. |
| `-f` / `--force` | Force allow commands unless explicitly denied. Default: `false`. |
| `--yolo` | Alias for `--force` (Run Everything). Default: `false`. |
| `--sandbox <mode>` | Explicitly enable or disable sandbox. Choices: `enabled`, `disabled`. Overrides config. |
| `--trust` | Trust the current workspace without prompting. Only in `--print`/headless mode. Default: `false`. |

### Mode

| Option | Description |
|--------|-------------|
| `--mode <mode>` | Execution mode. `plan`: read-only/planning (analyze, propose plans, no edits). `ask`: Q&A, read-only. Choices: `plan`, `ask`. |
| `--plan` | Shorthand for `--mode=plan`. Ignored if `--cloud` is passed. Default: `false`. |
| `-c` / `--cloud` | Start in cloud mode (open composer picker on launch). Default: `false`. |

### Auth and MCP

| Option | Description |
|--------|-------------|
| `--api-key <key>` | API key for authentication (or set `CURSOR_API_KEY`). |
| `-H` / `--header <header>` | Add custom header to agent requests (`Name: Value`, repeatable). |
| `--approve-mcps` | Automatically approve all MCP servers. Default: `false`. |

### Other

| Option | Description |
|--------|-------------|
| `-v` / `--version` | Output the version number. |
| `-h` / `--help` | Display help. |

---

## Examples

**Log in (required before first use):**
```bash
agent login
```

**Check auth and list models:**
```bash
agent status
agent models
```

**Run agent in current directory with a prompt:**
```bash
agent -p "Explain this codebase" --workspace /path/to/project
```

**Stream JSON output (for scripts / apps):**
```bash
agent -f -p "Summarize the README" --workspace /path/to/project \
  --output-format stream-json --stream-partial-output
```

**Resume a specific chat:**
```bash
agent -f -p "Continue from before" --workspace /path/to/project --resume <chat-id>
```

**Create a new chat and get its ID:**
```bash
agent create-chat
```

**Use a specific model:**
```bash
agent -f -p "Review this function" --workspace . --model sonnet-4
```

**Read-only / plan mode (no edits):**
```bash
agent --plan -p "Suggest a refactor" --workspace .
agent --mode ask -p "What does this file do?" --workspace .
```

---

## How Cursor Metro uses the CLI

Cursor Metro uses only a subset of the CLI:

1. **New conversation:** It runs `agent create-chat` once per tab; stdout is the conversation ID.
2. **Send message / stream response:** It runs the agent with:
   - `-f` — non-interactive (allow commands)
   - `-p "<prompt>"` — user message
   - `--workspace <path>` — selected project directory
   - `--output-format stream-json` — newline-delimited JSON events on stdout
   - `--stream-partial-output` — stream partial output
   - `--resume <id>` — when continuing an existing chat (from `create-chat`)
   - `--model <model>` — when the user picks a specific model

The app parses the CLI’s stdout (stream-json events) to show thinking, assistant text, and tool calls in real time. For details, see [agent-streaming-and-rendering.md](agent-streaming-and-rendering.md).

---

## Troubleshooting

| Issue | What to do |
|-------|------------|
| **“Cursor CLI not found”** | Install with `curl https://cursor.com/install -fsSL \| bash` and ensure `~/.local/bin` is in your PATH. |
| **“Not authenticated” / “Try running ’agent login’”** | Run `agent login` in Terminal and complete sign-in, then try again. |
| **Agent exits with non-zero code** | Check stderr; if it mentions login/auth, run `agent login` again. |

To see the exact options and commands on your system:

```bash
agent --help
agent help <command>
```
