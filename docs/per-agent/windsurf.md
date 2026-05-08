# Windsurf

Windsurf reads MCP servers from `~/.codeium/windsurf/mcp_config.json`. MCP-only adapter.

## Via agents.sh

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=windsurf-desktop
```

Restart Windsurf for the change to take effect.

## Manual install

Edit `~/.codeium/windsurf/mcp_config.json` and add:

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

## API key

`ROBOFLOW_API_KEY` must be in the environment Windsurf inherits when it starts. On macOS, set it via your shell profile (and launch Windsurf from a terminal) or via `launchctl setenv` for GUI launches.

```bash
export ROBOFLOW_API_KEY=YOUR_KEY
```

## Uninstall

```bash
agents.sh --yes --host=windsurf-desktop --uninstall
```
