# computer-vision-skills — Agent Instructions

## Skill Editing Rule

**All skill edits happen in this project, never in the plugin cache.**

When asked to create, edit, or update any skill:

- **Write to**: `skills/<skill-name>/SKILL.md` (relative to repo root)
- **Never write to**: `~/.claude/plugins/cache/roboflow/**` or any path outside this repo

The plugin cache is a read-only install artifact — changes there are overwritten on next `claude plugin install`. This repo is the canonical source.

## Gate Rule — Secret Files Must Be Gitignored

**Before any operation that creates `.claude/settings.local.json` or `.codex/config.toml` in a project with git initialized:**

1. Verify the file path is present in `.gitignore` — if not, add it immediately before writing the file.
2. Never commit `.claude/settings.local.json` or `.codex/config.toml` under any circumstances.
3. This rule is unconditional — no exceptions, no user override.
