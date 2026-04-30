# Roboflow and Computer Vision Skills

Agent-ready Skills for Roboflow and general computer vision workflows, covering data management, training, evaluation, inference, model selection, and Roboflow-specific topics like the platform APIs, Universe, and plans.

Each top-level directory is a Skill: expert knowledge packaged for AI agents (Claude Code, Cursor, Codex, OpenCode, and others). Skills follow the [Agent Skills](https://code.claude.com/docs/en/skills) convention: a `SKILL.md` with YAML frontmatter (`name`, `description`) plus optional supporting markdown pages.

## Install with `npx skills`

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

## Also exposed via MCP

These same skills are served as MCP resources by the [Roboflow MCP server](https://github.com/roboflow/roboflow-mcp) under URIs like `roboflow://skills/<skill>/SKILL`. Connected MCP clients can browse and read them on demand without installing anything locally.

## Contributing

Skills are markdown. Open a PR with edits or a new skill folder. Each new skill must have a `SKILL.md` at its root with `name` and `description` frontmatter.

## License

Apache-2.0
