---
name: roboflow-setup
description: Configure Roboflow API key for this project — writes or updates ROBOFLOW_API_KEY in .env for per-project workspace switching.
argument-hint: [api-key]
when_to_use: Use when setting up Roboflow credentials for a new project, switching Roboflow workspaces, or resolving MCP authentication errors. Pass the API key as an argument to write it immediately.
allowed-tools: Bash(python3 -c *)
---

# Roboflow Auth Setup

## Current state

```!
if [ -n "${ROBOFLOW_API_KEY:-}" ]; then
  echo "ROBOFLOW_API_KEY: set in environment (${#ROBOFLOW_API_KEY} chars)"
elif [ -f .env ] && grep -q "^ROBOFLOW_API_KEY=" .env 2>/dev/null; then
  VAL=$(grep "^ROBOFLOW_API_KEY=" .env | head -1 | cut -d= -f2-)
  echo "ROBOFLOW_API_KEY: set in .env (${#VAL} chars)"
else
  echo "ROBOFLOW_API_KEY: NOT SET"
fi
```

## Instructions

**If an API key was provided as `$ARGUMENTS`:** write it to `.env` in the current working directory using:

```
python3 -c "
import os, re
key = '$ARGUMENTS'.strip()
if not key:
    print('No key — pass it as argument: /roboflow-setup YOUR_KEY')
else:
    f = '.env'
    content = open(f).read() if os.path.exists(f) else ''
    pattern = r'^ROBOFLOW_API_KEY=.*'
    replacement = f'ROBOFLOW_API_KEY={key}'
    if re.search(pattern, content, re.MULTILINE):
        content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
        action = 'Updated'
    else:
        content = content.rstrip('\n') + ('\n' if content else '') + replacement + '\n'
        action = 'Written'
    open(f, 'w').write(content)
    print(f'{action} ROBOFLOW_API_KEY to {f}')
    if not os.path.exists('.gitignore') or '.env' not in open('.gitignore').read():
        print('Reminder: add .env to .gitignore to avoid committing credentials')
"
```

**If no argument was given:** print the get-key instructions below and ask the user to re-run with their key.

## Get your API key

Keys are **workspace-scoped**. Use a different key per workspace to isolate projects.

1. Open `https://app.roboflow.com/{workspace}/settings/api`
2. Copy the workspace API key
3. Run: `/computer-vision-skills:roboflow-setup YOUR_KEY`

## Auth methods

| Method | Agent | Scope | How |
|--------|-------|-------|-----|
| `.env` file | Both | Per project (gitignored) | Run this skill with your key |
| Shell env var | Both | Session | `export ROBOFLOW_API_KEY=xxx` |
| Plugin settings (Claude Code) | Claude Code | Global | `claude plugin configure computer-vision-skills` |
| Scope-local install (Claude Code) | Claude Code | Per project | `claude plugin install computer-vision-skills --scope local` then configure |

**Claude Code per-project isolation:** `--scope local` stores plugin settings in `.claude/settings.local.json` (gitignored). Each project gets independent plugin config including its own API key.

**Codex per-project isolation:** write `ROBOFLOW_API_KEY` to `.env` (this skill) or set it in your shell profile per project directory.
