# OpenCode CLI

OpenCode reads its config from `~/.config/opencode/opencode.json`. The schema differs from most hosts: the container key is `mcp` (not `mcpServers`), and HTTP-based MCP servers use `type: "remote"` (not `"http"`).

## Via agents.sh

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=opencode-cli
```

## Manual install

Edit `~/.config/opencode/opencode.json` and add:

```json
{
  "mcp": {
    "roboflow": {
      "type": "remote",
      "url": "https://mcp.roboflow.com/mcp",
      "headers": {
        "x-api-key": "${ROBOFLOW_API_KEY}",
        "Accept": "application/json, text/event-stream"
      }
    }
  }
}
```

## JSONC caveat

OpenCode's config technically supports JSONC (JSON with `//` comments and `/* */` blocks). The installer refuses to edit a config that contains comments — preserving them through a JSON round-trip is brittle. If your config has comments:

- Pass `--force` to drop them and rewrite the file (your existing comment-related context is lost; a backup is written next to the original).
- Or edit the file by hand using the JSON above.

## API key

```bash
export ROBOFLOW_API_KEY=YOUR_KEY
```

Get the key from `https://app.roboflow.com/{workspace}/settings/api`.

## Uninstall

```bash
agents.sh --yes --host=opencode-cli --uninstall
```
