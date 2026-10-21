---
name: roboflow-autoresearch
description: Improve a Roboflow stream-based vision task with a bounded loop over native data collection, a fixed Workflow Eval, and one Workflow or model-training candidate at a time. Use when a user gives a stream, goal, and constraints and wants evidence-led improvement and production deployment.
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `roboflow://skills/<name>/...` MCP resources serve the same skills for clients that don't have them loaded.

# Roboflow Autoresearch

Use this skill with [`workflow-from-eval`](../workflow-from-eval/SKILL.md) for Workflow design and
[`roboflow-training-and-evaluation`](../roboflow-training-and-evaluation/SKILL.md) for model training.
Those skills own model selection, training, and diagnosis guidance. Autoresearch adds an Objective and
Experiment journal. It uses native Workflows, video jobs, data management, training, and Eval
operations. Do not create separate capture, retry, cancel, estimate, start, or deployment
systems.

The user chooses the stream, goal, and constraints. Help collect and label useful examples,
define a scorecard, compare one candidate at a time, and recommend a result. The user must
approve production promotion, replacement, or rollback.

## Set up the Objective and data

1. Ask which stream to use and what result matters. Agree on success measures, failure cases,
   production constraints, Project, sampling, quotas, and estimated spend. Explain that stream
   processing and labeling cost extra. Confirm the setup work, including collection and the seed
   Eval baseline, within the agreed limits. The
   Objective budget limits cumulative Experiment estimates. It is not a hard cap on actual
   charges; report estimates and let server admission checks enforce the limit.
2. Prepare the Project and native data collection before creating the Objective. Build and
   validate a collector Workflow with a `roboflow_core/roboflow_dataset_upload@v2` sink. Save a
   new Workflow with `workflows_create` or update an existing one with `workflows_update`, then
   run it on the selected stream with `video_jobs_create`. Read the installed sink manifest
   before setting fields. It supports probabilistic `data_percentage`, `minutely_usage_limit`,
   `hourly_usage_limit`, `daily_usage_limit`, a `usage_quota_name`, `labeling_batch_prefix`,
   `labeling_batches_recreation_frequency`, and `metadata`. Agree on sampling, quotas, and batch
   naming with the user. Enable `persist_predictions` only when predictions are useful pre-labels.
   Native sink quotas control collection volume. Poll the job with `video_jobs_get`.
3. When enough data is collected, stop the collector with `video_jobs_cancel` and verify its
   terminal state with `video_jobs_get`. Reuse useful captured pre-labels. Prefer native Auto
   Label for batches that need initial labels. For foundation models, call `autolabel_models_list`
   to check availability, supported
   Project types, guidance, and cost. Use `autolabel_preview` on representative samples to select
   a model and ontology; previews are for model selection, not bulk labeling. Start the batch
   with `autolabel_start`, using `model_type="foundational"`, the selected model, and an explicit
   `num_images_to_label` within the agreed labeling budget. A suitable trained Roboflow model
   can instead use `model_type="roboflow"`. Poll `autolabel_job_get` with the returned `jobId`.
4. Review the returned `annotationJobId`, or the existing annotation job for captured pre-labels,
   with native annotation job and image tools. Check generated labels against the images and
   correct errors with the matching annotation tool. Use Label Assist in the native annotator
   for interactive corrections. Model predictions alone are not Eval ground truth. Accept reviewed
   images into the Dataset with `annotation_jobs_accept_into_dataset`, setting explicit train, valid, and
   test counts. Keep the test split out of candidate tuning. If there is not enough reviewed data
   for a meaningful test, say so and collect more before making a strong claim.
5. Generate and inspect a frozen Dataset version with `versions_generate` and `versions_get` when
   training needs it. Use the user's selected Project and version. Follow the training skill for
   model selection, checkpoints, version readiness, and training configuration. Native tools
   determine current task support and workspace availability.
6. Build a seed Workflow and native Workflow Eval using `workflow-from-eval` and `workflow_evals_*`
   tools. Read the Eval resources for valid case, check, and runtime schemas. Run the seed
   Workflow on the Eval and save its completed baseline Run and Execution before creating the
   Objective. The baseline must be measured and bound before any Experiment can be proposed.
7. Create the Objective with `autoresearch_objective_create`, using a stable `request_id`, source
   ID, goal, and selected Project IDs. It claims the source and Projects. Stop the collector first:
   after the claim, native jobs on this source require a quoted production change. Read it with
   `autoresearch_objective_get`.
8. Configure the Objective with the exact baseline Run and Execution IDs, plus
   `baselineWorkflow`, `evalId`, `scorePolicy`,
   `runtimePolicy: {kind: "serverless", fingerprint: ...}`, and
   `limits: {roboflowCredits, externalCosts}`. Confirm the Objective is `ready` and has bound
   baseline evidence before proposing an Experiment. The configuration schema can omit baseline
   IDs for incomplete setup, but that state cannot admit Experiments.

Keep the Eval cases and score policy fixed within each comparison epoch. When they change, start
a new epoch, measure and bind its baseline, and do not compare its scores with the previous one.

## Compare one candidate

Choose the change that best tests the current hypothesis: Workflow design, training, or both.
Prefer changing one axis at a time. Each step compares one baseline with one candidate; do not
start a large candidate portfolio.

