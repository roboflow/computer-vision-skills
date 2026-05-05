# Roboflow and Computer Vision Skills

Agent-ready Skills for Roboflow and general computer vision workflows, covering data management, training, evaluation, inference, model selection, and Roboflow-specific topics like the platform APIs, Universe, and plans.

Each directory under `skills/` is a Skill: expert knowledge packaged for AI agents (Claude Code, Cursor, Codex, OpenCode, and others). Skills follow the [Agent Skills](https://code.claude.com/docs/en/skills) convention: a `SKILL.md` with YAML frontmatter (`name`, `description`) plus optional supporting markdown pages.

## Install as a Claude Code Plugin

This repo is a Claude Code plugin. Install it from the [Claude Code marketplace](https://claude.ai/settings/plugins) or run it locally for development:

```bash
# Test locally without installing
claude --plugin-dir ./path/to/computer-vision-skills

# After adding the marketplace, install via the Claude Code CLI
claude plugin install computer-vision-skills@<marketplace-name>
```

Once installed, the plugin:
- Auto-connects the **Roboflow MCP server** (`https://mcp.roboflow.com/mcp`) so tools like `models_infer`, `workflows_run`, and `universe_search` work immediately
- Prompts for your **Roboflow API key** on first use (stored in OS keychain via plugin settings)
- Skills trigger automatically on matching intents, or manually via `/computer-vision-skills:<skill-name>`

### Per-project API keys

Different workspaces need different API keys. Two options:

**Option A — install with local scope** (recommended for per-project isolation):
```bash
claude plugin install computer-vision-skills --scope local
# Then set the key for this project only via plugin settings
```

**Option B — use the setup skill** (writes to `.env`):
```bash
# After plugin is installed, run:
/computer-vision-skills:roboflow-setup YOUR_API_KEY
```

The setup skill writes `ROBOFLOW_API_KEY` to `.env` in the current directory, checks current auth state, and warns if `.env` is not gitignored.

## Install with `npx skills`

Install all skills into a project:

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
- **roboflow-setup**: configure API key globally or per-project
- **training-and-evaluation**: training models and improving accuracy
- **universe**: searching and using Roboflow Universe

## Roboflow MCP server

The plugin bundles the [Roboflow MCP server](https://github.com/roboflow/roboflow-mcp) via `.mcp.json`. When the plugin is enabled, Claude can call tools like `models_infer`, `workflows_run`, `universe_search`, and 20+ others directly — no separate MCP setup needed.

The API key is read from `user_config.roboflow_api_key` (set via plugin settings, stored in OS keychain).

## Contributing

Skills are markdown. Open a PR with edits or a new skill folder. Each new skill must have a `SKILL.md` at its root with `name` and `description` frontmatter.

## License

Apache-2.0
