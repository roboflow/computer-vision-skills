# Releasing a ChatGPT plugin version

Follow these steps when asked to prepare a new version of the Roboflow ChatGPT plugin. Each version needs an OpenAI review, so batch skill and listing changes into occasional versions. Hosted MCP tool changes reach ChatGPT without a new version.

## 1. Refresh the hidden tool list

Open `src/roboflow_mcp/core/surfaces.py` on the `main` branch of the roboflow-mcp repo and read `hidden_tools` in `OPENAI_SURFACE`. If it differs from `hidden` in `chatgpt/tools.json`, replace the list (sorted) and set `mcp_commit` to the roboflow-mcp commit you read it from. Make sure that commit is deployed, since ChatGPT sees the deployed server.

## 2. Carry over default changes

Take the "Skills baseline" commit of the latest version in `CHANGELOG.md` and list what changed in the default skills since then:

```bash
git diff --stat <baseline>..HEAD -- skills/
```

For every changed file that has a version in `chatgpt/skills/`, bring the relevant change into the ChatGPT version. New skills are included automatically unless they are listed in `chatgpt/exclude.txt`.

## 3. Build and fix

```bash
python3 chatgpt/build.py
```

- For each hidden tool the build reports, rewrite that passage in the ChatGPT version of the file (create it in `chatgpt/skills/` by copying the default file first). Describe a flow that uses visible tools.
- If a skill's whole flow depends on hidden tools, add it to `chatgpt/exclude.txt` instead.
- Check that every tool the ChatGPT package names still exists. A stale name is usually wrong for every client, so fix it in `skills/`.

## 4. Review the content

Read the assembled skills in `chatgpt/build/` against the [OpenAI plugin guidelines](https://developers.openai.com/plugins/plugin-guidelines):

- No API keys in URLs, command arguments or code literals. Use the `ROBOFLOW_API_KEY` environment variable.
- No creating API keys unless the user asks for one.
- No plan tables, prices, upgrade prompts or purchase paths. Factual explanations of credits are fine.
- No comparative or unverifiable claims.

Fix problems in `skills/` when they're wrong for every client, otherwise in `chatgpt/skills/`.

## 5. Version and notes

- Bump `version` in `chatgpt/plugin/plugin.json`. Never reuse a version number for a different package.
- Update `extensions.com.openai.publication.release_notes` in `plugin.json` with what changed for users.
- Add an entry to `chatgpt/CHANGELOG.md` with the status, the user-facing changes, the skills baseline (the commit you diffed against in step 2), and the roboflow-mcp commit in `tools.json`.

## 6. Check the review material

- Run each positive test case in `plugin.json` with a dedicated reviewer account and confirm the result matches `expected_behavior`.
- Confirm each negative test case leaves the plugin unused.
- Confirm the demo recording still matches the plugin.
- Confirm the tools in the test cases exist on production `/openai/mcp`. The build only checks that they aren't hidden.

Reviewer credentials go only in the OpenAI dashboard, never in the repo.

## 7. Merge and build

1. Open a PR with the changes. CI builds and validates the package.
2. After merge, build from a clean checkout of the merge commit:

   ```bash
   python3 chatgpt/build.py --commit "$(git rev-parse HEAD)"
   ```

   The ZIP and its provenance file land in `chatgpt/build/`.

## 8. Submit and record

A person uploads `chatgpt/build/roboflow-chatgpt-<version>.zip` in the OpenAI dashboard, waits for the review and clicks **Publish plugin**. Then update the version's entry in `chatgpt/CHANGELOG.md` with the outcome (submitted, approved, published, or rejected with the reason), and set its "Skills baseline" to the merge commit the ZIP was built from, with the `package_sha256` from the provenance file. The next version diffs from that baseline.
