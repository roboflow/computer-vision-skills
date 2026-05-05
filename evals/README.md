# Roboflow Skill Evals

These evals run user-style prompts against the Roboflow skills/plugin and score the
agent response against expected and forbidden patterns.

## Commands

List cases:

```bash
make eval-list
```

Show the commands that would run without calling an agent:

```bash
make eval-dry-run AGENT=claude
```

Run the smoke suite against the current checkout:

```bash
make eval AGENT=claude SUITE=smoke
```

Compare two refs after the plugin layout exists on both refs:

```bash
make eval BASE=main CANDIDATE=HEAD AGENT=claude SUITE=smoke
```

Use Codex instead of Claude:

```bash
make eval AGENT=codex SUITE=smoke
```

## Case Format

Cases live in `evals/cases/<suite>.json`.

Each case has:

- `prompt`: the user-style task to ask the agent
- `expected.must_include`: phrases that must appear in the response
- `expected.must_include_any`: phrase groups where at least one must appear
- `expected.must_not_include`: phrases that must not appear
- optional regex equivalents: `must_include_regex`, `must_not_include_regex`

The runner writes JSONL results to `evals/runs/` by default. That directory is
ignored by git.
