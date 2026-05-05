# Roboflow Agent Plugin

Agent-ready Roboflow skills plus MCP configuration for computer vision workflows: data management, training, evaluation, inference, model selection, Workflows, Universe, plans, and Roboflow platform APIs.

This repository is a plugin-shaped source of truth for AI agents (Claude Code, Codex, Cursor, OpenCode, and others). The canonical skill content lives in [`skills/`](skills/); plugin manifests point at those files instead of copying them elsewhere.

## Install as a plugin

The repo includes both plugin manifests:

- Codex: [`.codex-plugin/plugin.json`](.codex-plugin/plugin.json)
- Claude Code: [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json)

Both manifests load skills from [`skills/`](skills/) and bundle the Roboflow MCP server config from [`.mcp.json`](.mcp.json).

Set your Roboflow API key in the environment used by your agent before enabling the plugin:

```bash
export ROBOFLOW_API_KEY=YOUR_ROBOFLOW_API_KEY
```

The bundled MCP server connects to `https://mcp.roboflow.com/mcp` and sends the API key as the `x-api-key` header.

For local Claude Code plugin testing:

```bash
claude --plugin-dir .
```

## Install standalone skills

Install all skills:

```bash
npx skills add roboflow/computer-vision-skills
```

Install a single skill:

```bash
npx skills add roboflow/computer-vision-skills --skill inference
```

By default this installs into `./.claude/skills/` for the current project. Pass `-g` for `~/.claude/skills/` (global).

See [`vercel-labs/skills`](https://github.com/vercel-labs/skills) for the full CLI reference.

## Available skills

- **api-reference**: REST API and inference API references
- **data-management**: uploading images, labeling, dataset organization
- **inference**: running inference, workflows, workflow templates
- **plans-and-pricing**: Roboflow plans and credit usage
- **product-navigation**: where features live in the Roboflow product
- **training-and-evaluation**: training models and improving accuracy
- **universe**: searching and using Roboflow Universe

## Evals

This repo includes a lightweight eval harness for skill changes. Cases live in [`evals/cases/`](evals/cases/) and compare agent responses against expected and forbidden phrases.

List the smoke cases:

```bash
make eval-list
```

Preview the agent commands without running them:

```bash
make eval-dry-run AGENT=claude
```

Run the smoke suite against the current checkout:

```bash
make eval AGENT=claude SUITE=smoke
```

Compare two refs after the plugin layout exists on both refs:

```bash
make eval BASE=main CANDIDATE=HEAD AGENT=claude SUITE=smoke
```

## MCP and skills

The [Roboflow MCP server](https://mcp.roboflow.com/) should expose live tools for projects, images, annotations, versions, models, Workflows, Universe, and feedback. This plugin should own the expert guidance in skills.

That separation keeps the install model simple:

- MCP server: live Roboflow tools and authenticated API access
- Plugin skills: durable product guidance and workflow playbooks
- This repo: canonical source for skill updates and plugin distribution

## Contributing

Skills are markdown. Open a PR with edits or a new folder under [`skills/`](skills/). Each new skill must have a `SKILL.md` at its root with `name` and `description` frontmatter.

## License

Apache-2.0
