# Claude Desktop

Claude Desktop reads MCP servers from a platform-specific config file. It does not consume `SKILL.md` files (those are a Claude Code CLI / plugin concept), so this is MCP-only.

## Via agents.sh

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=claude-desktop
```

## Config path

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Linux | `~/.config/Claude/claude_desktop_config.json` |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |

The installer adds an entry under `mcpServers` and preserves anything else in the file.

## Manual install

Open the config file at the path for your platform and add:

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

Restart Claude Desktop after editing.

## API key

`ROBOFLOW_API_KEY` must be in the environment Claude Desktop inherits at launch. On macOS that's typically the `launchd` environment or your shell rc files (depending on how you launch Claude Desktop). The simplest path:

```bash
launchctl setenv ROBOFLOW_API_KEY YOUR_KEY
```

…before launching Claude Desktop. For persistence across reboots, use a launchd plist or your preferred shell profile.

## Uninstall

```bash
agents.sh --yes --host=claude-desktop --uninstall
```
