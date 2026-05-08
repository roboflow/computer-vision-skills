# `agents.sh` Installer Reference

`agents.sh` configures your installed coding agents (Claude Code, Codex, and others as later phases land) to use Roboflow Skills, MCP, and rules.

For the user-facing one-liner, see the repo README. This document is the flag and host reference.

## Quick reference

```bash
# Interactive
curl -fsSL https://roboflow.com/agents.sh | bash

# Non-interactive
curl -fsSL https://roboflow.com/agents.sh | bash -s -- \
    --yes --host=claude-code-cli,codex-cli --api-key=$ROBOFLOW_API_KEY

# Dry run
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --dry-run --host=claude-code-cli

# Uninstall
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --uninstall

# Pin to a branch / tag while testing
ROBOFLOW_AGENTS_REF=installer curl -fsSL https://roboflow.com/agents.sh | bash
```

## Flags

| Flag | Effect |
|---|---|
| `--yes`, `-y` | No prompts; use defaults for any unspecified decision. |
| `--host=<id,...>` | Restrict to specific agent IDs. Comma-separated, repeatable. |
| `--all` | All detected agents. Implied with `--yes` if no `--host` is given. |
| `--skills-only`, `--mcp-only`, `--rules-only` | Component scope (Phase 2+ for non-plugin hosts). |
| `--no-skills`, `--no-mcp`, `--no-rules` | Negative scope. |
| `--global` | Default scope (per-user). |
| `--project` | Project-scoped install. Inline secrets blocked. |
| `--api-key=<key>` | Override key resolution. |
| `--workspace=<url>` | Pick a workspace from the Python SDK config. |
| `--inline-key` | Write the key literally. Global scope only. |
| `--auth-skip` | Skip auth wiring; install everything else. |
| `--update` | Reconcile-only mode. (A bare re-run also reconciles.) |
| `--uninstall` | Remove Roboflow-managed components. |
| `--dry-run` | Print plan without making changes. |
| `--force` | Override safety checks. |
| `--force-skill=<name>` | Overwrite a specific user-edited skill (Phase 2+). |
| `--version` | Print installer version + repo SHA. |
| `--help`, `-h` | Show usage. |

## Hosts

The installer dispatches to per-host adapters in `installer/hosts/`. Each adapter knows how to install, update, and uninstall the Roboflow integration for one host.

### Phase 1 (plugin path) — shipped

| ID | Kind | Detection | What the installer does |
|---|---|---|---|
| `claude-code-cli` | CLI | `claude` on PATH | `claude plugin marketplace add roboflow/computer-vision-skills` + `claude plugin install roboflow` |
| `codex-cli` | CLI | `codex` on PATH | `codex plugin marketplace add roboflow/computer-vision-skills`, then prints next steps for `/plugins` |

Both use Roboflow's published plugin manifests in this repo (`.claude-plugin/`, `.codex-plugin/`), which bundle the skills (`skills/`) and the MCP server config (`.mcp.json`). The installer's job is to spare users from typing two commands per host and to record the install in the central manifest.

### Phase 2 (config-file path) — shipped

| ID | Kind | Detection | MCP config path | Skills path |
|---|---|---|---|---|
| `cursor-desktop` | Desktop | `/Applications/Cursor.app` (mac), `~/.config/Cursor` (linux), `%LOCALAPPDATA%\Programs\cursor` (win) | `~/.cursor/mcp.json` (or `<project>/.cursor/mcp.json` with `--project`) | `~/.claude/skills/` (or `<project>/.claude/skills/`) |
| `claude-desktop` | Desktop | `/Applications/Claude.app` (mac), `~/.config/Claude` (linux), `%APPDATA%\Claude` (win) | `~/Library/Application Support/Claude/claude_desktop_config.json` (mac), `~/.config/Claude/claude_desktop_config.json` (linux), `%APPDATA%\Claude\claude_desktop_config.json` (win) | n/a (Claude Desktop has no skills support) |
| `copilot-cli` | CLI | `copilot` on PATH or `gh extension list` includes `gh-copilot` | `~/.copilot/mcp-config.json` | n/a (Copilot CLI has no skills support) |

Phase 2 hosts get the Roboflow MCP entry written into their config files. Skills (where supported) are copied from `skills/<name>/` into the destination dir, with a per-skill `.roboflow-install-manifest.json` sidecar carrying a content hash. Re-running `agents.sh` reconciles upstream changes against pristine local copies and preserves user-edited skills.

### Phase 4 (config-file path) — shipped