1. For a Workflow candidate, start from the seed or another saved Workflow. Save the proposed
   version as an unpublished draft with `workflows_save_draft`. Pass its `workflowId` and
   `draftVersionId` as `candidateWorkflow: {workflowId, versionId}`. For a training candidate,
   follow the training skill's model-selection guidance and read its
   [model IDs](../roboflow-training-and-evaluation/model-ids.md) before choosing an architecture.
   Prefer NAS whenever native training supports it for the task because it searches the accuracy/latency Pareto frontier.
   This includes object detection, instance segmentation, semantic segmentation, and future
   tasks with native NAS support. Use native availability and preflight checks for workspace
   access and data requirements. Respect an explicit model choice. If NAS is unavailable, use
   the training skill's fallback guidance. Retain native defaults unless the hypothesis needs a
   specific change. For recipe tuning, read `trainings_describe_recipe` before changing its template.
   Store the complete native configuration directly in `training`, including `modelType` and any
   native `trainRecipe`. Preserve the configuration unchanged for the native launch.
   Training also needs a Project dataset version; Workflow-only proposals omit it. After
   training finishes, save a candidate draft from the frozen Workflow template that references
   the returned model weights. For combined changes, start from the exact `candidateWorkflow`
   template saved in the proposal.
2. Call `autoresearch_experiment_propose` with a stable request ID, current Objective
   revision, Objective Project ID, hypothesis, and candidate reference. Include `training`
   and `version_id` only when the candidate includes training. The server calculates native
   estimates and checks the cumulative Objective estimate budget. No Experiment approval,
   estimate, or start tool exists.
3. Read the Experiment for its stable training child request ID. For a training candidate,
   call native `trainings_create` with the proposal's `training` object unchanged as
   `training_config`, plus `expected_credits`, `expected_billing_system`, and
   `idempotency_key` from the Experiment. Do not ask for per-training approval. Read queued
   work with `trainings_get` using `task_id` and `launch_request_id`; use its native training
   ID after it starts. If the run is NAS, select one concrete child from the completed frontier
   using the user's hardware, accuracy, and latency constraints. Read
   [NAS results](../roboflow-training-and-evaluation/nas-results.md) for child metrics and recommendation limits.
   Mining metrics help select the model; they are not
   the Workflow Eval result. Bind the selected child into the saved Workflow and compare that
   Workflow on the fixed Eval.
4. Read the stable Evaluation child request ID from the Experiment. Select the source Run and
   Execution from the best kept candidate in this epoch, or from the Objective's baseline
   evidence when no candidate is kept. Replay that Run with `workflow_evals_runs_replay`, using
   exactly two `executions`: `baseline` points to the selected baseline saved Workflow version
   and includes its `sourceExecutionId`; `candidate` points to the saved candidate Workflow
   version and omits `sourceExecutionId`. Both entries use the same saved `bindingSet` from the
   source Execution. Keep the source Run's inference runtime and pass the Experiment's evaluation
   `requestId` as `idempotency_key`. Do not use `workflow_evals_runs_start` for an Experiment.
   Poll with `workflow_evals_runs_get` and inspect results. Do not ask for per-Eval approval. Use
   `workflow_evals_runs_retry_failed` or `workflow_evals_runs_cancel` for native retry or cancel
   actions allowed by the Run state.
5. Attach the saved candidate Workflow/version and completed Eval run with
   `autoresearch_experiment_record_evidence`. Compare measured scores, costs, and constraints
   with the baseline. Call `autoresearch_experiment_decide` to apply the keep policy. Report
   the result before proposing the next single candidate.

If training changes the model weights used by the Workflow, evaluate the Workflow version
that references those weights. Do not say the model improved until the fixed Eval measures it.

## Stop and deploy

`autoresearch_experiment_cancel` records stop intent and blocks new child work. It does not
cancel native jobs. Use `trainings_cancel` or `workflow_evals_runs_cancel` to stop active
native work, then read the Experiment until it settles. Use native tools to read or retry jobs.

Recommend the best measured candidate with its scorecard, estimate, limits, and reason it
meets the user's constraints. The user must approve production promotion, replacement, or
rollback. For a stream change, call `video_jobs_quote` with the selected target and current
Objective revision. Show the exact quoted change and estimate. Then pass the quote unchanged
to `video_jobs_create`. That tool requests explicit approval for the production change and
fails closed when the client cannot collect approval. Use `video_jobs_get` and
`video_jobs_cancel` for native job status and stop actions.

After deployment, continue collecting with the native Dataset Upload Workflow, review new
labels through native annotation tools, and use native Dataset versions and Workflow Evals
for future comparisons.

## Verified tool names

Objective and Experiment: `autoresearch_objective_create`, `autoresearch_objective_get`,
`autoresearch_objectives_list`, `autoresearch_objective_configure`,
`autoresearch_experiment_propose`, `autoresearch_experiment_get`,
`autoresearch_experiment_record_evidence`, `autoresearch_experiment_decide`, and
`autoresearch_experiment_cancel`.

Native collection and data: `video_jobs_create`, `video_jobs_get`, `video_jobs_cancel`,
`image_upload`, `image_upload_status`, `video_upload`, `video_upload_status`,
`autolabel_models_list`, `autolabel_preview`, `autolabel_start`, `autolabel_job_get`,
`annotation_jobs_list`, `annotation_jobs_get`, `annotation_jobs_review_images`,
`annotation_jobs_accept_into_dataset`, `annotations_save`, `versions_generate`, and
`versions_get`. Native Workflow authoring: `workflows_create`, `workflows_update`, and
`workflows_save_draft`. Native training:
`trainings_create`, `trainings_get`, `trainings_cancel`, and `trainings_list`. Native Eval:
use the applicable `workflow_evals_*` tools, including `workflow_evals_runs_start`,
`workflow_evals_runs_get`, `workflow_evals_runs_cancel`, and
`workflow_evals_runs_retry_failed`.

For Workflow candidate design, read `workflow-from-eval`. For model choices and metrics, read
`roboflow-training-and-evaluation`.
