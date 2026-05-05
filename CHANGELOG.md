# Changelog

## [1.0.0] - 2026-05-05

### Added
- `.claude-plugin/plugin.json` manifest — converts repo into a distributable Claude Code plugin
- `skills/` subdirectory — all 7 skill directories moved here following Claude Code plugin convention
- `.mcp.json` — bundles Roboflow MCP server (`https://mcp.roboflow.com/mcp`) so it auto-connects when the plugin is enabled
- `userConfig.roboflow_api_key` in plugin.json — API key stored securely in OS keychain, referenced by `.mcp.json`
- `skills/roboflow-setup` — skill to configure per-project API key; writes `ROBOFLOW_API_KEY` to `.env` and explains global vs project-scoped auth options
- `when_to_use` frontmatter field on `roboflow-api-reference` skill for stronger trigger matching
- `.gitignore` covering IDE and local settings files

### Changed
- Cross-references updated from `roboflow://skills/<skill>/<page>` MCP URIs to relative markdown paths (works with or without the Roboflow MCP server connected)
- README updated with Claude Code plugin install instructions