| ID | Kind | Detection | MCP config | Schema notes |
|---|---|---|---|---|
| `gemini-cli` | CLI | `gemini` on PATH | `~/.gemini/settings.json` | Standard `mcpServers` schema. MCP only. |
| `windsurf-desktop` | Desktop | `/Applications/Windsurf.app` (mac), `~/.codeium/windsurf` or `~/.config/Windsurf` (linux), `%LOCALAPPDATA%\Programs\Windsurf` (win) | `~/.codeium/windsurf/mcp_config.json` | Standard `mcpServers` schema. MCP only. |
| `vscode-copilot` | Desktop | `code` on PATH, or `/Applications/Visual Studio Code.app` (mac), `~/.vscode` (linux) | Project: `<project>/.vscode/mcp.json`. Global: `~/Library/Application Support/Code/User/mcp.json` (mac), `~/.config/Code/User/mcp.json` (linux), `%APPDATA%\Code\User\mcp.json` (win). | **Different schema**: `servers` (not `mcpServers`) + `inputs` array. Installer adds an `inputs[]` `promptString` so VS Code prompts for the API key on first use. `--inline-key` warns about committing secrets. |
| `opencode-cli` | CLI | `opencode` on PATH | `~/.config/opencode/opencode.json` | **Different schema**: `mcp` container + `type: "remote"`. JSONC technically supported; the installer refuses to edit if `//` or `/* */` comments are present unless `--force` (which overwrites). |

### Schema variations summary

| Container key | Server type | Hosts |
|---|---|---|
| `mcpServers` | `http` | Cursor, Claude Desktop, Copilot CLI, Gemini, Windsurf |
| `servers` (with `inputs[]`) | `http` | VS Code Copilot |
| `mcp` | `remote` | OpenCode |

## Authentication

Resolution precedence:

1. `--api-key=<key>` flag.
2. `$ROBOFLOW_API_KEY` env var.
3. Roboflow Python SDK config:
   - macOS / Linux: `~/.config/roboflow/config.json`
   - Windows: `~/roboflow/config.json` (== `%USERPROFILE%\roboflow\config.json`)
   - Override: `$ROBOFLOW_CONFIG_DIR`
   - Single-workspace configs are used directly. Multi-workspace prompts unless `--workspace=<url>` or `--yes` (which falls back to `RF_WORKSPACE`).
4. Interactive prompt (silent `read -s`). Skipped under `--yes` or `--auth-skip`.

The Roboflow MCP server reads `ROBOFLOW_API_KEY` from the environment of whatever shell launches your agent. If your shell doesn't already have it exported, the installer prints a reminder.

## Manifest

Installs are recorded at `~/.config/roboflow/installations.json` (or `$ROBOFLOW_CONFIG_DIR/installations.json`):

```json
{
  "schema_version": 1,
  "installer_version": "0.1.0",
  "installations": [
    {
      "host_id": "claude-code-cli",
      "component": "plugin",
      "scope": "global",
      "marketplace": "roboflow/computer-vision-skills",
      "plugin_name": "roboflow",
      "installed_at": "2026-05-07T20:00:00Z",
      "updated_at": "2026-05-07T20:00:00Z"
    }
  ]
}
```

This is what `--update` and `--uninstall` consult to know what to reconcile or remove. File mode is `0600` on Unix.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | OK |
| 1 | Install failure (one or more host adapters failed) |
| 2 | Invalid usage (unknown flag, unknown host id) |
| 3 | No supported coding agents detected or selected |
| 4 | Unsafe operation blocked (e.g. `--project --inline-key`) |

## Environment variables

| Var | Default | Purpose |
|---|---|---|
| `ROBOFLOW_API_KEY` | — | Read by adapters (priority 2) and by the MCP server at runtime. |
| `ROBOFLOW_CONFIG_DIR` | `~/.config/roboflow` | Override the Roboflow config directory (matches the Python SDK). |
| `ROBOFLOW_AGENTS_REF` | `main` | Branch/tag the bootstrap fetches the tarball from. |
| `ROBOFLOW_AGENTS_REPO` | `roboflow/computer-vision-skills` | Source repo for the bootstrap tarball and the Claude/Codex marketplace registration. |
| `XDG_CACHE_HOME` | `~/.cache` | Bootstrap-extracted installer caches under this dir. |
| `NO_COLOR` | unset | If set, the installer suppresses ANSI colors. |

## Testing

The installer has bats tests under `tests/bats/`:

```bash
brew install bats-core         # macOS
sudo apt-get install bats      # Ubuntu/Debian
bats tests/bats/
```

CI runs the suite on `ubuntu-latest` and `macos-latest`; see [`.github/workflows/installer.yml`](../.github/workflows/installer.yml).
