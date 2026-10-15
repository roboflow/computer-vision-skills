# The search: portfolio, smoke, joint scoring, tune and prune

The job decides the architecture more than any threshold does, so the search starts wide and
narrows. Every round is one Run that scores every live candidate on the whole suite. A Run
takes up to 100 Executions; keep live candidates at or below 60, and fewer when most of them
call the same heavy native model.

## Candidates are saved Workflows with descriptive names

Each candidate is created with `workflows_create` (config in the body; 7 KB manifests are
fine) and recorded in `created.json` with its id, url slug, family, parent (if tuned from
another candidate), and the change in one sentence. Saved rather than inline: the user can
open any candidate in the UI, Run payloads stay small, and cleanup is a list of slugs.

**Name pattern:** `<model or checkpoint> + <approach> (<key change>) · cNN · <timestamp>`.
Examples: `Qwen 27B + evidence booleans (quarter-height close-up) · c30 · 1856`,
`CLIP scene + crop → PP-OCR digits, no possession · c11 · 1856`. Descriptive part first
because the results table truncates from the right; model first because it is the strongest
signal. Everything else goes in `business_context` and in `created.json`, not in the name.

Pre-existing Workflows the user brings join the portfolio with `pre-existing: true` in the
registry. They are never modified, renamed, or deleted.

Tuning a candidate means a new saved Workflow with `parent` set (the parent stays in the Run
for comparison) or, when the parent is being replaced, `workflows_update` with the new
specification. `workflows_update` needs the full config even for a rename.

## Keep prompts DRY

Generate manifests from one script (`candidates/generate.py` style): shared field
definitions, one context sentence, and the decision rules in `expression` blocks rather than
in prose. Variants then differ by one named change, which is what the round analysis needs.

## The portfolio

Target 20 to 40 candidates in the first round, spread over families. Not every family fits
every job; skip the ones that cannot produce the Goal Card's answer types. For each family,
check the block schema with `workflow_blocks_get_schema` (`manifest` = block type) and the
available models with `models_list`, `universe_search`, and `autolabel_models_list` before
writing anything.

| Family | What goes in | Typical answer types |
| --- | --- | --- |
| VLM, evidence pattern (default) | `qwen_vlm@v4` (native Qwen 3.8 VL 27B, 3.5 VL 2B/0.8B, 3 VL 2B), `open_ai@v7`, `google_gemini@v6`, `anthropic_claude@v3`; the VLM returns observable booleans, `expression` blocks decide | label, boolean, count |
| VLM, direct structured answer | same blocks, prompt returns the answer directly, `json_parser` | label, boolean, count, labelSet |
| VLM as classifier or detector | `vlm_as_classifier@v2`, `vlm_as_detector@v2` with foundation detectors | label, positionedObjects, count |
| Two-stage | `absolute_static_crop` or a detector crop, then a VLM or OCR on the crop; or a cheap model for the easy answers plus a strong one for the hard one | label, boolean, count |
| OCR on a fixed region | `absolute_static_crop` + `pp_ocr@v1` (reads 18 px digits; EasyOCR did not) + `property_definition` digit extraction | count, label |
| Foundation and public detectors | `roboflow_object_detection_model@v3` with public checkpoints (`yolov8n-640` COCO), zero-shot detectors | positionedObjects, count |
| Universe models | `universe_search` for models trained on the same objects | depends on the model |
| Detector plus logic blocks | detector, `detections_filter`, `detections_nearest_neighbor`, `dynamic_crop` + `clip_comparison` + `detections_classes_replacement`, `expression` | count, boolean, label derived from detections |
| Zero-shot CLIP | `clip_comparison@v2` with one prompt per value | label (weak on broadcast scenes: 37 of 37 pitch frames wrong) |
| Ensemble | two families answering, an `expression` reconciling, or two calls of the same model for different answers | label, boolean, count |
| Pre-existing | the user's own Workflows | as they are |

