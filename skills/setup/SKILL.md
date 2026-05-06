---
name: roboflow-setup
description: Use when user asks how to configure the Roboflow MCP server, get or set their API key, wire the key into their environment globally or per project, or troubleshoot a missing key or unreachable MCP server.
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
  (a) Global — available in all projects on this machine (shell profile)
  (b) Local — this project only (.claude/settings.local.json, gitignored)
```

### Step 3 — Apply Configuration

**If user chose (a) Global:**

Show the user the exact line to add to their shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export ROBOFLOW_API_KEY="<key>"
```

Then show the reload command:

```bash
source ~/.zshrc   # or source ~/.bashrc
```

Instruct them to open a new Claude Code session after sourcing.

**If user chose (b) Local:**

Before writing, handle gitignore based on project state:

```bash
# 1. Is this a git repo?
git rev-parse --is-inside-work-tree 2>/dev/null && IS_GIT=true || IS_GIT=false

if [ "$IS_GIT" = "true" ]; then
  if [ -f .gitignore ]; then
    # .gitignore exists — add entry if missing
    grep -qxF '.claude/settings.local.json' .gitignore || echo '.claude/settings.local.json' >> .gitignore
  else
    # git repo but no .gitignore — create it
    echo '.claude/settings.local.json' > .gitignore
  fi
fi
```

Write `.claude/settings.local.json` at the project root:

```json
{
  "env": {
    "ROBOFLOW_API_KEY": "<key>"
  }
}
```

Confirm the file was written and the gitignore entry is in place.

### Step 4 — Verify

Run:

```bash
claude mcp list
```

`roboflow` must appear with status connected. If not, see Troubleshooting.

Then ask Claude Code:

> "Search Roboflow Universe for hard hat detection datasets."

Result list = auth working. Error = proceed to Troubleshooting.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `ROBOFLOW_API_KEY not set` | Env var not exported or stale session | `echo $ROBOFLOW_API_KEY`; source profile; open fresh Claude Code session |
| `401 Unauthorized` | Wrong workspace key or key regenerated | Re-copy from `app.roboflow.com/{workspace}/settings/api`; update config |
| `roboflow` not in `claude mcp list` | Plugin not installed | `claude plugin list`; if missing, see README install instructions |
| MCP server unreachable | Network or firewall | `curl -I https://mcp.roboflow.com/mcp` |
| Tools unavailable after key set | Session predates key | Open fresh terminal, relaunch Claude Code |

## Related Skills

- `roboflow://skills/api-reference/SKILL` — REST and Inference API auth patterns and SDK choice
- `roboflow://skills/inference/SKILL` — running inference once setup is complete
