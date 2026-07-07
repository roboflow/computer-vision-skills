# Repository Review — `computer-vision-skills`

**Date:** 2026-07-06 · **Branch:** `japrescott/auckland` (clean, at `3c5b8fd`)
**Scope:** full review of code, tests, and docs — all 33 tracked files (~4,000 lines).

**Verification method:** every skill page, manifest, script, and workflow was read in full.
Factual claims were cross-checked where possible against the local Roboflow source mirrors
(`~/.claudeflow/repos/inference`, `roboflow-python`, `roboflow-mcp`, synced 2026-07-02) and
against git metadata. A link-checker was run over all relative markdown links (all resolve).
Confidence = probability the finding is real and the suggested fix is correct.

---

## Summary

The repo is in good shape for what it is — a docs-as-plugin distribution with one asset
script and one CI workflow. Content quality is high and internally consistent in most places.
The important findings are:

1. **The bundled `.mcp.json` almost certainly doesn't authenticate the way the README says it does** (no header mapping).
2. **`poll_batch_job.py` is not executable in git**, contradicting its own docstring and the docs that tell users to invoke it directly.
3. **`rf.universe(...)` in the product-navigation docs is not a real SDK API.**
4. **There is zero automated validation** — no CI lint/link/JSON/frontmatter checks and no tests for the Python script.
5. Several **internal contradictions** between skill pages (inline-spec policy, YOLO-NAS sizes, hard-coded pricing).

---

## A. Bugs

### A1. `.mcp.json` has no auth header mapping — bundled MCP auth likely broken or misleading

- **File:** `.mcp.json` · **Severity: High** · **Confidence: 85%**
- The config is only `{"type": "http", "url": "https://mcp.roboflow.com/mcp", "note": ...}`. The `note` claims setting `ROBOFLOW_API_KEY` in the agent environment authenticates plugin-managed requests, and `README.md:153` says the key authenticates "via the `x-api-key` header". But nothing in the config maps the env var to a header — MCP clients do not automatically forward arbitrary env vars as headers. The `roboflow-mcp` server's own README documents exactly two auth modes: OAuth (bare URL, interactive sign-in) or an explicit `"headers": {"x-api-key": ...}` block.
- **Failure scenario:** a user installs the plugin, exports `ROBOFLOW_API_KEY` as instructed, runs headless (no OAuth prompt possible) → every MCP tool call is unauthenticated and fails.
- **Resolution:** use env-var expansion in the config, which Claude Code supports in `.mcp.json` headers:
  ```json
  {
    "mcpServers": {
      "roboflow": {
        "type": "http",
        "url": "https://mcp.roboflow.com/mcp",
        "headers": { "x-api-key": "${ROBOFLOW_API_KEY}" }
      }
    }
  }
  ```
  If OAuth is the intended primary path, say so in the README and demote the env-var instructions to a "headless / API-key fallback" section. Verify expansion behaves the same in Codex before shipping one shared file. Also note `"note"` is not a standard `.mcp.json` key (harmless, but move the text to README if any client validates strictly).

### A2. `poll_batch_job.py` is not executable — docs and docstring say it is

- **Files:** `skills/inference/bin/poll_batch_job.py:4` and `skills/inference/batch-jobs.md:69` · **Severity: Medium** · **Confidence: 98%**
- Verified: `git ls-files -s` shows mode `100644`. The docstring says "shebang + exec bit set in git" and `batch-jobs.md` instructs `skills/inference/bin/poll_batch_job.py JOB_ID` as the primary invocation — which fails with `Permission denied` on every fresh clone/install.
- **Resolution:** `git update-index --chmod=+x skills/inference/bin/poll_batch_job.py` and commit. (The `python …` fallback in the docs works meanwhile.)

### A3. `rf.universe(...)` does not exist in the `roboflow` Python SDK

- **File:** `skills/product-navigation/features-by-page.md:100` · **Severity: Medium** · **Confidence: 90%**
- The "Download dataset" row suggests `rf.universe(user, proj).version(v).download(fmt)`. Verified against the `roboflow-python` mirror: the `Roboflow` class exposes `auth()` and `workspace()` only; there is no `universe` attribute anywhere in the package. An agent following this skill will emit code that raises `AttributeError`.
- **Resolution:** replace with the working pattern, e.g. `rf.workspace(user).project(proj).version(v).download(fmt)`, or defer to the copy-paste snippet Universe shows on its Download page.

### A4. Broken markdown table row silently drops content (RF-DETR Seg note)

