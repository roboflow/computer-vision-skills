# The test suite and the answer key

The user reviews; you label. Their job is to correct and confirm, not to fill in a form. The
suite is append-only: examples are added or corrected in place, never deleted by the skill.
A mislabeled example is fixed with `workflow_evals_cases_replace`, not dropped.

## Reuse before create

The suite belongs to the job, not to the session. Before creating anything, look for
`<slug>-eval` with `workflow_evals_list` and read it with `workflow_evals_get`. If it exists,
reuse its Spec and Dataset, add this session's examples to it, and register it in
`created.json` as `pre-existing: true` so cleanup never touches it. Only create a new suite
for a new job.

## Getting examples

Target 30 to 60 examples that cover every answer value and the hard transitions. Fewer than
20 makes the search noisy; say so.

| Source | How |
| --- | --- |
| Video file | `ffprobe` for duration and fps. Extract with `ffmpeg -vf fps=<r>,scale=960:-1` into `frames/`. Pick `r` so you land between 30 and 60 frames; for a 26 s clip that is 2 fps, for a 131 s clip 0.4 fps. Name frames with a zero-padded index so ordering is stable, and keep `frames/index.json` (name to seconds). |
| Folder of images | Use them as-is. Downscale anything above 1920 px on the long side before upload. |
| Roboflow project | `workflow_evals_cases_import` with a dataset source (`project:read`, `image:read`). Imported Cases start incomplete. |
| Workspace images or Universe | `images_workspace_search` / `universe_dataset_images_search`, then `cases_import` with a source, or download and upload. |
| URLs | Download into `frames/` first. Case inputs must be uploaded artifacts, never URLs. |

### The contract comes first

Write the Dataset's `ground_truth_contract` (and which fields are `optional`) before the
first `cases_create`. `workflow_evals_datasets_update_contract` validates every existing Case
as if it were complete, so a Dataset holding a single draft Case refuses any migration
("groundTruth.x is required by the Dataset contract"). If you must migrate anyway: complete
every Case (placeholders on the fields that will become optional), migrate, then replace
those Cases without the placeholders.

### Uploading local files into the suite

Three calls per image: `workflow_evals_case_assets_upload` (start; needs `eval_dataset_id`,
`asset_name`, `content_type`, `expected_size`), an HTTP `PUT` of the bytes to the signed URL
with exactly `requiredHeaders` (`x-goog-if-generation-match: 0`, `Content-Type`), and
`workflow_evals_case_assets_upload_complete`. Then `workflow_evals_cases_create` with
`{"artifactId": ...}` as the image input, `slices`, and `ground_truth_state: "incomplete"`.

Do this with a helper and subagents, not by hand:

1. Write `put.sh` in the working folder: a `curl -X PUT` of a file to a URL with the exact
   headers, printing the HTTP status.
2. Delegate batches of about 10 images to subagents, each working one image start-to-finish
   (signed URLs expire in 15 minutes) and writing `cases/batch-N.json` (file name to caseId,
   artifactId, name). Five parallel batches did 52 frames in 6 minutes with no failures.
3. Merge the batch files into `cases/all.json` and verify the count with
   `workflow_evals_cases_list`.

Case order in the UI is creation order, so parallel batches interleave frames; upload
sequentially when the order matters to the user, or say the UI order is not the video order.
Signed URLs may pass through the helper's arguments. They never go into a file you keep, into
the report, or into a message to the user.

### Previewing before the suite exists (Phase 2)

`workflow_specs_run` needs a public URL or base64. For a local frame use `media_upload`, the
PUT it describes (`x-goog-content-length-range`), and `media_upload_finalize`; the returned
`url` goes to `workflow_specs_run`. The upload contracts differ from Case uploads, so do not
reuse one helper for both.

## Drafting the answer key

Do not ask the user to label from zero. Draft, then let them correct.