**Out of the defaults until the platform changes:** custom Python
(`dynamic_blocks_definitions`) times out inside Eval Runs; `qwen3_5vl@v2` and `smolvlm2@v1`
expose only a `parsed_output` of the wrong kind, so no parser can read them; Qwen 2.5 VL 7B
native fails to load; `enable_thinking` on Qwen 27B yields unparseable output.

What testing found: small native VLMs (2B, 0.8B) invent numbers (they answered
"11-11" for a 1-1 scoreboard) and fail any exact gate; the 27B reads a scoreboard from the
full frame as well as from a crop; the evidence pattern needs observable evidence, written as
things you could point at (player height relative to the frame, number of players visible,
a legible shirt number), and then beats or ties direct answering.

Within a family, vary one axis at a time between candidates so the round analysis can
attribute wins.

## Smoke, outside the Eval

Every manifest passes `workflow_specs_validate`, then `workflow_specs_run` on two or three
examples chosen to cover the answer values, before it is saved. A manifest that errors or
returns the wrong shape (scores as strings, a list where a string is due) is fixed or dropped
(registry: `dropped: smoke, <reason>`). Delegate "validate, smoke, save" for a batch of
manifests to one subagent working from `candidates/to-save-rN.json`, writing
`candidates/saved-rN.json`. Never read a ranking from smoke, and never read latency from it:
`workflow_specs_run` returns no timing.

## Submitting a Run

Say what the Run is before starting it: "round 1: 13 candidates × 77 examples".

```json
{
  "eval_id": "<eval>",
  "executions": [
    { "subject": { "kind": "savedWorkflow", "workflowId": "<id>", "subjectKey": "c13" },
      "bindingSet": { ...the validated BindingSet from the Eval... } }
  ],
  "case_selection": { "kind": "all" },
  "execution_reuse": "prefer",
  "idempotency_key": "<uuid4>"
}
```

- Every Execution uses the same `bindingSet`, which is why output names are frozen.
- `caseSelection` is always `all`. The suite is the unit of scoring.
- Reuse applies only when the Spec has no runtime (latency) check and the Dataset snapshot is
  unchanged since the candidate last ran; the response echoes `executionReuse: never`
  otherwise, and every candidate is re-executed. Budget for that after a correction round.
- Start polling with `workflow_evals_runs_get(wait_seconds=25)` immediately after submission
  and continue until the Run reaches a terminal state. Show meaningful progress changes and
  surface failures promptly; do not wait a fixed interval before the first poll. In testing,
  13 × 77 took 5 minutes, 9 × 77 with retries 12 minutes.
- If the server rejects the joint Run, split in halves and retry once, then one Run per
  candidate, and record the error (code, message, requestId) in the report.

## Reading a round

1. If `retry.allowed` on the finished Run, call `workflow_evals_runs_retry_failed`, up to
   twice. Native model backends return transient 500s under load (131 of 693 Cases in a Run
   with nine Qwen 27B candidates; two retries settled all of them). Export is refused on a
   partially completed Run with retryable Cases unless `allow_pending_retries` is set; use
   that only to read diagnostics.
2. Export once (`workflow_evals_exports_start`, JSON, then `exports_get_job` with
   `async_task_id`), download the artifact with a script, and run `rounds/analyze.py` on it:
   per candidate, gate errors, errors per Check, errors per answer value, median and p90
   latency, the failing Case names. Exports carry judgments and measurements, not the
   predicted value; `workflow_evals_results_case_get` gives it (8 KB per call), so fetch it
   only for the Cases you must see.
3. Gates. Compute each must-never rule from the rows per Execution. Gate-breakers are marked
   `disqualified` but stay in the table for the analysis.
4. Rank the rest by the Goal Card's order, criterion by criterion.
5. Noise. From round 2 on, compare every unchanged candidate with its previous round. The
   largest move per criterion is the noise band (in testing: 0-2 on a 77-frame scene
   label, up to 6 on possession). Differences inside the band are ties, broken on the next
   criterion; say so in the round line.
