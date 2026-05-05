# Changelog

## [1.0.0] - 2026-05-05

### Added
- `.claude-plugin/plugin.json` — Claude Code plugin manifest; bundles skills + MCP + API key config
- `.codex-plugin/plugin.json` — Codex plugin manifest; same skills + MCP via env var auth
- `skills/` subdirectory — all 8 skill directories (shared by both plugins)
- `.mcp.json` — Roboflow MCP server for Claude Code (`${user_config.roboflow_api_key}`)
- `.mcp.codex.json` — Roboflow MCP server for Codex (`$ROBOFLOW_API_KEY` env var)
- `userConfig.roboflow_api_key` in Claude Code plugin.json — API key in OS keychain
- `skills/roboflow-setup` — per-project API key setup; works for both Claude Code and Codex
- `AGENTS.md` — Codex project context (equivalent of CLAUDE.md)
- `when_to_use` frontmatter on `roboflow-api-reference` for stronger trigger matching
- `.gitignore` covering IDE and local settings files

### Changed
- Cross-references updated from `roboflow://skills/<skill>/<page>` MCP URIs to relative markdown paths
- README updated with both Claude Code and Codex plugin install instructions
