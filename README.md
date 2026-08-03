# Roboflow Agent Plugin

Agent-ready Roboflow plugin that contains skills and MCP configuration for computer vision workflows: data management, training, evaluation, inference, model selection, Workflows, Universe, plans, and Roboflow platform APIs.

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

<details>
<summary>Per-project installation</summary>

For per-project isolation — for example, when different projects need different `ROBOFLOW_API_KEY` values for different workspaces:

```bash
claude plugin install roboflow --scope local
```

Local scope writes the plugin into the current project only and reads the API key from that project's environment.
</details>

<details>
<summary>Install from a local clone</summary>

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

</details>

### Codex

Add this repo as a marketplace source, then install the plugin from that marketplace.

Install from GitHub:

```bash
codex plugin marketplace add roboflow/computer-vision-skills
codex plugin add roboflow@roboflow
```

You can also install from the plugin browser after adding the marketplace:

```text
codex /plugins
```

Choose the **Roboflow** marketplace source, select the **Roboflow** plugin, install it, and press <kbd>Space</kbd> if it is installed but still disabled. Restart Codex after installing or upgrading a plugin so cached skill metadata is refreshed.

<details>
<summary>Local clone workflow</summary>

When editing a local clone, register it as a local marketplace source:

```bash
git clone https://github.com/roboflow/computer-vision-skills
cd computer-vision-skills
codex plugin marketplace add .
codex plugin add roboflow@roboflow
```

Restart Codex after edits. If Codex still shows stale metadata, upgrade the marketplace or remove and re-add it:

```bash
codex plugin marketplace upgrade roboflow
codex plugin marketplace remove roboflow
codex plugin marketplace add .
codex plugin add roboflow@roboflow
```

</details>

If you registered the GitHub marketplace source instead, refresh it with `codex plugin marketplace upgrade roboflow`.

<details>
<summary>What the Codex marketplace file does</summary>

Codex reads [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json), which points `source.path` at the repo root via `./`. Codex resolves `source.path` relative to the marketplace root, so the plugin manifest in [`.codex-plugin/plugin.json`](.codex-plugin/plugin.json), the skills in [`skills/`](skills/), and the Roboflow MCP server config in [`.mcp.json`](.mcp.json) are all loaded from this repository.

Codex caches installed plugins under `~/.codex/plugins/cache/`, so a running Codex session may not see edits until Codex is restarted or the plugin is reinstalled from the Plugin Directory.

</details>

Codex CLI picks up `ROBOFLOW_API_KEY` from the shell environment that launches the `codex` binary. In Codex desktop, set the key in the local environment used by the workspace. Use a project-scoped `.env` if you need different keys per project.

### One-line installer

The installer script registers this marketplace and installs the plugin for whichever supported agent CLIs it finds (`codex`, `claude`, or both). When using the published endpoint:

```bash
curl -fsSL https://repo.roboflow.com/agent-install/agent.sh | bash
```

PowerShell:

```powershell
iwr -useb https://repo.roboflow.com/agent-install/agent.ps1 | iex
```

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
- **cloud-storage**: connecting S3/GCS buckets to mirror images into a workspace
- **data-management**: uploading images, labeling, dataset organization
- **inference**: running inference, workflows, workflow templates
- **plans-and-pricing**: Roboflow plans and credit usage
- **product-navigation**: where features live in the Roboflow product
- **training-and-evaluation**: training models and improving accuracy
- **universe**: searching and using Roboflow Universe

## Try it

After installing, start with one of these prompts:

- "Build a Roboflow project for detecting defects in my manufacturing images."
- "Run my saved Roboflow Workflow on a test image and save visual outputs to disk."
- "Review my dataset and recommend the next model-training iteration."

## MCP and skills

The [Roboflow MCP server](https://mcp.roboflow.com/) exposes live tools for projects, images, annotations, versions, models, Workflows, Universe, and feedback. Skills own the expert guidance and workflow playbooks.

That separation keeps the install model simple:

- MCP server: live Roboflow tools and authenticated API access
- Plugin skills: durable product guidance and workflow playbooks
- This repo: canonical source for skill updates and plugin distribution

## Limitations

- Live MCP tools require `ROBOFLOW_API_KEY` in the environment used by your agent.
- Product routes, model availability, credit rates, and pricing can change; verify current commercial details at `roboflow.com/pricing`, `roboflow.com/credits`, or the in-app billing pages.
- Local skills are durable guidance, not a substitute for live MCP schema checks when a workflow block, API field, or tool parameter is uncertain.
- The installer scripts require the target agent CLI (`codex` or `claude`) to already be installed.

<details>
<summary>Get your API key</summary>

**Grab your Roboflow API key** from the Roboflow settings:
[app.roboflow.com/settings/api](https://app.roboflow.com/settings/api)

The key authenticates the bundled MCP server against `https://mcp.roboflow.com` via the `x-api-key` header.

Export it in the shell that launches your agent:

```bash
export ROBOFLOW_API_KEY=your_key
```

For persistence, add the `export` to your shell profile (`~/.zshrc`, `~/.bashrc`) or to a project-local `.env` file loaded by your agent's environment. Per-project isolation is the safer default — keeps separate workspaces and billing accounts from leaking across projects.

</details>

## Contributing

Skills are markdown. Open a PR with edits or a new folder under [`skills/`](skills/). Each new skill must have a `SKILL.md` at its root with `name` and `description` frontmatter.

Run the structural validator before opening a PR:

```bash
python3 scripts/validate_plugin.py
```

## License

Apache-2.0
