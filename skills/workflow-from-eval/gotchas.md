# Gotchas

Platform, MCP and block behaviors verified in the 2026-10-06 smoke test, the 2026-10-08 first
live run (28 candidates, 6 Runs) and the 2026-10-09/12 second live run (27 candidates, 5
Runs). Remove an entry once it stops being true.

## Verified against production

- **Joint Runs work.** Up to 16 Executions per Run tested, saved and inline Subjects mixed.
- **Execution reuse has two killers.** A runtime (latency) check in the Spec forces
  `executionReuse: never` (the Run service refuses stale timings), and any change to the
  Dataset snapshot (a corrected Case) re-executes everyone. The response echoes the policy
  actually applied; read it.
- **Runs freeze each Subject's manifest.** Readable through
  `workflow_evals_executions_configuration`; `workflowSubjectHash` is the sha256 of the
  sorted, compact JSON.
- **Check applicability exists.** `"applicability": {"kind": "ground_truth_present", "path":
  "$.field"}` plus an `optional: true` contract field makes the Check `not_applicable` on
  Cases without the field. The Spec accepts no `description`.
- **Contract migration ignores `incomplete`.** `datasets_update_contract` validates every
  Case as complete; with a draft Case present it fails with "groundTruth.x is required by
  the Dataset contract". Decide optional fields before the first Case. (Platform fix: pass
  `row.groundTruthState === "incomplete"` in the migrate loop of
  `workflowEvalsDatasetService.ts`.)
- **`workflows_delete` takes the url slug**, not the id; soft delete into the workspace
  Trash (30 days, `trash_restore_workflow`). `workflows_update` requires `config` even for
  a rename. `workflows_create` takes the config in the body (7 KB fine).
- **`workflow_evals_create` has no `runtime` argument** in the MCP tool; the server defaults
  to serverless.
- **Readiness differs between list and get.** Use `workflow_evals_get`.
- **Workflow results are a list, one record per image.** Output paths start at `$[0].` and use
  the Workflow's declared output names.
- **Binding paths are dotted.** `$["name"]` never resolves; names with a dot cannot be bound.
- **`bindings_validate` reports unknown outputs** with code `unknown_workflow_output`. Treat
  it as a hard error.
- **Raw outputs are omitted by default.** `workflow_evals_results_case_get` adds
  `rawOutputOmitted: true`; it still returns ~8 KB per Case (checks repeated three times plus
  a signed artifact URL). Fetch it only for the Cases you must see.
- **Exports have no predicted values.** Rows carry judgments and measurements per Check,
  `state`, `latencyMs`, and for failed Cases a `diagnostic.message` with the query string
  redacted (`?[redacted]`). `exports_get_job` takes `async_task_id`; the artifact URL is
  signed and expires in 10 minutes.
- **Export is refused on a partially completed Run with retryable Cases** unless
  `allow_pending_retries=true` (provenance records `pendingRetryableWork`).
- **Native model backends return transient 500s under load.** `500 ... /infer/lmm/qwen3_8-27b`
  on 131 of 693 Cases with nine 27B candidates in one Run; marked retryable; two
  `runs_retry_failed` settled all. Rounds with 7 or fewer 27B candidates had none.
- **Execution state is Run-level.** Poll the Run with `wait_seconds=25`.
- **`cases_create` takes `ground_truth_state`.** Replacement needs the current `revision`
  and the full Case body; 412 means stale revision.
- **Case order in the UI is creation order**, and two Cases can share a `caseOrder`.
- **`case_preparations_cases` returns only signed readUrls** (69 KB for 52 Cases, over the
  tool-result limit). Download the artifacts with a script.
- **`results_compare` returned `INTERNAL_ERROR`** twice on two completed Executions of one
  Run (refs dffa2e60f4f6e073d02002efe8390085, 9302bfdcd86cb1056ef0e51d8297b87a). Compute the
  per-Case diff from the exports.
