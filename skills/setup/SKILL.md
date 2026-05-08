---
name: roboflow-setup
description: Use when user asks how to configure the Roboflow MCP server, get or set their API key, wire the key into their Claude Code or Codex environment, or troubleshoot a missing key or unreachable MCP server.
---

# Roboflow MCP Configuration

Run this as an interactive wizard. Follow the steps in order — each step gates the next.

## Wizard Steps

### Step 1 — Obtain the API Key

First check whether the Roboflow CLI is available:

```bash
which roboflow
```

**If CLI is available** — instruct the user to log in (this stores the key in `~/.config/roboflow/config.json`):

```bash
roboflow auth login
```

After login, extract the key automatically:

```bash
python3 -c "
import json, os
cfg = json.load(open(os.path.expanduser('~/.config/roboflow/config.json')))
print(list(cfg['workspaces'].values())[0]['apiKey'])
"
```

Show the extracted key to the user and proceed to Step 2 with it.

**If CLI is not available** — direct the user to the web UI:

> Open `https://app.roboflow.com/{workspace}/settings/api`, copy the **Private API Key**, then come back.

Then use `AskUserQuestion` to collect it:

```
Question: "Paste your Roboflow API key here (it will only be used to configure your environment — never stored in chat or committed to git):"
```

### Step 2 — Ask Scope

Use `AskUserQuestion` with these options:

```
Question: "Where should the API key be configured?"
Options:
  (a) Local — Claude Code only (.claude/settings.local.json, gitignored)
  (b) Local — Codex only (.codex/config.toml, gitignored)
  (c) Local — both Claude Code and Codex
```

### Step 3 — Apply Configuration

**If user chose (a) Local — Claude Code or (c) both:**

Before writing, handle gitignore based on project state:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null && IS_GIT=true || IS_GIT=false

if [ "$IS_GIT" = "true" ]; then
  if [ -f .gitignore ]; then
    if ! grep -qxF '.claude/settings.local.json' .gitignore; then
      if [ -s .gitignore ] && [ "$(tail -c 1 .gitignore)" != "" ]; then
        printf '\n' >> .gitignore
      fi
      printf '%s\n' '.claude/settings.local.json' >> .gitignore
    fi
  else
    printf '%s\n' '.claude/settings.local.json' > .gitignore
  fi
fi
```

Create the `.claude` directory and write `.claude/settings.local.json` at the project root:

```bash
mkdir -p .claude
cat > .claude/settings.local.json <<'EOF'
{
  "env": {
    "ROBOFLOW_API_KEY": "<key>"
  }
}
EOF
```

Confirm the file was written and the gitignore entry is in place.

**If user chose (b) Local — Codex or (c) both:**

Before writing, handle gitignore based on project state:

```bash
git rev-parse --is-inside-work-tree 2>/dev/null && IS_GIT=true || IS_GIT=false

if [ "$IS_GIT" = "true" ]; then
  if [ -f .gitignore ]; then
    grep -qxF '.codex/config.toml' .gitignore || echo '.codex/config.toml' >> .gitignore
  else
    echo '.codex/config.toml' > .gitignore
  fi
fi
```

Create the `.codex/` directory if it does not exist, then write `.codex/config.toml`:

```toml
[shell_environment_policy]
set = { ROBOFLOW_API_KEY = "<key>" }

[mcp_servers.roboflow.env]
ROBOFLOW_API_KEY = "<key>"
```

`[shell_environment_policy]` makes the key available to all subprocesses Codex spawns.
`[mcp_servers.roboflow.env]` scopes it directly to the Roboflow MCP server.

Confirm the file was written and the gitignore entry is in place.

### Step 4 — Verify

**Claude Code path (options a or c):** Run:

```bash
claude mcp list
```

`roboflow` must appear with status connected. If not, see Troubleshooting.

**Codex-only path (option b):** No automated verification available — confirm `.codex/config.toml` was written and instruct the user to launch Codex and run a Roboflow tool call to verify.

Then ask Claude Code:

> "Search Roboflow Universe for hard hat detection datasets."

Result list = auth working. Error = proceed to Troubleshooting.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `ROBOFLOW_API_KEY not set` | Key missing from `.claude/settings.local.json` or stale session | Check file exists and contains `env.ROBOFLOW_API_KEY`; open fresh Claude Code session |
| `401 Unauthorized` | Wrong workspace key or key regenerated | Re-copy from `app.roboflow.com/{workspace}/settings/api`; update config |
| `roboflow` not in `claude mcp list` | Plugin not installed | `claude plugin list`; if missing, see README install instructions |
| MCP server unreachable | Network or firewall | `curl -I https://mcp.roboflow.com/mcp` |
| Tools unavailable after key set | Session predates key | Open fresh terminal, relaunch Claude Code |

## Related Skills

- `roboflow://skills/api-reference/SKILL` — REST and Inference API auth patterns and SDK choice
- `roboflow://skills/inference/SKILL` — running inference once setup is complete
