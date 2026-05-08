# Claude Desktop (chat tab)

Claude Desktop has two AI surfaces: the **Chat tab** (general-purpose Claude conversations) and the **Code tab** (Claude Code, integrated). They use different config systems.

| Surface | Reads from | Roboflow path |
|---|---|---|
| **Code tab** (Claude Code in Claude Desktop) | `~/.claude/plugins/` (Claude Code plugin system) | install via [`claude-code-cli`](claude-code.md) — covers both the standalone CLI and the Code tab in Claude Desktop |
| **Chat tab** | `claude_desktop_config.json` (stdio-only schema) | install via `--host=claude-desktop` (this page) |

If you only want Roboflow while coding, install [`claude-code-cli`](claude-code.md) and skip this page entirely. If you want Roboflow tools available in regular Claude conversations on the Chat tab, read on.

## Why this needs a bridge

Claude Desktop's Chat tab MCP schema only accepts stdio servers (`{ command, args, env, extensionId }` — no `type: "http"`). Since Roboflow MCP is HTTP-based, the installer configures the [`mcp-remote`](https://github.com/geelen/mcp-remote) npm package as a stdio↔HTTP bridge. That requires:

- **Node.js + npx** on PATH (Node ≥ 18). The installer refuses to write the config if `npx` isn't found and prints install instructions.
- The literal API key is embedded in the bridge `args` because Claude Desktop doesn't expand env variables in MCP arguments.

## Via agents.sh

```bash
# Provide a key — installer refuses without one (Chat tab can't read $ROBOFLOW_API_KEY at runtime)
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=claude-desktop --api-key=YOUR_KEY
```

If you have your key in `$ROBOFLOW_API_KEY` or in `~/.config/roboflow/config.json` (the Roboflow Python SDK location), the installer picks it up automatically:

```bash
export ROBOFLOW_API_KEY=YOUR_KEY
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=claude-desktop
```

When multiple workspaces are present in the SDK config, the installer prompts you to pick one (or use `--workspace=<url>` non-interactively).

## Config path

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Linux | `~/.config/Claude/claude_desktop_config.json` |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |

The installer adds an entry under `mcpServers` and preserves anything else in the file. Restart Claude Desktop after install for the change to take effect.

## What gets written

```json
{
  "mcpServers": {
    "roboflow": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@0.1.27",
        "https://mcp.roboflow.com/mcp",
        "--header",
        "x-api-key:rf_xxxxxxxxxxxxxxxx"
      ]
    }
  }
}
```

The `mcp-remote` version is pinned in the installer so behavior is reproducible — bumps go through `agents.sh` updates.

## Manual install

If you'd rather skip `agents.sh` and edit the file by hand: take the JSON above, replace `rf_xxx…` with your Roboflow API key (from `https://app.roboflow.com/{workspace}/settings/api`), and drop it into the platform-specific config path. Make sure Node + npx are on the PATH that Claude Desktop inherits when it launches.

## Uninstall

```bash
agents.sh --yes --host=claude-desktop --uninstall
```

Removes only the `roboflow` entry from `mcpServers`; other servers preserved.
