# Cursor Agents: Local vs Remote

## Recommendation

If users should be able to choose either a normal agent or a remote agent:

- Use the **local/normal agent** for interactive work on the user's current workspace.
- Use the **remote/cloud agent** for async repo-based work that can continue in the background.

If choosing one remote path first:

- Pick the **Cloud Agents API** if the goal is durable backend-managed remote runs.
- Pick the **CLI in cloud mode** if the goal is live streaming UX while the user is present.

## Option Summary

| Option | Best for | Main strengths | Main limitations |
| --- | --- | --- | --- |
| Local Agent CLI | Interactive coding in current workspace | Works on local files and uncommitted changes, interactive approvals, local MCP/config, conversational UX | Requires local machine/session |
| Remote Agent CLI (`agent -c`) | Live remote session with streaming | Cloud-backed execution with CLI streaming output, closer to local-agent UX | Still process-driven; less natural as a backend job system |
| Remote Agent API | Detached async runs | Job lifecycle, polling, webhooks, artifacts, PR automation | No documented true streaming output |

## What Local/Normal Agents Can Do That Remote API Cannot

- Work on the user's actual local workspace, including uncommitted changes and local-only files.
- Support explicit `agent`, `plan`, and `ask` modes in the CLI.
- Ask for approval before shell/tool execution.
- Use ACP (`agent acp`) for custom client/editor integrations.
- Use local/project MCP configuration directly.
- Support local session workflows like `resume`, `ls`, and `@` context picking.

## What Remote/Cloud Agents Can Do Better

- Run on a separate cloud VM and continue after the user disconnects.
- Scale parallel runs without using the user's machine.
- Work naturally as async jobs with create, follow-up, stop, delete, and status APIs.
- Create PRs and branches as part of the run.
- Return artifacts such as screenshots, videos, and logs.
- Send webhooks on `FINISHED` and `ERROR`.

## Key Gaps To Design Around

### 1. Local workspace vs hosted repo

Local agents can use dirty git state and local files. Remote agents work from a hosted repo or PR URL. Remote mode is not a true substitute for "work on what is only on my laptop".

### 2. MCP parity is not clean

- CLI supports MCP in local/project config.
- Cloud agent docs describe MCP support in cloud agents.
- But the Cloud Agents API docs explicitly say MCP is not yet supported by the API.

This means remote API support should not assume full MCP parity with local agents.

### 3. No documented remote `plan` / `ask` mode parity in the API

The CLI exposes mode selection. The Cloud Agents API exposes job operations, not conversational mode controls.

### 4. Environment differences

Local agents inherit the user's machine. Remote agents require cloud environment setup, secrets, and possibly `.cursor/environment.json`.

### 5. Streaming differences

- **Remote API:** no documented true streaming interface.
- **Remote CLI cloud mode:** streamable via CLI stdout using:

```bash
agent -c -p "do the task" --output-format stream-json --stream-partial-output
```

If live progress is important, remote CLI is the stronger option.

## Suggested Product Model

Treat these as separate runtimes behind one shared abstraction:

- `local`
- `remoteCli`
- `remoteApi`

Each runtime should expose capability flags such as:

- `supportsLocalWorkspace`
- `supportsUncommittedChanges`
- `supportsInteractiveApproval`
- `supportsStreaming`
- `supportsWebhooks`
- `supportsArtifacts`
- `supportsPrCreation`
- `supportsMcp`
- `supportsPlanMode`
- `supportsAskMode`

## Recommended Default

For a clean product model:

- `normal` = local interactive workspace agent
- `remote` = API-backed async cloud agent
- optional future enhancement = "Watch live" mode using remote CLI cloud mode

This keeps the UX honest:

- **Local** feels like an interactive coding assistant.
- **Remote API** feels like a background job.
- **Remote CLI** can later be added as a live remote session mode when streaming matters.