1. Get a candidate answer per example from the first Workflow. Once the Cases exist (as
   drafts) and the Eval is created, `workflow_evals_case_preparations_start` runs the Eval's
   subject on every Case (52 frames in 44 s); `workflow_evals_case_preparations_cases`
   returns one signed `readUrl` per Case and no values, and its listing exceeds the tool
   result limit above ~40 Cases. Read it from the saved file with a script that downloads
   each artifact (the record is the Workflow's output list) and writes
   `c02-draft-outputs.json`; never paste the listing anywhere.
2. **Look at every example yourself** (the Read tool renders local images; a 12-tile sheet
   reads fine) and correct the draft where the Workflow is wrong. Your corrected draft is
   what the user reviews. The first Workflow's errors are exactly what the search must learn
   to fix; if they leak into the answer key the search optimizes toward them.
3. If the first Workflow cannot run (a provider is down, a model will not load), draft from
   your own visual review and say so in the review message and the report.
4. Mark uncertain examples: transition frames in a video, occluded objects, ambiguous counts,
   possession on wide shots. These are where the user's judgment matters most.
5. Save the draft as `answer-key-draft.json` (name, time, each answer, note, review status)
   before asking. Distinguish agent-drafted, uncertain, and user-confirmed answers; record
   which answers and rules the user confirmed rather than claiming every tile was reviewed.

## The review: uncertain examples first, full suite available

Show a small selection of uncertain examples first and ask a concrete rule question with a
recommendation: "Does re-seating an already connected bar count as connecting or placing?"
Keep the full suite available as readable contact sheets or a navigable grid.

Use `draw-vision` as routed in `SKILL.md` for media annotations. Make Case ids, video
timestamps, proposed answers, and review status readable. Scalar/classification answers need
captions, not invented boxes or masks; use geometry only when present in the ground truth.
Inspect the rendered output for legibility. Display it in the conversation when supported;
otherwise attach or open the saved artifact. If the skill is unavailable, use simple media
with adjacent text captions. Keep artifacts under `review/` for the report.

In the message, for video, group contiguous frames with the same answers into **ranges**:
`f_000 to f_017: phase=empty, done=false`, with the `?` frames listed separately. For a
folder of unrelated images, one row per example. Keep it under 60 rows; paginate otherwise.

Ask the user to flag corrections and explicitly confirm the proposed answers and rules
before marking Cases complete. Silence or an unmentioned tile is not approval. A confirmation
of the full draft is sufficient; do not require a separate response for every tile.

Apply corrections with `workflow_evals_cases_replace` (full replacement: send name, inputs,
ground truth, slices, ground-truth state, and the current `revision`; delegate
batches of 15 to subagents from a `cases/replace-*.json` file). When the user's corrections
imply a different rule ("possession on close-ups too"), update the Goal Card wording, relabel
every example the rule touches, and show the affected answers for confirmation. Keep
unconfirmed proposals `incomplete`; set `ground_truth_state: "complete"` after confirmation.

## Slices

Add a slice per answer value (for labels and booleans), one for "not applicable" examples
(`no-scoreboard`), a `transition` slice for frames within one step of a label change, and a
slice per source (`video-1`, `video-1-dense`, `shift-b`) so later additions can be reported
separately. `workflow_evals_results_overview` and `workflow_evals_results_compare` accept
slice filters.

## Shared failures are answer-key suspects

After round 1, list the examples that every gate-passing candidate gets wrong. Send them as a
sheet using `draw-vision`, with the key's answer and actual candidates' answers on each tile.
Shared misses warrant review, not an automatic key change. Confirm any correction with the
user and apply it with `cases_replace`; the next Run
scores everyone on the corrected suite (and re-executes everyone, since the snapshot changed).

## Growing the suite

The suite grows in four moments, all with the same draft-review-confirm-complete flow:

- **Coverage.** An answer value with fewer than 5 examples: first sample the same source more
  densely around those moments (1 fps in the windows that contain them added 25 frames and
  took celebration from 3 to 8), then ask for media that contains it.
- **Validation (Phase 5).** Examples from a source the search never saw, tagged with their own
  slice. The champion must win on the whole grown suite.
- **Corrections.** Shared failures and the user's later observations, in place.
- **After the session.** A production miss becomes a new example. Tell the user this at the
  end: the suite is the regression test for every future version of the Workflow.

Never split the suite into search and holdout halves. Validation is new examples, or an
honest statement that there were none.
