# Codex CLI

Codex CLI exposes `plugin marketplace add / upgrade / remove` but does not yet have a non-interactive `plugin install` command. The flow is:

```bash
codex plugin marketplace add roboflow/computer-vision-skills
```

Then restart Codex and open the plugin browser:

```text
codex /plugins
```

Pick the **Roboflow** marketplace source, select the **Roboflow** plugin, install it, and press <kbd>Space</kbd> if it shows installed-but-disabled.

## Via agents.sh

```bash
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=codex-cli
```

This adds the marketplace and prints the manual step you still need to complete inside Codex.

## Local clone workflow

When editing a local clone, register it as a local marketplace source:

```bash
git clone https://github.com/roboflow/computer-vision-skills
cd computer-vision-skills
codex plugin marketplace add .
```

Restart Codex after edits. If the plugin browser shows stale metadata, remove and re-add the local marketplace:

```bash
codex plugin marketplace remove roboflow
codex plugin marketplace add .
```

## API key

Codex CLI reads `ROBOFLOW_API_KEY` from the shell that launches the `codex` binary. In Codex desktop, set the key in the local environment used by the workspace. Use a project-scoped `.env` if you need different keys per project.

```bash
export ROBOFLOW_API_KEY=YOUR_KEY
```

## Caching gotcha

Codex caches installed plugins under `~/.codex/plugins/cache/`, so a running Codex session may not see edits until Codex is restarted or the plugin is reinstalled from the Plugin Directory.

## Uninstall

```bash
codex plugin marketplace remove roboflow
```

Then remove the plugin itself from `codex /plugins`.

Or via `agents.sh`:

```bash
agents.sh --yes --host=codex-cli --uninstall
```