6. Analysis, written to `rounds/r<N>/analysis.md`: per family, what it gets right and wrong,
   with example ids; which failures are shared by everyone (send them to the user as a
   contact sheet with key and actual predictions printed for review); which are
   family-specific. To diagnose a shared miss, read the predicted values for a few of them.
7. Tell the user: a table of candidates with errors per criterion and latency, one or two
   sentences of insight, a link to that completed Run ("Explore results"), and what
   the next round adds and prunes. Use visual evidence below when it clarifies the result.

## Linking app results

After each completed round, link its exact Run so the user can browse all candidates and
Cases in the app. In the final delivery, include both the Eval link ("Open evaluation") for
its history and the completed finalists Run link ("Explore final results") for the scores
being reported. Keep these links alongside the summary and in `report.md`.

Prefer an app URL returned by the API; otherwise use the documented UI routes in
`gotchas.md` with the actual workspace slug, Eval URL slug, and Run id. A signed artifact
`readUrl` is not an app results link. If the required URL or identifiers are unavailable,
give the known resource id and say the link is unavailable; never invent a URL or present
pending results as complete.

## Showing saved-result evidence

Reuse the completed Run's saved results; never rerun inference solely to render a visual.
Choose a small set of same-Case comparisons covering gains, regressions, and remaining
failures when present. Fetch actual predictions only for these examples with
`workflow_evals_results_case_get`. Use `draw-vision` as routed in `SKILL.md` to show ground
truth beside named candidates' predictions and check outcomes, with Case ids and video
timestamps. Caption scalar labels; overlay boxes or masks only when retained predictions
or ground truth contain that geometry. Mark missing predictions/geometry unavailable; never
reconstruct them from pass/fail. This presentation sample does not replace whole-suite scoring.

When a tradeoff needs explaining, plot the Goal Card's quality metric against measured
latency with ordinary plotting tools suited to the environment. Name the metric, its better
direction, and latency units/statistic (median or p90). Default to a scatter plot with latency
on X and the selected Goal Card quality metric on Y: one point per candidate Workflow,
colored by family, with finalists labeled and the latency budget drawn as a vertical line
when specified. Prefer PNG/SVG for display and sharing; use interactive HTML only when the
interaction adds value and the host supports it.
Compare only compatible checks, ground-truth snapshots, scoring populations, and
measured runtime/reuse conditions. Separate and label incompatible historical runs; show
latency as unavailable when unmeasured, and do not invent an aggregate quality score. Trace
metrics to saved Run/Execution ids and suite revisions, not screenshot captions.

If temporal context helps explain a transition, optionally render a short saved clip or frame
sequence with `draw-vision`. Align predictions to actual source timestamps and mark unscored
gaps; do not interpolate predictions. Per-frame evidence is not stateful video validation or
live inference, and recorded latency replay is not camera/edge FPS.

Inspect visual artifacts for legibility and save them with the report. Display them in the
conversation when supported; otherwise attach or open the saved files. Choose only visuals
that help the current question; charts and clips are not required for every round.

## Tune and prune rounds

Each round:

- **Keep** the survivors unchanged, so every round compares the full field.
- **Add** tuned variants of the top candidates (default: top 3 to 5, one to three variants
  each), each targeted at one named failure: one definition rewritten in observable terms,
  one threshold, one phrasing of the hard question, one model swap. Each variant is a new
  saved Workflow with `parent` set.
- **Prune** the bottom third and every disqualified candidate that has no obvious fix.
  Pruned candidates stay in `created.json` (`pruned: round N`) for cleanup.
- **Run** once on the whole suite, read, re-rank, re-analyze. One line to the user: round,
  completed Run link, champion, errors per criterion, what changed, what the next round does.

