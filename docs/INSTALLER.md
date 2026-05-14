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
| `--no-install-node` | Don't auto-install Node.js if `npx` is missing — fail with manual-install link instead. |
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
| `claude-code-cli` | CLI | `claude` on PATH | `claude plugin marketplace add roboflow/computer-vision-skills` + `claude plugin install roboflow` + **patch `~/.claude/plugins/cache/roboflow/roboflow/<version>/.mcp.json` to embed the resolved API key into the `mcp-remote` stdio bridge args**. Same install also feeds Claude Code in Claude Desktop (the Code tab). Requires `npx` (Node.js) — installer auto-installs if missing. |
| `codex-cli` | CLI | `codex` on PATH | `codex plugin marketplace add roboflow/computer-vision-skills`, then prints next steps for `/plugins` |

Both use Roboflow's published plugin manifests in this repo (`.claude-plugin/`, `.codex-plugin/`), which bundle the skills (`skills/`) and the MCP server config (`.mcp.json`). The installer's job is to spare users from typing two commands per host, embed the API key into the cached MCP config so authentication works without a `ROBOFLOW_API_KEY` env var, and record the install in the central manifest.

### Phase 2 (config-file path) — shipped

| ID | Kind | Detection | MCP config path | Skills path |
|---|---|---|---|---|
| `cursor-desktop` | Desktop | `/Applications/Cursor.app` (mac), `~/.config/Cursor` (linux), `%LOCALAPPDATA%\Programs\cursor` (win) | `~/.cursor/mcp.json` (or `<project>/.cursor/mcp.json` with `--project`) | `~/.claude/skills/` (or `<project>/.claude/skills/`) |
| `claude-desktop` | Desktop | `/Applications/Claude.app` (mac), `~/.config/Claude` (linux), `%APPDATA%\Claude` (win) | platform-specific `claude_desktop_config.json` — **stdio bridge via `mcp-remote`**, requires `npx` on PATH | n/a (Claude Desktop chat-tab has no skills; the Code tab is covered by `claude-code-cli`) |
| `copilot-cli` | CLI | `copilot` on PATH or `gh extension list` includes `gh-copilot` | `~/.copilot/mcp-config.json` | n/a (Copilot CLI has no skills support) |

Phase 2 hosts get the Roboflow MCP entry written into their config files. Skills (where supported) are copied from `skills/<name>/` into the destination dir, with a per-skill `.roboflow-install-manifest.json` sidecar carrying a content hash. Re-running `agents.sh` reconciles upstream changes against pristine local copies and preserves user-edited skills.

### Phase 5 — rules + polish

Phase 5 adds:

- **Managed-block rules** for hosts that consume project-level guidance files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`). The installer writes content between `<!-- BEGIN ROBOFLOW -->` / `<!-- END ROBOFLOW -->` markers — anything outside is preserved on re-runs and uninstall.
- **Cursor rule file** at `<project>/.cursor/rules/roboflow.mdc` (Cursor's per-rule format — Roboflow owns the file in full).

Rules install only at `--project` scope (they're inherently project-level). Pass `--rules-only` to install nothing else, or `--no-rules` to skip them.

Templates live in [`templates/rules/`](../templates/rules/).

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
| `mcpServers` | `http` | Cursor, Copilot CLI, Gemini, Windsurf |
| `mcpServers` | stdio (`command:npx args:[…mcp-remote…]`) | Claude Code plugin (CLI + Code tab in Claude Desktop), Codex plugin, Claude Desktop chat-tab — all via the `mcp-remote` bridge |
| `servers` (with `inputs[]`) | `http` | VS Code Copilot |
| `mcp` | `remote` | OpenCode |

### Why some hosts need the stdio bridge

Claude Desktop's plugin runner (used by both the Code tab inside Claude Desktop and by Claude Code CLI's plugin install) suppresses plugin-declared HTTP MCPs at load time — it expects HTTP MCPs to flow through the cloud Connector subsystem at `claude.ai/customize/connectors`. To get the same behavior end-to-end without waiting for a Roboflow Connector listing, the plugin's `.mcp.json` declares a stdio bridge: `npx -y mcp-remote@<ver> https://mcp.roboflow.com/mcp --header x-api-key:<key>`. This requires Node.js + npx on the user's machine; the installer auto-installs Node when missing.

Claude Desktop's chat tab uses the same bridge mechanism — its config schema only accepts stdio MCPs anyway, and env-var expansion in args isn't reliable, so the literal key gets inlined.

## Authentication

Resolution precedence:

1. `--api-key=<key>` flag.
2. `$ROBOFLOW_API_KEY` env var.
3. Roboflow Python SDK config:
   - macOS / Linux: `~/.config/roboflow/config.json`
   - Windows: `~/roboflow/config.json` (== `%USERPROFILE%\roboflow\config.json`)
   - Override: `$ROBOFLOW_CONFIG_DIR`
   - Single-workspace configs are used directly. **Multi-workspace prompts interactively** with `RF_WORKSPACE` as the default selection, or non-interactively uses `RF_WORKSPACE` under `--yes` (with `--workspace=<url>` to override).
4. Interactive prompt (silent `read -s`). Skipped under `--yes` or `--auth-skip`.

### Inlining vs placeholder

| Scope | Default | Effect |
|---|---|---|
| `--global` (default) | **Literal key** baked into config | Just works, no env var setup needed. Files live in `$HOME` (mode 0644) — not in version control. |
| `--project` | `${ROBOFLOW_API_KEY}` placeholder | Project config files are commit-able; default avoids leaking secrets. The runtime needs `ROBOFLOW_API_KEY` set. |
| `--project --inline-key` | Literal key + warning | Explicit opt-in for "yes, write the literal key into the project file." |
| `vscode-copilot --project` | `${input:roboflow_api_key}` | VS Code prompts you for the key on first MCP use; never written to disk. |

For Claude Desktop's chat tab, the literal key is **always** inlined (its schema doesn't expand env vars in MCP args). The installer refuses to write a config without a resolvable key.

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
