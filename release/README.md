# Plugin releases

Claude Code and Codex share a version because they ship the same default skills.
ChatGPT and Cowork have independent versions and release processes.

## Automatic Claude Code and Codex releases

Merge your skill or plugin change into `main`. No version bump or tag command
is needed in the PR. The **Plugin releases** workflow:

1. Checks out the latest `main`, including merges that arrived while it waited.
2. Compares the shipped plugin files with the latest `plugin-vX.Y.Z` release.
3. If they changed, increases the patch version in both manifests and commits
   those two files. The first run also creates an initial patch release.
4. Pushes the version commit and its tag together, atomically. A competing merge
   causes a retry against the latest `main`, never a force push.
5. Checks out the exact tag and builds the plugin ZIP and provenance JSON.
6. Creates a draft GitHub release containing both files.

Shipped files are `skills/`, `.mcp.json`, `.claude-plugin/`, `.codex-plugin/`,
`.agents/plugins/`, and `LICENSE`. Other documentation and ChatGPT-only changes
don't increase the Claude/Codex version. A retry reuses the existing tag and
commit; it can restore draft release assets without another version bump.
Published release assets are left intact.

Both the version commit and tag use `GITHUB_TOKEN`, so their pushes don't start
another workflow run. The build runs in this same workflow and doesn't rely on
the tag push triggering another run. See [GitHub's workflow trigger rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow).

The automatic job needs `contents: write` and permission to push to `main` and
create tags. No extra account secret is required. If repository rules later
block the bot's push, the workflow fails without publishing either ref. After
fixing access, rerun **Plugin releases** with **Run workflow** on `main`.
Do the same to recover a failed build or release upload; the existing version
and tag will be reused if the shipped files haven't changed.

Review the draft release and add user-facing release notes before publishing.
Claude users can receive the new skills when their marketplace and plugin
update, even before the GitHub draft is published, because they install from
`main`. Auto-update must be enabled in Claude's marketplace settings.

CI checks that both manifests agree and that a PR doesn't decrease versions.
For an intentional major or minor release, you can still set a higher version
in the PR:

```bash
python3 release/manage.py bump 2.0.0
```

The automatic release respects that higher version instead of adding a patch.
Versions use stable `X.Y.Z` numbers. Never move a release tag or reuse a version
for changed contents.

For local verification and a ZIP from a clean release checkout:

```bash
python3 -m unittest discover -s release -p 'test_*.py'
python3 release/manage.py check
python3 release/manage.py build plugin-v1.0.3
```

Outputs land in `release/build/`. The ZIP contains committed plugin files and
the license, excluding ChatGPT overrides and development tools. The provenance
records the version, source commit, and ZIP SHA-256.

## ChatGPT

Follow [`chatgpt/RELEASE.md`](../chatgpt/RELEASE.md) to prepare and review the
package contents, version, and release notes. Batch skill changes into a store
release rather than bumping ChatGPT for every skill PR. The automatic
Claude/Codex release does not change a ChatGPT version already under review.

After merging a prepared ChatGPT version, tag its commit, for example:

```bash
git fetch origin main
git tag chatgpt-v1.0.4 origin/main
git push origin chatgpt-v1.0.4
```

The workflow verifies that tag and runs Lean's existing ChatGPT tests and
builder. Download the ZIP and provenance from the draft GitHub release. Upload
that exact ZIP in the OpenAI dashboard, complete review and publication, and
record the source commit, checksum, and outcome in `chatgpt/CHANGELOG.md`.
Creating a GitHub release does not publish to the OpenAI store.
