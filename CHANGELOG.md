# Changelog

## [1.0.0] - 2026-05-05

### Added
- `.claude-plugin/plugin.json` manifest — converts repo into a distributable Claude Code plugin
- `skills/` subdirectory — all 7 skill directories moved here following Claude Code plugin convention
- `when_to_use` frontmatter field on `roboflow-api-reference` skill for stronger trigger matching
- `.gitignore` covering IDE and local settings files

### Changed
- Cross-references updated from `roboflow://skills/<skill>/<page>` MCP URIs to relative markdown paths (works with or without the Roboflow MCP server connected)
- README updated with Claude Code plugin install instructions
