# Plugin releases

Claude Code and Codex share a version because they ship the same default skills.
The Claude manifest is the version source; the release command updates both manifests.
ChatGPT and Cowork have independent versions and release processes.

## Claude Code and Codex

When changing `skills/`, `.mcp.json`, `.claude-plugin/`, `.codex-plugin/`, or
`.agents/plugins/`, increase the shared version in the same PR:

```bash
python3 release/manage.py bump 1.0.3
python3 release/manage.py check --base origin/main
python3 -m unittest discover -s release -p 'test_*.py'
```

Choose a version greater than the current versions in both manifests. Stable
`X.Y.Z` versions are supported. CI rejects mismatches, decreases, and shipped
changes without an increase. If another plugin change merges first, update the
PR's version again. Documentation outside the shipped paths and ChatGPT-only
changes don't require a Claude/Codex version bump.

Once merged, Claude users can receive the new skills when their marketplace and
plugin update. Auto-update must be enabled in Claude's marketplace settings.
The GitHub release is a downloadable record; clients installing from `main`
can receive the change before that release is published.

To record a release, tag the merged commit with its manifest version:

```bash
git fetch origin main
git tag plugin-v1.0.3 origin/main
git push origin plugin-v1.0.3
```

The **Plugin releases** workflow tests the tooling, verifies the tag version and
that the commit is on `main`, and builds a ZIP containing the committed plugin
files and license. It creates a draft GitHub release with the ZIP and a
provenance JSON containing the version, source commit, and ZIP SHA-256. Review
the draft and add user-facing release notes before publishing. Never move a
release tag or reuse a version for changed contents.

For a local artifact from a clean release checkout:

```bash
python3 release/manage.py build plugin-v1.0.3
```

Outputs land in `release/build/`. The archive excludes untracked and ignored
files, ChatGPT overrides, and development tools.

## ChatGPT

Follow [`chatgpt/RELEASE.md`](../chatgpt/RELEASE.md) to prepare and review the
package contents, version, and release notes. Batch skill changes into a store
release rather than bumping ChatGPT for every skill PR.

After merging, tag that commit with the ChatGPT manifest version, for example:

```bash
git fetch origin main
git tag chatgpt-v1.0.4 origin/main
git push origin chatgpt-v1.0.4
```

The same workflow verifies the tag and runs the existing ChatGPT tests and
builder. Download the ZIP and provenance from the draft GitHub release. Upload
that exact ZIP in the OpenAI dashboard, complete review and publication, and
record the source commit, checksum, and outcome in `chatgpt/CHANGELOG.md`.
Creating a GitHub release does not publish to the OpenAI store.

The workflow needs the standard `GITHUB_TOKEN` permission to write releases;
it needs no new account secret. Only the final job has `contents: write`, after
the build succeeds, and that job does not check out or execute repository code.
