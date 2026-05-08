# Claude Code

Claude Code CLI exposes a plugin marketplace, so the simplest install is:

```bash
claude plugin marketplace add roboflow/computer-vision-skills
claude plugin install roboflow
```

The first command registers this repo as a marketplace source (run once per machine). The second installs the plugin.

`agents.sh` does this for you:

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=claude-code-cli
```

## Project scope

Per-project isolation — useful when different projects need different `ROBOFLOW_API_KEY` values for different workspaces:

```bash
claude plugin install roboflow --scope local
```

Or via `agents.sh`:

```bash
agents.sh --yes --host=claude-code-cli --project
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

## API key

The bundled MCP server reads `ROBOFLOW_API_KEY` from the environment. Get the key from `https://app.roboflow.com/{workspace}/settings/api` and export it in the shell that launches `claude`:

```bash
export ROBOFLOW_API_KEY=YOUR_KEY
```

Per-project isolation (different keys per project) is the safer default — keep separate workspaces and billing accounts from leaking across projects. Add the export to a project-local `.env` and source it from your shell or use a tool like direnv.

## Managed rules

Optionally, install a Roboflow guidance block in your project's `CLAUDE.md`:

```bash
agents.sh --yes --host=claude-code-cli --project --rules-only
```

This writes the block between `<!-- BEGIN ROBOFLOW -->` / `<!-- END ROBOFLOW -->` markers — content outside the markers is preserved on re-runs and uninstall.

## Uninstall

```bash
claude plugin remove roboflow
# Optionally also remove the marketplace source:
claude plugin marketplace remove roboflow
```

Or via `agents.sh`:

```bash
agents.sh --yes --host=claude-code-cli --uninstall
```