- **File:** `skills/training-and-evaluation/SKILL.md:44` · **Severity: Low** · **Confidence: 95%**
- The Instance Segmentation table declares 3 columns but the RF-DETR Seg row has 4 cells; the fourth ("Pico and Base not available for seg") is dropped or misrendered by most renderers — and it's exactly the caveat that prevents an agent from requesting a non-existent `rfdetr-seg-pico`.
- **Resolution:** add a `Notes` column to the table (with empty cells for other rows) or move the caveat to a line below the table.

### A5. YOLO-NAS sizes contradict their own model-ID list

- **File:** `skills/training-and-evaluation/SKILL.md:35` vs `:112` · **Severity: Low** · **Confidence: 90%**
- Architecture table says YOLO-NAS comes in "Small, Medium"; the Model ID Reference lists `yolo_nas_s`, `yolo_nas_m`, **`yolo_nas_l`**. One of the two is wrong, and the page itself warns "Do not guess — wrong IDs cause training failures."
- **Resolution:** confirm against the Train UI and make both entries agree.

### A6. `api-reference/inference.md` recommends `workflow_specs_run`, contradicting the repo-wide "exception only" policy

- **File:** `skills/api-reference/inference.md:5` and `:67` · **Severity: Medium** · **Confidence: 95%**
- `inference/SKILL.md` and `workflows.md` repeatedly establish that inline specs (`workflow_specs_run`) are an exception requiring explicit user authorization, with `workflows_run` as the default. This page tells agents to "prefer … `workflow_specs_run` / `workflows_run`" (listing the exception first) and, in the Visualization section, flatly recommends "use `workflow_specs_run` with a visualization block". Since skills are consumed piecemeal by agents, whichever page loads decides behavior — this one trains the opposite habit.
- **Resolution:** reword both spots to name `workflows_run` as the tool of choice and reference the inline-spec exception policy.

### A7. `poll_batch_job.py` robustness gaps

- **File:** `skills/inference/bin/poll_batch_job.py` · **Severity: Medium** · **Confidence: 90%**
- Verified the good news first: `get_workspace`, `get_batch_job_metadata`, and the `current_stage` / `is_terminal` / `error` / `last_notification` fields all exist in `inference_cli` — the core logic is sound. Remaining issues:
  1. **No error handling around API calls** (lines 104, 110). One transient network blip mid-poll kills the script with a traceback and exit code 1 — the same code the docstring reserves for "job reported terminal error", so automation can't tell "job failed" from "poller crashed".
  2. **`--interval` accepts 0 or negatives** → tight loop hammering the API.
  3. **Imports from `inference_cli.lib.…` internals** — a private, unversioned surface (`pip install inference-cli` is unpinned in the docs). The CLI already schedules breaking removals (e.g. `--machine-size` gone in 0.42.0), so this can break without notice.
- **Resolution:** (1) wrap the poll call in try/except, retry transient failures a bounded number of times, and use a distinct exit code (e.g. 3) for poller errors; (2) `parser.error(...)` when `interval <= 0` (and clamp a sane floor, e.g. 5s); (3) pin a tested range in the docs (`pip install "inference-cli>=X,<Y"`) and add a smoke test (see C1).

### A8. Placeholder installers are published to production endpoints

- **Files:** `agent-install/agent.sh`, `agent-install/agent.ps1`, `.github/workflows/publish-agent-install.yml` · **Severity: Medium** · **Confidence: 95%**
- Both scripts are explicit `TODO` placeholders, yet the workflow ships them on every push to `main` to three GCS buckets behind `repo.roboflow.com/agent-install/agent.sh` — a URL the script header itself advertises as `curl … | bash`. Users who run it get a successful (exit 0) no-op, which reads as "installed" when nothing happened.
- **Resolution:** until real install logic lands, make the placeholders `exit 1` with a "not yet available" message so failure is unambiguous, or gate the publish job off. Longer term, publish a checksum alongside the script and reference it in docs to mitigate the inherent `curl | bash` risk.

---

## B. Documentation gaps & inconsistencies

### B1. Skill frontmatter `name` doesn't match directory names

- **Files:** every `skills/*/SKILL.md` · **Severity: Medium** · **Confidence: 70%**
- Frontmatter names are `roboflow-inference`, `roboflow-api-reference`, etc., while directories are `inference`, `api-reference`. The agent-skills convention is that `name` matches the directory. Depending on which the loader honors, installed skills surface either as `roboflow:inference` (frontmatter ignored) or the stuttering `roboflow:roboflow-inference` — and the repo's own source-of-truth notes promise users will see `roboflow:<name>`. The README's "Available skills" list uses directory names, adding a third variant.
- **Resolution:** pick one canonical name per skill. Since the plugin prefix already provides the `roboflow:` namespace, renaming frontmatter to match directories (`name: inference`) is the cleaner fix; then verify what `claude plugin install` actually displays and align README + in-page notes.

