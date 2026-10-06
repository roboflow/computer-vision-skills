# Running, reading, and cleaning up

Everything after the Spec, Dataset, and bindings exist. Runs, Case preparation, exports, and
deletions are background work: start them, then poll. Reads are always safe to retry.

## Case preparation (candidate outputs)

Case preparation runs the Eval's Workflow over Dataset Cases and keeps each raw output. Use it
to label ground truth faster (correct what the Workflow says instead of starting from zero) and
to see the real shape of the Workflow's outputs before you write bindings. It costs inference.

1. `workflow_evals_case_preparations_start(eval_id, case_selection=..., runtime=...)` with an
   idempotency key. `case_selection` is `{"kind": "all"}` or
   `{"kind": "explicit", "caseIds": [...]}`.
2. Poll `workflow_evals_case_preparations_get` (or call it without `preparation_id` for the
   Eval's current one) until `state` is terminal. `progress` counts queued, running,
   succeeded, failed, and cancelled Cases.
3. `workflow_evals_case_preparations_cases` lists each Case's `candidateOutput.readUrl`. Fetch
   it with an HTTP GET to read the raw Workflow output. The URL expires in minutes.
4. `workflow_evals_case_preparations_resume` requeues only failed Cases and keeps successful
   ones. On a preparation with no failures it changes nothing. It needs write and run access.

## Runs

`workflow_evals_runs_start(eval_id, executions=[...])` takes one entry per Workflow to evaluate:
`{"subject": <Subject>, "bindingSet": <validated BindingSet>}`. One Run with two entries is how
you compare two Workflows on the same Cases; each entry becomes an **Execution**.

- `case_selection`: all Cases, or explicit ids. Run one Case first as a cheap dry run.
- `execution_reuse`: `prefer` (default) reuses retained Workflow outputs that match exactly;
  `never` runs the Workflow again.
- `inference_server`: overrides the Eval's runtime for this Run.
- Use an idempotency key. If the response is lost, retry with the same key instead of starting
  a second Run.

The Run freezes the Spec, a Dataset snapshot, the Workflow subjects, and the bindings. Later
edits never change it. `workflow_evals_runs_configuration` and
`workflow_evals_executions_configuration` show what was frozen.

### Polling

Poll `workflow_evals_runs_get` every 5 to 10 seconds. Run states are `queued`, `running`,
`completed`, `partially_completed`, `failed`, `cancelled`, and `deleting`. Small Runs usually
finish in seconds to a few minutes.

Tell three situations apart instead of polling forever:

- **Slow but healthy**: still `queued` or `running`, and `childStateCounts` or the Execution
  summaries move. Keep polling up to the time you agreed with the user (5 minutes is a good
  default for a few Cases), then report progress and ask before waiting longer.
- **Terminal failure**: `failed` or `partially_completed`. Read `retry` on the Run: `allowed`
  is authoritative, and `reason` explains why not. Read the failed Cases before retrying.
- **Communication problem**: the poll itself errors (timeouts, `5xx`, `429`). Back off and
  retry the read. A failed poll never means the Run failed, and stopping polling never cancels
  it.

`workflow_evals_runs_cancel` requests cancellation of an active Run.

### Retry, replay, rescore

- `workflow_evals_runs_retry_failed` reruns only operationally failed or missing Cases in the
  same Run. A Run with nothing retryable returns `409` with `reason: "nothing_retryable"`.
  Cases a Check judged as failing are results, not failures, and are never retried.
- `workflow_evals_runs_replay` creates a new Run from a previous one, optionally with new
  Workflow subjects and bindings. It returns `409` if the saved Spec or Dataset changed since.
- `workflow_evals_runs_rescore` scores a previous Run's retained outputs against a revised
  Spec without running the Workflow again. Save the new Spec and attach it to the Eval first.
  Executions whose retained outputs cannot answer the new Spec come back as rerun required.

## Results

Work from the aggregate down to single Cases.

1. `workflow_evals_results_overview(eval_id, run_id, execution_id)`: per Check `passed`,
   `failed`, `passRate`, `evaluatedCount`, measurement sums and averages, a normalized
   `performanceScore`, and runtime (average latency, failure rate). Filter by `slices`.
2. `workflow_evals_results_cases_list`: one row per Case with each Check's judgment, score, and
   measurements. Filter with `failed_check=true`, `check_id`, `judgment`, `state`, or `slices`;
   `order="latency"` finds slow Cases.
3. `workflow_evals_results_case_get`: inputs, frozen ground truth, the bound actual values, and
   Check details for one Case. The raw Workflow output is left out by default because it can
   carry megabytes of base64 images. Pass `include_raw_output=true` only when a bound value
   looks wrong and you need to see what the Workflow really returned.

Report results per Check: the pass rate, which Cases failed, by how much, and in which slices.
Say what the ground truth is and where it came from.

### Comparing

`workflow_evals_results_compare(eval_id, execution_ids=[...])` returns per-Check deltas and
Case-level deltas between completed Executions. Executions from the same Run are always
comparable. Executions from different Runs are comparable only when they froze the same Spec
semantics and the same Dataset snapshot; otherwise the response explains why not.

### Exports

1. `workflow_evals_exports_start(eval_id, run_id, format="csv" | "json" | "xlsx")` with optional
   filters (Executions, Check, judgment, slices, failed Checks). The Run must be stable.
2. Poll `workflow_evals_exports_get_job` until `state` is `completed`. `result` has `rowCount`,
   `artifactId`, and a short-lived `url`. A JSON export holds `provenance` and `rows`.
3. `workflow_evals_exports_download_url` renews the URL for the same `artifactId`.

### Embeddings

Every Run starts image-embedding analyses on its own (CLIP, DINOv2, DINOv3, SigLIP2), which
project each Case's input to 2D points for clustering failures by appearance.
`workflow_evals_embeddings_get` without a provider returns every provider's job; a completed
job's `result.url` holds the points. Reading never starts work. Call
`workflow_evals_embeddings_start` only for older Runs or to retry a failed job, and only when
the user asks: it costs compute.

### Local runtimes

With `inference_server={"kind": "local", "url": ...}` the Run returns no `asyncTaskId`. The
caller runs the Workflow itself: read Cases with `workflow_evals_executions_input_cases` and
send each output with `workflow_evals_executions_submit_capture`. The server still scores.

## Cleanup

Delete only what you created, and tell the user what stays.

- **Runs and Evals** use a two-step deletion. Call `workflow_evals_runs_delete` or
  `workflow_evals_delete` without `deletion_key`: nothing is deleted, and you get the
  `impact` (Runs, Executions, Case results, Check results, artifacts) and a `deletionKey`
  that expires. Show the impact, get a clear yes, then call again with the key. Poll
  `workflow_evals_operation_get` with the returned `asyncTaskId` until `completed`. Deleting an
  Eval deletes its Runs and keeps the Spec and Dataset.
- **Cases**: `workflow_evals_cases_delete` with the Case's `revision`. Runs that froze the Case
  keep their copy.
- **Specs and Eval Datasets** have no delete operation. Reuse them, give test resources a clear
  prefix and timestamp, and list their ids in your summary so the user can find them.
