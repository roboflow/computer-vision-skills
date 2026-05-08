# Claude Code

Claude Code CLI exposes a plugin marketplace. The installer registers Roboflow as a marketplace, installs the plugin, and embeds your API key into the plugin's MCP config so the server authenticates without you needing to manage `ROBOFLOW_API_KEY` anywhere.

This same plugin install is **also picked up by the Code tab in Claude Desktop** (which reads `~/.claude/`), so one install covers two surfaces.

## Via agents.sh

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=claude-code-cli
```

The installer:
1. `claude plugin marketplace add roboflow/computer-vision-skills`
2. `claude plugin install roboflow`
3. Patches `~/.claude/plugins/cache/roboflow/roboflow/<version>/.mcp.json` to embed the resolved API key inline (no env var needed at runtime).

If multiple workspaces are present in `~/.config/roboflow/config.json` (the Roboflow Python SDK location), the installer prompts you to pick one. Or pass `--workspace=<url>` to choose non-interactively.

## Manual install (without agents.sh)

```bash
claude plugin marketplace add roboflow/computer-vision-skills
claude plugin install roboflow
```

Then **either**:

- Set `ROBOFLOW_API_KEY` in the env that launches `claude` (the plugin's `.mcp.json` substitutes `${ROBOFLOW_API_KEY}` from the environment), **or**
- Edit `~/.claude/plugins/cache/roboflow/roboflow/<version>/.mcp.json` and replace `"x-api-key": "${ROBOFLOW_API_KEY}"` with the literal key.

The first path is more convenient when you have the env var set up; the second is what `agents.sh` does for you.

## Project scope

Per-project isolation — useful when different projects need different `ROBOFLOW_API_KEY` values for different workspaces:

```bash
agents.sh --yes --host=claude-code-cli --project
```

Or directly:

```bash
claude plugin install roboflow --scope local
```

## Local clone (development / contributors)

```bash
git clone https://github.com/roboflow/computer-vision-skills
claude plugin marketplace add ./computer-vision-skills
claude plugin install roboflow
```

For a throwaway test without registering the plugin globally:

```bash
cd computer-vision-skills
claude --plugin-dir .
```

## Managed rules

Optionally, install a Roboflow guidance block in your project's `CLAUDE.md`:

```bash
agents.sh --yes --host=claude-code-cli --project --rules-only
```

Writes the block between `<!-- BEGIN ROBOFLOW -->` / `<!-- END ROBOFLOW -->` markers — content outside the markers is preserved on re-runs and uninstall.

## Uninstall

```bash
agents.sh --yes --host=claude-code-cli --uninstall
```

Or directly:

```bash
claude plugin remove roboflow
claude plugin marketplace remove roboflow   # optional
```