- **Specs and Eval Datasets cannot be deleted.** Only Evals, Runs, and Cases can.
- **Deleting an Eval is two steps** and removes its Runs. This skill never proposes it.
- **Custom Python times out inside Eval Runs** (`dynamic_blocks_definitions`). Parked.
- **Listings and create responses carry signed URLs** (`readUrl` on Evals, case
  preparations, exports). Never paste a listing into a file or the report.
- **Signed URLs in diagnostics are redacted** server-side (roboflow#17151).
- **`checkIds` can come back empty** in some result payloads. Key your bookkeeping on the
  Spec's check ids.
- **`embeddings_get` with no provider** fans out across providers. Do not start embeddings.
- **UI routes**, until the API returns `appUrl`: Eval
  `https://app.roboflow.com/<workspace>/workflows/evals/<evalUrl>`, Run `.../runs/<runId>`,
  Workflow editor `https://app.roboflow.com/<workspace>/workflows/editor/<workflowUrl>`.

## Blocks and models

- **The Roboflow-managed VLM proxy** (`heavy-api.roboflow.com/apiproxy/{openai/v2, gemini,
  anthropic, openrouter}`) was down for 15 minutes in the first test and for three days in
  the second. Native models kept working. These observations do not establish the cause;
  diagnose from the returned error, not the duration of the failure.
- **Native Qwen 3.8 VL 27B** reads a 640x360 scoreboard exactly (72/72) from the full frame;
  7-10 s per frame alone, 10-16 s in big joint Runs. **Qwen 3.5 VL 2B / 0.8B and Qwen 3 VL
  2B** invent numbers ("11-11") and fail exact gates; Qwen 3 VL 2B returns numbers as strings
  (cast with `property_definition` `ToNumber`). **Qwen 2.5 VL 7B native** fails to load.
  `enable_thinking` on the 27B makes the output unparseable.
- **`qwen3_5vl@v2` and `smolvlm2@v1`** expose only `parsed_output`, declared `dictionary`
  but holding a fenced JSON string; `json_parser@v1` refuses the kind. Unusable for
  structured answers until the blocks expose a `language_model_output`.
- **CLIP zero-shot** (`clip_comparison@v2`, ViT-L-14) separates nothing on broadcast
  football frames (37/37 pitch frames wrong). Fine as a shirt-colour classifier on crops.
- **OCR on small digits:** `easy_ocr@v1` read "BRA MAR" and no digits on a 230x44 crop;
  `pp_ocr@v1` (small/medium) read "O BRA 1 1 MAR". Digit extraction in `property_definition`:
  `DetectionsFilter` (class_name `in (Sequence)` digits), `SortDetections` x_min,
  `DetectionsPropertyExtract` class_name, `SequenceAggregate` first/last, `ToNumber`.
- **Nested batches.** `dynamic_crop` → `clip_comparison` → `expression` returns a list at the
  Workflow output. `detections_classes_replacement` writes the crop-level class back onto
  the parent detections; then `detections_nearest_neighbor` + `DetectionsPropertyExtract`
  gives a top-level list the `expression` can compare with `["yellow"]`.
- **COCO `yolov8n-640`** rarely finds the ball on 640 px broadcast frames.
- **`workflow_specs_run` returns no timing** (`profiler_trace` empty).

## Roboflow Agent (`agent_chat`), when the user switches it on

- Plan mode can reply "saved a draft" with `workflows: []` and no spec.
- It saves Workflows under its own names. Never let one of those enter a Run.
- Its designs have gated on evidence that is not observable at the image resolution. Use it
  as an advisor, verify everything through the Eval.

## Client-side

- The MCP tool schemas are cached when a session starts. A tool parameter added after the
  session began is invisible until a new session.
- The Read tool renders local images, including a 12-tile contact sheet. `ffmpeg` and
  `ffprobe` are available; PIL may not be.
- Heavy MCP payload work (uploads, Case replacements, smoke + save of manifests, deletes)
  belongs in subagents working from files; the main session verifies counts and ids.
- A closed laptop between checkpoints lost nothing: the working folder is the resume point.
