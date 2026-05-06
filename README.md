# Roboflow Agent Plugin

Agent-ready Roboflow skills plus MCP configuration for computer vision workflows: data management, training, evaluation, inference, model selection, Workflows, Universe, plans, and Roboflow platform APIs.

This repository is a plugin-shaped source of truth for AI agents (Claude Code, Codex, Cursor, OpenCode, and others). The canonical skill content lives in [`skills/`](skills/); plugin manifests point at those files instead of copying them elsewhere.

## Install as a plugin

The repo ships both plugin manifests pointing at the same skill content and MCP config:

- Claude Code: [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) — plugin name `roboflow`
- Codex: [`.codex-plugin/plugin.json`](.codex-plugin/plugin.json) — plugin name `roboflow`

Both manifests load skills from [`skills/`](skills/) and bundle the Roboflow MCP server config from [`.mcp.json`](.mcp.json).

### Claude Code

Install from GitHub — no clone required:

```bash
claude plugin marketplace add roboflow/computer-vision-skills
claude plugin install roboflow
```

The first command registers this repo as a marketplace source (run once per machine). The second installs the plugin.

For per-project isolation — for example, when different projects need different `ROBOFLOW_API_KEY` values for different workspaces:

```bash
claude plugin install roboflow --scope local
```

Local scope writes the plugin into the current project only and reads the API key from that project's environment.

**Alternative** — install from a local clone:

```bash
git clone https://github.com/roboflow/computer-vision-skills
claude plugin marketplace add ./computer-vision-skills
claude plugin install roboflow
```

For a throwaway test without touching the installed-plugins list:

```bash
cd computer-vision-skills
claude --plugin-dir .
```

### Codex

This repo includes a repo-scoped Codex marketplace file at [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json), so a local clone can be registered directly.

```bash
git clone https://github.com/roboflow/computer-vision-skills
cd computer-vision-skills
codex plugin marketplace add .
```

Restart Codex after adding the marketplace, then open `/plugins` to browse the `roboflow` entry.

For a remote marketplace source:

```bash
codex plugin marketplace add roboflow/computer-vision-skills
```

The current Codex CLI does not expose `codex plugin install` or `codex --plugin-dir`.

Codex picks up `ROBOFLOW_API_KEY` from the same shell environment that launches the `codex` binary. Use a project-scoped `.env` if you need different keys per project.

## Install standalone skills

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

## License

Apache-2.0
