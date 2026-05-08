# Cursor

Cursor doesn't have a plugin marketplace yet, so the installer writes config files directly.

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=cursor-desktop
```

This writes:

- `~/.cursor/mcp.json` — adds the Roboflow MCP server entry, preserving any other servers you have configured.
- `~/.claude/skills/<name>/` — copies the seven Roboflow skills. Cursor reads `SKILL.md` files from this path (the same convention `npx skills add` uses).

## Project scope

For per-project setup (skills + MCP scoped to one workspace, plus a Cursor rule file):

```bash
cd /path/to/your/project
agents.sh --yes --host=cursor-desktop --project
```

Writes:

- `<project>/.cursor/mcp.json`
- `<project>/.claude/skills/`
- `<project>/.cursor/rules/roboflow.mdc` (rule file scoped to the project)

## Manual install

Skip `agents.sh` and do it yourself:

1. Edit `~/.cursor/mcp.json` and add this entry under `mcpServers`:

   ```json
   {
     "mcpServers": {
       "roboflow": {
         "type": "http",
         "url": "https://mcp.roboflow.com/mcp",
         "headers": {
           "x-api-key": "${ROBOFLOW_API_KEY}",
           "Accept": "application/json, text/event-stream"
         }
       }
     }
   }
   ```

2. Install skills with `npx skills add roboflow/computer-vision-skills -g` (global) or drop this `-g` for project scope.

## API key

Export `ROBOFLOW_API_KEY` in the shell that launches Cursor. macOS GUI launches inherit the env from `launchctl setenv` or your shell profile if launched from terminal.

```bash
export ROBOFLOW_API_KEY=YOUR_KEY
```

Get the key from `https://app.roboflow.com/{workspace}/settings/api`.

## Uninstall

```bash
agents.sh --yes --host=cursor-desktop --uninstall
```

Or manually: remove the `roboflow` entry from `~/.cursor/mcp.json` and delete `~/.claude/skills/<roboflow-skill>/` directories.
