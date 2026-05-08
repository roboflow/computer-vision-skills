# Roboflow Agent Plugin

Agent-ready Roboflow skills plus MCP configuration for computer vision workflows: data management, training, evaluation, inference, model selection, Workflows, Universe, plans, and Roboflow platform APIs.

This repository is a plugin-shaped source of truth for AI agents (Claude Code, Codex, Cursor, Windsurf, Gemini, Copilot, OpenCode, and others). The canonical skill content lives in [`skills/`](skills/); plugin manifests point at those files instead of copying them elsewhere.

## Quick install

The fastest path: one command configures every coding agent it finds on your machine.

```bash
# macOS / Linux
curl -fsSL https://roboflow.com/agents.sh | bash

# Windows PowerShell
irm https://roboflow.com/agents.ps1 | iex
```

The script detects which agents you have, asks what to install, and uses each agent's preferred mechanism — plugin install for Claude Code and Codex, config-file writes for everyone else.

Non-interactive variants:

```bash
# All detected agents, skip every prompt
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes

# Just one agent
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --yes --host=claude-code-cli

# Preview without writing
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --dry-run

# Uninstall
curl -fsSL https://roboflow.com/agents.sh | bash -s -- --uninstall
```

Full flag reference: [`docs/INSTALLER.md`](docs/INSTALLER.md).

## Per-agent install instructions

If you'd rather wire a single agent up by hand (or want to know exactly what `agents.sh` is doing for your host), each one has a dedicated guide:

- [Claude Code](docs/per-agent/claude-code.md) — `claude plugin install`
- [Claude Desktop](docs/per-agent/claude-desktop.md) — `claude_desktop_config.json`
- [Codex CLI](docs/per-agent/codex.md) — `codex plugin marketplace add` + `/plugins`
- [Cursor](docs/per-agent/cursor.md) — `~/.cursor/mcp.json` + `~/.claude/skills/`
- [GitHub Copilot CLI](docs/per-agent/copilot-cli.md) — `~/.copilot/mcp-config.json`
- [Gemini CLI](docs/per-agent/gemini-cli.md) — `~/.gemini/settings.json`
- [Windsurf](docs/per-agent/windsurf.md) — `~/.codeium/windsurf/mcp_config.json`
- [VS Code Copilot](docs/per-agent/vscode-copilot.md) — `<project>/.vscode/mcp.json` (servers + inputs schema)
- [OpenCode CLI](docs/per-agent/opencode.md) — `~/.config/opencode/opencode.json` (mcp + remote schema)

## Standalone skills

If you want the skills without the MCP server bundle — for example, with an agent that doesn't speak the plugin manifest format — install them directly:

```bash
npx skills add roboflow/computer-vision-skills
```

Install a single skill:

```bash
npx skills add roboflow/computer-vision-skills --skill inference
```

By default this installs into `./.claude/skills/` for the current project. Pass `-g` for `~/.claude/skills/` (global).

The `npx skills` CLI works with any agent that reads `SKILL.md` files from `.claude/skills/` — Claude Code, Cursor, OpenCode, and others. See [`vercel-labs/skills`](https://github.com/vercel-labs/skills) for the full CLI reference.

## Available skills

- **api-reference**: REST API and inference API references
- **data-management**: uploading images, labeling, dataset organization
- **inference**: running inference, workflows, workflow templates
- **plans-and-pricing**: Roboflow plans and credit usage
- **product-navigation**: where features live in the Roboflow product
- **training-and-evaluation**: training models and improving accuracy
- **universe**: searching and using Roboflow Universe

## MCP and skills

The [Roboflow MCP server](https://mcp.roboflow.com/) exposes live tools for projects, images, annotations, versions, models, Workflows, Universe, and feedback. Skills own the expert guidance and workflow playbooks.

That separation keeps the install model simple:

- MCP server: live Roboflow tools and authenticated API access
- Plugin skills: durable product guidance and workflow playbooks
- This repo: canonical source for skill updates and plugin distribution

<details>
<summary>Get your API key</summary>

Grab your Roboflow API key from the workspace settings page:

```text
https://app.roboflow.com/{workspace}/settings/api
```

Replace `{workspace}` with your workspace slug. The key authenticates the bundled MCP server against `https://mcp.roboflow.com/mcp` via the `x-api-key` header.

Export it in the shell that launches your agent:

```bash
export ROBOFLOW_API_KEY=YOUR_ROBOFLOW_API_KEY
```

For persistence, add the `export` to your shell profile (`~/.zshrc`, `~/.bashrc`) or to a project-local `.env` file loaded by your agent's environment. Per-project isolation is the safer default — keeps separate workspaces and billing accounts from leaking across projects.

</details>

## Contributing

Skills are markdown. Open a PR with edits or a new folder under [`skills/`](skills/). Each new skill must have a `SKILL.md` at its root with `name` and `description` frontmatter.

The installer (`agents.sh`, `agents.ps1`, and the modules under [`installer/`](installer/)) is also Apache-2.0 — see [`docs/INSTALLER.md`](docs/INSTALLER.md) for an architecture overview and [`tests/bats/`](tests/bats/) / [`tests/pester/`](tests/pester/) for the test suites.

## License

Apache-2.0
