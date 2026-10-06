# Roboflow Agent Plugin

Agent-ready Roboflow plugin that contains skills and MCP configuration for computer vision workflows: data management, training, evaluation, inference, model selection, Workflows, Universe, plans, and Roboflow platform APIs.

This repository is a plugin-shaped source of truth for AI agents (Claude Code, Codex, Cursor, OpenCode, and others). The canonical skill content lives in [`skills/`](skills/); plugin manifests point at those files instead of copying them elsewhere.

## Install as a plugin

The repo ships both plugin manifests pointing at the same skill content and MCP config:

- Claude Code: [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) — plugin name `roboflow`
- Codex: [`.codex-plugin/plugin.json`](.codex-plugin/plugin.json) — plugin name `roboflow`

Both manifests load skills from [`skills/`](skills/) and bundle the Roboflow MCP server config from [`.mcp.json`](.mcp.json).

The bundled connection uses OAuth: sign in to Roboflow when your client prompts
you. No API key is needed. Clients that cannot complete OAuth can configure the
[API-key fallback](#api-key-fallback).

### Microsoft Copilot Cowork

The [`cowork/`](cowork/) directory contains a Microsoft 365 app manifest, validation, and a Python-only package build that downloads a verified public tool catalog. It uses Roboflow's OAuth Dynamic Client Registration flow and produces a v1.28 package ready for tenant sideloading.

```bash
./cowork/build.sh
```

See [`cowork/README.md`](cowork/README.md) for build and installation instructions.

### Claude Code

Install from GitHub — no clone required:

```bash
claude plugin marketplace add roboflow/computer-vision-skills
claude plugin install roboflow
```

The first command registers this repo as a marketplace source (run once per machine). The second installs the plugin.

<details>
<summary>Per-project installation</summary>

To install the plugin only for the current project:

```bash
claude plugin install roboflow --scope local
```

Local scope controls where the plugin is installed. The bundled MCP connection
still uses OAuth; it does not automatically read a project API key.
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

The Codex CLI currently exposes `codex plugin marketplace add`, `upgrade`, and `remove`. It does not expose a direct `codex plugin install` command or a `codex --plugin-dir` flow, so add this repo as a marketplace source and install the plugin from the plugin browser.

Install from GitHub:

```bash
codex plugin marketplace add roboflow/computer-vision-skills
```

Restart Codex, then open the plugin browser:

```text
codex /plugins
```

Choose the **Roboflow** marketplace source, select the **Roboflow** plugin, install it, and press <kbd>Space</kbd> if it is installed but still disabled.

<details>
<summary>Local clone workflow</summary>

When editing a local clone, register it as a local marketplace source:

```bash
git clone https://github.com/roboflow/computer-vision-skills
cd computer-vision-skills
codex plugin marketplace add .
```

Restart Codex after edits. If the plugin browser still shows stale metadata, remove and re-add the local marketplace:

```bash
codex plugin marketplace remove roboflow
codex plugin marketplace add .
```

</details>

If you registered the GitHub marketplace source instead, refresh it with `codex plugin marketplace upgrade roboflow`.

<details>
<summary>What the Codex marketplace file does</summary>

Codex reads [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json), which points `source.path` at the repo root via `./`. Codex resolves `source.path` relative to the marketplace root, so the plugin manifest in [`.codex-plugin/plugin.json`](.codex-plugin/plugin.json), the skills in [`skills/`](skills/), and the Roboflow MCP server config in [`.mcp.json`](.mcp.json) are all loaded from this repository.

Codex caches installed plugins under `~/.codex/plugins/cache/`, so a running Codex session may not see edits until Codex is restarted or the plugin is reinstalled from the Plugin Directory.

</details>

The bundled Codex connection also uses OAuth. Setting `ROBOFLOW_API_KEY` alone
does not configure MCP authentication; API-key connections need an explicit
header configuration as described below.

## Install standalone skills

If you want the skills without the MCP server bundle — for example, with an agent that doesn't speak the plugin manifest format — install them directly:

```bash
npx skills add roboflow/computer-vision-skills
```

Install a single skill:

```bash
npx skills add roboflow/computer-vision-skills --skill roboflow-inference
```

By default this installs into `./.claude/skills/` for the current project. Pass `-g` for `~/.claude/skills/` (global).

The `npx skills` CLI works with any agent that reads `SKILL.md` files from `.claude/skills/` — Claude Code, Cursor, OpenCode, and others. See [`vercel-labs/skills`](https://github.com/vercel-labs/skills) for the full CLI reference.

## Available skills

- **roboflow-api-reference**: REST API and inference API references
- **roboflow-cloud-storage**: connecting S3/GCS buckets to mirror images into a workspace
- **roboflow-data-management**: uploading images, labeling, dataset organization
- **roboflow-inference**: running inference, workflows, workflow templates
- **roboflow-plans-and-pricing**: Roboflow plans and credit usage
- **roboflow-product-navigation**: where features live in the Roboflow product
- **roboflow-training-and-evaluation**: training models, diagnosing why a model underperforms, and improving accuracy
- **roboflow-universe**: searching and using Roboflow Universe
- **roboflow-workflow-evals**: measuring Workflows against ground truth, catching regressions, and comparing Workflows

## MCP and skills

The [Roboflow MCP server](https://mcp.roboflow.com/) exposes live tools for projects, images, annotations, versions, models, Workflows, Universe, and feedback. Skills own the expert guidance and workflow playbooks.

That separation keeps the install model simple:

- MCP server: live Roboflow tools and authenticated API access
- Plugin skills: durable product guidance and workflow playbooks
- This repo: canonical source for skill updates and plugin distribution

### API-key fallback

Use this only when your client cannot complete OAuth or you need a headless
API-key connection. Obtain a private key from
[Roboflow settings](https://app.roboflow.com/settings/api), then configure your
client to send it in the `x-api-key` header to `https://mcp.roboflow.com/mcp`.

For clients that support environment expansion in MCP JSON configuration:

```json
{
  "mcpServers": {
    "roboflow": {
      "type": "http",
      "url": "https://mcp.roboflow.com/mcp",
      "headers": {
        "x-api-key": "${ROBOFLOW_API_KEY}"
      }
    }
  }
}
```

Load `ROBOFLOW_API_KEY` into the environment of the process running the client,
using a secret manager or a gitignored `.env` that you explicitly load. A `.env`
file is not automatically loaded by this plugin. If your client uses a different
configuration format or does not expand environment variables, use its supported
secret-to-header configuration instead of this JSON example. Configure one
Roboflow connection, avoiding duplicate plugin and manual server entries.

When switching an existing OAuth connection to an API key, sign out of that
connection or clear its saved OAuth credentials so the client stops sending an
`Authorization: Bearer` header. The server prefers that header over `x-api-key`
when both are present, so adding the API-key header alone may still use the
OAuth workspace and permissions.

Never paste a private key into chat or commit it. To return to OAuth, remove the
API-key header configuration and reconnect.

## Contributing

Skills are markdown. Open a PR with edits or a new folder under [`skills/`](skills/). Each new skill must have a `SKILL.md` at its root with `name` and `description` frontmatter. Check your change with:

```bash
python3 .github/scripts/validate_skills.py
```

It enforces the folder-name match, the 20,000-character `SKILL.md` limit, at most 20 companion files, and working relative links.

`skills/roboflow-workflow-evals/reference/` is generated from each Workflow Evals engine release, which opens a draft `engine-sync` pull request here. Do not edit those files by hand. The draft is marked ready once production serves that engine version, and an older draft that a newer sync supersedes is closed.

## License

Apache-2.0