### B2. Three sub-pages carry skill-style frontmatter; five don't

- **Files:** `data-management/labeling.md`, `training-and-evaluation/active-learning.md`, `training-and-evaluation/improvement-playbook.md` (have `name`/`description` frontmatter) vs `inference/workflows.md`, `workflow-templates.md`, `local-tooling.md`, `batch-jobs.md`, `batch-staging.md`, `api-reference/*.md` (don't) · **Severity: Low** · **Confidence: 85%**
- Only `SKILL.md` defines a skill; frontmatter on supporting pages is at best ignored and at worst picked up by looser loaders (`npx skills`, Cursor, OpenCode) as three phantom extra skills with names (`roboflow-labeling`, `roboflow-model-improvement`) that collide with nothing else in the repo.
- **Resolution:** strip frontmatter from the three sub-pages (keep their H1 titles), or deliberately add it everywhere with a documented purpose — just make it consistent.

### B3. Local pages cross-reference via MCP URIs they tell agents not to use

- **Files:** e.g. `inference/SKILL.md:44,67`, `data-management/SKILL.md:216`, `improvement-playbook.md:147`, `api-reference/SKILL.md:90-92`, `universe/SKILL.md:157` · **Severity: Medium** · **Confidence: 95%**
- Every page opens with "don't call `ReadMcpResourceTool` for `roboflow://skills/...` when the local skill is available", then the body cites related material as `roboflow://skills/<path>` — the exact URIs agents were told to avoid. An agent that obeys the header has no actionable pointer; one that follows the link disobeys the header. Some pages (`batch-jobs.md`, SKILL.md's staging links) already use relative links correctly, so the repo has both styles.
- **Resolution:** standardize on relative links (`[workflows](./workflows.md)`) in the repo — they work for plugin installs and on GitHub — and let the MCP-resource build (wherever `roboflow://` is served from) rewrite them if needed. Keep one line in the source-of-truth note explaining the URI scheme for non-plugin clients.

### B4. Hard-coded prices contradict the skill's own "never guess prices" rule

- **File:** `skills/plans-and-pricing/SKILL.md:10` vs `:17-20` · **Severity: Medium** · **Confidence: 85%**
- Line 10: "always direct the user to roboflow.com/pricing. Never guess at prices." Lines 17–20 then hard-code $99/mo, $79/mo annual, $29/user, $130–$630 packs, $6/credit. The moment marketing changes a number, the skill *is* the guessed price — and agents will quote it confidently. Also inconsistent units: Public plan credits are described as "~$60/mo worth" while Core is "50/mo" credits.
- **Resolution:** keep credit *rates* (structural, slow-moving) but replace dollar amounts with "see roboflow.com/pricing", or annotate them with an as-of date ("as of 2026-06, verify at …"). Express all plan credit allowances in the same unit.

### B5. Minor doc nits

| # | File:line | Issue | Confidence | Fix |
|---|---|---|---|---|
| 1 | `api-reference/api-key-management.md:155` | "The **three** states of `scopes`" — followed by four bullets | 95% | "four states" or fold "omitted" into prose |
| 2 | `inference/workflows.md:43` | SAM3 row: garbled hyphenated phrasing ("Default `output_format: "rle"` - compact and modern, … - legacy") inside a table cell | 80% | rewrite as "Defaults to `rle` (compact); `polygons` is legacy" |
| 3 | `api-reference/rest-api.md:177` vs `inference.md:204` | Bad API key = 401 on platform API but 403 on serverless — likely both true per host, but unexplained | 60% | add a one-line note that the two hosts differ |
| 4 | `README.md:22` | `claude plugin install roboflow` — with marketplace and plugin both named `roboflow`, the unambiguous form is `roboflow@roboflow` | 50% | verify on a clean machine; use the fully-qualified form if needed |
| 5 | `api-key-management.md:9` | Staging base URL `api.roboflow.one` published in a public repo | 70% (intentional?) | drop it or mark internal-only |

---

## C. Tests & CI — the biggest structural gap

### C1. No tests of any kind

- **Severity: High** (for repo health) · **Confidence: 98%**
- `poll_batch_job.py` has two pure helpers (`_summarize_notification`, `_output_batches`) that are trivially unit-testable, plus arg-parsing and exit-code semantics worth locking down. Nothing exists.
- **Resolution:** add `tests/test_poll_batch_job.py` (pytest, no network — stub `get_batch_job_metadata`) covering: dict/str/None notification inputs, `resultsBatches` extraction, exit codes for terminal-success / terminal-error / timeout / missing key, and interval validation once A7 lands.

### C2. No repo validation CI

- **Severity: High** · **Confidence: 98%**
- The only workflow publishes installer scripts. Nothing validates the things this repo actually is: JSON manifests, markdown links, frontmatter, Python syntax. Every bug in section A would have been caught or preventable by cheap checks.
- **Resolution:** add a `validate.yml` running on PRs:
  1. `jq empty` on all `*.json` (manifests, `.mcp.json`);
  2. relative-link checker over `skills/**/*.md` (the ~15-line Python used for this review suffices, or `lychee` offline mode);
  3. frontmatter lint: every `skills/*/SKILL.md` has `name` + `description`, names unique, (post-B1) name == dirname; optionally forbid frontmatter on non-SKILL pages;
  4. `python -m py_compile` + `ruff` on `skills/**/bin/*.py`;
  5. check executable bits on files under `bin/` match their shebangs (catches A2 class forever);
  6. cheap consistency greps, e.g. version match between `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` (see D1).

### C3. Skill content is untestable-by-construction against the live product

- **Severity: Low** (accepted limitation) · **Confidence: 90%**
- Most content (model IDs, credit rates, block types, URL routes) describes an external product and will drift silently. This can't be fully CI'd, but it can be managed.
- **Mitigation:** add a `last-verified: YYYY-MM` field to each skill's frontmatter and a quarterly review checklist; where an authoritative machine-readable source exists (e.g. `workflow_blocks_list`, the batch-processing OpenAPI spec already linked in the docs), consider a scheduled job that diffs documented names against it and opens an issue on drift.

---

## D. Architecture & maintenance

### D1. Duplicated plugin manifests with no sync guard

- **Files:** `.claude-plugin/plugin.json` vs `.codex-plugin/plugin.json` · **Severity: Low** · **Confidence: 90%**
- The Codex manifest is a strict superset (adds `interface`); the shared fields (version, description, keywords, skills/mcp paths) are duplicated and currently in sync only by discipline. First forgotten bump ships two different versions of "the same" plugin.
- **Resolution:** add the version-equality check to C2's CI, or generate one manifest from the other with a tiny script.

### D2. Codex install instructions are speculative

- **File:** `README.md:57-106` · **Severity: Low** · **Confidence: 60%**
- The Codex flow ("currently exposes `codex plugin marketplace add`…", plugin-browser keystrokes, cache paths) describes a fast-moving third-party CLI in step-by-step detail. Unverifiable here, and precisely the kind of doc that rots in weeks.
- **Mitigation:** date-stamp the section ("as of Codex vX.Y") and link to Codex's own plugin docs as authoritative.

### D3. Security posture (mostly fine — three notes)

- **Confidence: 80%** · **Severity: Low**
- The publish workflow is well done: WIF (no long-lived keys), least-privilege permissions, `persist-credentials: false`, no-cancel concurrency. Notes:
  1. REST examples put `api_key` in query strings throughout — that's Roboflow's API design, but `api-key-management.md` shows a `Authorization: Bearer` header is accepted there; where headers are accepted, prefer them in examples (query strings end up in server/proxy logs and shell history).
  2. `curl | bash` installer distribution (see A8) — publish checksums when the script becomes real.
  3. No `SECURITY.md` (or CONTRIBUTING/CODEOWNERS) for a public, org-owned repo. Add a stub pointing at Roboflow's disclosure process.

---

## Priority order

| Priority | Findings | Effort |
|---|---|---|
| 1 — do now | A1 (MCP auth), A2 (exec bit), A3 (fake SDK API) | minutes each (A1 needs a verification pass on both clients) |
| 2 — this week | A6, A7, A8, B1, B3, C2 | ~1–2 days total |
| 3 — housekeeping | A4, A5, B2, B4, B5, C1, D1–D3 | opportunistic |

*Overall confidence in this review: high on everything verified against source (A2, A3, A7-internals, all internal-contradiction findings); medium-high on client-behavior claims (A1, B1) which should get a quick empirical check — install the plugin on a clean machine and observe skill names and MCP auth.*
