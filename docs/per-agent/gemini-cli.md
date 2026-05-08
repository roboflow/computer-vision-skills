# Gemini CLI

Gemini CLI reads MCP servers from `~/.gemini/settings.json`. MCP-only adapter.

## Via agents.sh

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=gemini-cli
```

## Manual install

Edit `~/.gemini/settings.json` and add:

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

The installer preserves any other settings already in the file.

## API key

```bash
export ROBOFLOW_API_KEY=YOUR_KEY
```

Get the key from `https://app.roboflow.com/{workspace}/settings/api`.

## Uninstall

```bash
agents.sh --yes --host=gemini-cli --uninstall
```
