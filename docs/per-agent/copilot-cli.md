# GitHub Copilot CLI

Copilot CLI reads MCP servers from `~/.copilot/mcp-config.json`. This adapter is MCP-only — Copilot CLI doesn't consume `SKILL.md` files.

## Via agents.sh

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=copilot-cli
```

## Manual install

Edit `~/.copilot/mcp-config.json` and add:

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

```bash
export ROBOFLOW_API_KEY=YOUR_KEY
```

Get the key from `https://app.roboflow.com/{workspace}/settings/api`.

## Uninstall

```bash
agents.sh --yes --host=copilot-cli --uninstall
```
