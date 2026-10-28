# Editing skills

The skills in [`skills/`](skills/) are the default text. Claude, Codex, Cowork, standalone installs and the Roboflow MCP server all read them as they are. Edit them there.

## The ChatGPT layer

The ChatGPT plugin is built from the same skills, with two differences kept in [`chatgpt/`](chatgpt/):

- [`chatgpt/skills/`](chatgpt/skills/) holds ChatGPT versions of a few files, at the same path as the default file. When the package is built, each one replaces its default file. Every other file comes from `skills/` unchanged.
- [`chatgpt/exclude.txt`](chatgpt/exclude.txt) lists skills left out of the ChatGPT package entirely.

These exist because the ChatGPT plugin connects to `https://mcp.roboflow.com/openai/mcp`, which hides some tools that `/mcp` exposes. [`chatgpt/tools.json`](chatgpt/tools.json) lists the tools that surface hides, copied from `OPENAI_SURFACE.hidden_tools` in `src/roboflow_mcp/core/surfaces.py` of the roboflow-mcp repo.

## When you edit a skill

1. Edit the file in `skills/`.
2. If the same path exists in `chatgpt/skills/`, decide whether the change applies to the ChatGPT version too, and make it there as well. CI lists default files that changed without their ChatGPT version, as a reminder.
3. The ChatGPT version must not name any tool in the `hidden` list of `chatgpt/tools.json`. If the default text needs a hidden tool, the ChatGPT version describes another way to do it (for example, saving a Workflow and running it with `workflows_run` instead of running an inline specification).
4. If a new or changed skill depends on hidden tools for its whole flow, add it to `chatgpt/exclude.txt` instead.
5. Build locally to check:

   ```bash
   python3 chatgpt/build.py
   python3 -m unittest discover -s chatgpt -p 'test_*.py'
   ```

   The build fails if the ChatGPT package names a hidden tool, links to a missing or excluded file, has invalid skill frontmatter, or breaks OpenAI's listing rules.

## Writing for every client

- Use `skill://roboflow/<name>/SKILL.md` for MCP skill entrypoints and `skill://roboflow/<name>/<page>.md` for supporting pages. These are the file URIs advertised in the server manifest for native skills, resource reads, and the `read_skill` fallback.

- Never put an API key in a URL or a command argument. Read it from the `ROBOFLOW_API_KEY` environment variable.
- Ask the user before uploading data in bulk, starting paid jobs, deleting data, or changing shared settings.
- Don't name tools that don't exist. Check the tool name against the MCP server before writing it.