Stop when the champion is perfect on the suite for two rounds, when two rounds in a row
change nothing in the top three beyond the noise band, or when the budget from Checkpoint 2
is spent. Default: 3 tune rounds after round 1.

## The finalists Run (Phase 5)

Rerun the top three plus every pre-existing Workflow alone, `execution_reuse: "never"`, on
the whole suite including any new examples. When speed is in the Goal Card, first add the
`latency@1` check to the Spec (`workflow_evals_specs_update` with the revision) so this Run
measures it without load from other candidates. Report, per candidate, the range across the
last tune round and this Run, the rare-value slices, and the per-Case diff between champion
and runner-up (`workflow_evals_results_compare` with two execution ids; it returned
`INTERNAL_ERROR` twice in testing, so compute the diff from the two exports when
it fails). Without a new source, say so; never carve a holdout out of the suite.

Pick the winner by the Goal Card order with ties inside the noise band broken on the next
criterion. Tell the user when the strict order and the noise-aware order disagree, and which
one you applied.

## Provider down

When a provider returns 500 on every call: probe each provider with a one-image caption spec
through `workflow_specs_run`, port the design to a working provider (native Qwen 27B is a
good stand-in), keep the down family's manifests as files so they can join a later round, and
record the errors and reference ids in the report. Diagnose from the returned status, code
and message: authentication or key-configuration errors warrant checking the workspace's
managed-key status or supplying a key; rate-limit and server errors do not establish a key
problem. If the error is inconclusive, report the cause as unknown. How long a failure
persists does not identify its cause; use working providers meanwhile.

## Cleanup

Read `created.json`. Propose deleting every Workflow with `pre-existing: false` except the
champion, in one list, with names. `workflows_delete` takes the **url slug**, not the id, and
is a soft delete to the workspace Trash, restorable for 30 days with
`trash_restore_workflow`. Runs keep a frozen snapshot of each Subject, so deleting candidate
Workflows does not erase the results. Delegate the deletes to a subagent from
`cleanup-list.json`, then verify the champion still exists with `workflows_get`. Offer
separately to delete the Runs (two-step deletion with impact and `deletion_key`). Never
propose deleting a pre-existing Workflow, the Eval, the Spec, or the Dataset.

## report.md

```
# <slug>: Workflow optimization, <dates>

## Goal Card
<as approved, with the rules added during the review>

## Test suite
Eval <name> (<id>), Spec (<id>, revision), Dataset (<id>, <count> Cases). Examples by source,
coverage per answer value, not-applicable examples, corrections the user made, caveats.
Eval app link for browsing the suite and Run history.

## Portfolio
| id | name | family | change | source (me / pre-existing) | status |
Dropped before any Run, and why. Families that could not enter (provider down).

## Runs
| Run id | purpose | candidates | examples | started |
Link each completed Run using the app-link guidance above.

## Round 1
| candidate | gate | criterion 1 | criterion 2 | latency | status |
Analysis: per family, shared failures, answer-key corrections that followed.

## Tune rounds
| round | Run | added | pruned | champion | errors per criterion | what changed |
Noise band measured on unchanged candidates.

## Validation on new examples / finalists Run
| candidate | criterion 1 (round / rerun) | criterion 2 (round / rerun) | latency | rare slices |
Per-Case diff champion vs runner-up. Or: no new source; validated on search examples only.

## Winner
What it is, in words. Key settings. Scores. Why it beat the runner-up. Where it still fails
(with the frames). Saved as <name> (<id>). Compared with pre-existing <name> (if any).
Validation limitations, including whether any new source was available. Visual artifact paths
and the Run/Execution and suite revision supporting each comparison or chart.
Eval link and completed finalists Run link for exploring the final results in the app.

## Resources
| kind | name | id | status (kept / deleted / pre-existing) |

## Notes for the workflow-from-eval skill
Pointer to skill-bugs.md and friction.md.
```
