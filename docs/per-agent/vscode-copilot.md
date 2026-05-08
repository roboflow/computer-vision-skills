# VS Code Copilot

VS Code Copilot uses a different MCP config schema from most hosts: `servers` (not `mcpServers`) plus an `inputs[]` array for prompted secrets.

## Via agents.sh

Project-scoped (writes `<project>/.vscode/mcp.json`):

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=vscode-copilot --project
```

User-level:

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=vscode-copilot
```

## Config paths

| Scope | Path |
|---|---|
| Project | `<project>/.vscode/mcp.json` |
| User (mac) | `~/Library/Application Support/Code/User/mcp.json` |
| User (linux) | `~/.config/Code/User/mcp.json` |
| User (win) | `%APPDATA%\Code\User\mcp.json` |

## Schema

The installer adds an `inputs[]` `promptString` so VS Code prompts for the API key the first time the server runs:

```json
{
  "inputs": [
    {
      "id": "roboflow_api_key",
      "type": "promptString",
      "description": "Roboflow API key (https://app.roboflow.com/settings/api)",
      "password": true
    }
  ],
  "servers": {
    "roboflow": {
      "type": "http",
      "url": "https://mcp.roboflow.com/mcp",
      "headers": {
        "x-api-key": "${input:roboflow_api_key}",
        "Accept": "application/json, text/event-stream"
      }
    }
  }
}
```

## Manual install

Drop the JSON above into the appropriate `mcp.json` for your scope.

## --inline-key warning

`--inline-key` writes the literal API key into the config file. Project `.vscode/mcp.json` files are commit-able — make sure that's intentional. Default behavior (without `--inline-key`) is the prompted-input flow, which keeps the secret out of source control.

## Uninstall

```bash
agents.sh --yes --host=vscode-copilot --uninstall
```

Removes the `roboflow` server entry and the `roboflow_api_key` input.
