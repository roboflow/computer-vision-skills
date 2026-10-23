---
name: roboflow-autoresearch
description: Run resumable Roboflow research across Workflow and training approaches, with saved experiment records and a measured recommendation. Use when the user asks to compare approaches, continue research across sessions, or keep an experiment log. Use workflow-from-eval for a one-session Workflow-only search without research records, and roboflow-training-and-evaluation for one training task.
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `roboflow://skills/<name>/...` MCP resources serve the same skills for clients that don't have them loaded.

# Roboflow Autoresearch

Autoresearch owns the research scope, experiment records, and recommendation. Use the linked skills for task-specific Workflow, labeling, dataset, and training steps. Their search portfolios, checkpoints, finalists, cleanup, and reporting apply only where this skill adopts them. Keep each baseline-candidate comparison in one Eval Run.

Use [Workflow from Eval](../workflow-from-eval/SKILL.md) (`roboflow://skills/workflow-from-eval/SKILL`) for reviewed examples and Eval scoring. Use [Training and Evaluation](../roboflow-training-and-evaluation/SKILL.md) (`roboflow://skills/roboflow-training-and-evaluation/SKILL`) for training choices and diagnosis. Use [Data Management](../roboflow-data-management/SKILL.md) (`roboflow://skills/roboflow-data-management/SKILL`) for Projects, uploads, annotations, and versions.

Keep internal IDs and bookkeeping out of the conversation. Show named resources, reviewed answers, measured results, uncertainty, and cost estimates. Do not ask the user to enter native IDs.

## Prepare the goal and evidence

1. Inspect the supplied media and resolve its Project.
2. Before creating resources or starting paid work, verify access to autoresearch, data management, Workflow version, and Workflow Eval tools. Read the Eval contract with `workflow_evals_agent_manifest` and `workflow_evals_agent_resource_get`. For training, verify its tools too. If a required capability is missing, explain the limit before dependent work. Create a suitable Project before saving the goal when none exists; you can update its Project associations later.
3. Find an existing goal with `autoresearch_objectives_list` and `autoresearch_objective_get`. If no goal exists, create one with `autoresearch_objective_create(request_id=..., goal=..., project_ids=[...])`. Use Project slugs or `workspace/project` references. MCP resolves the workspace. To associate another Project later, call `autoresearch_objective_update` with the current goal revision and the complete replacement `project_ids` list. A Project can be associated with multiple goals. Associate the training Project before `experiment.begin`. Updating Project associations advances the goal revision and clears the current recommendation while preserving history; experiments retain their original revision.
4. Agree on per-frame success criteria, important failure cases, hardware, latency, and the experiment limits. Set limits for training jobs, Eval Runs, and concurrency. Include the final comparison within those limits. Share `trainings_estimate` results as advisory conversation when useful. Never store estimate payloads in autoresearch records. Native billing and credit checks apply when training starts.
5. Prepare representative examples with [Ground Truth](../workflow-from-eval/ground-truth.md) (`roboflow://skills/workflow-from-eval/ground-truth`). Prefer supported foundation-model auto-labeling: discover models with `autolabel_models_list`, preview a sample with `autolabel_preview`, label the batch with `autolabel_start`, then review and correct annotations with the native review flow. Predictions are drafts, not ground truth.
6. Use the Project test split as a common evaluation source when it fits the task. Import approved classification or detection annotations with `workflow_evals_cases_import(ground_truth_path="$.<field>")`; every item must be a Dataset source with `split="test"`, and the import can include multiple test-split Dataset items. The mapping selects where native annotations go. It does not rename classes or labels. Confirm that the Eval contract accepts the imported values. Cases with other required fields remain incomplete until you fill them. Never train on Eval examples.
7. Save and measure a zero-shot baseline Workflow first. Freeze the examples, scorecard, bindings, and runtime within each Run. Keep the original baseline for the final comparison. Use training frames outside the suite; if they are insufficient, skip training or limit the claim. Frames from one clip are not independent validation. Say so when only one clip is available.

This skill evaluates per-frame answers. It does not set up live streams or temporal event logic. Per-execution latency is not stream throughput; test sustained throughput separately.

## Run and compare experiments

Start one experiment record for each tested approach. Set immutable `experiment_type` at begin to `workflow`, `training`, or `combined`. The type describes the full experiment and cannot change later. Keep one baseline and at most two challengers in each Run. Use the strongest measured candidate as the baseline for a new approach and its direct parent for a tuned variant. Include a final comparison with the original zero-shot baseline within the authorized Eval Run count. The baseline alone is not an experiment; never compare it with itself.

For labeling, use supported foundation models with the discover, preview, batch, and review sequence above. For training, inspect task-native model availability and prefer NAS where supported and its prerequisites pass. Use the training skill's NAS requirements and result guidance. Do not treat static model tables as authoritative.

Before training, inspect the frozen version's stored preprocessing and augmentation. Recipe transforms run during training; version transforms are already baked into the images. Disabling recipe flips does not remove flipped copies from a version. Generate a corrected version from source data when a baked transform is wrong, and record the version and submitted recipe.

When a model is used in a Workflow, bind a concrete trained model as `workspace/model-id`. Do not use `project/version` for a trained-model inference block. Read the selected model ID from `trainings_get.models[].modelId`. A dataset version number identifies training data; it is not the model ID. Pass `model_type` when the user or hypothesis selects an architecture. If omitted, let native training apply its default and leave `modelType` out of the record.

For a new candidate Workflow, create it with its real configuration using `workflows_create`. Do not create placeholder configurations. Save the candidate version with `workflows_save_draft`, inspect it with `workflows_list_versions`, then use that saved version in the Eval Run. Existing Workflows can be reused by saving a new version. Use useful Workflow and `version_name` values. Do not rename a Workflow to present a winner: `workflows_update` can publish a version and change its URL slug.

Resolve a Project BASE dependency with `project_deployment_get`. Inspect saved dependencies with `workflows_list_versions` and `workflows_get.version_id`. Pin nested Workflows and concrete model dependencies because an outer save does not freeze child graphs or Project defaults.

Run the selected baseline and up to two challengers together on the same frozen Eval suite. When the comparison needs fresh latency measurements, set `execution_reuse="never"`. Preserve the exact Eval, Run, and execution references. Read scored examples, regressions, latency, and uncertainty. Finalize only after the Run is `completed` or `partially_completed`, both selected executions are complete, and their selected Case checks are complete. A failed unrelated challenger does not block a complete comparison. `inconclusive` means complete comparable evidence cannot support a decision; never use it for incomplete evidence. State when confidence thresholds were tuned on the same Eval suite.

For a classification block, inspect `confidence_mode`. When the scorecard needs every class score, use `confidence_mode="custom"` and `custom_confidence=0`; handle an empty result explicitly in the Workflow.

Use [the experiment protocol](experiment-protocol.md) for exact lifecycle calls, payload fields, recovery, and recommendation behavior. MCP clients can read it at `roboflow://skills/roboflow-autoresearch/experiment-protocol`.

## Report and resume

Describe measured gains, regressions, latency, uncertainty, and the limits of the evidence. A candidate outcome applies only to its named baseline. Keep the current objective recommendation when new evidence does not support replacing it. Recommend a new experiment only when completed evidence supports it.

On resume, list goals, read the goal and its experiments in any state, then inspect each native job before launching anything. Reconcile active or completed work first. If a launch response was lost, search native jobs for a matching submission. A record `request_id` does not make training or Eval launches idempotent. If a launch remains ambiguous, report that before risking a duplicate paid job. If a stopped or failed record has complete native results, update its state to `in_progress` with the latest revision and references, then finalize it without restarting native jobs. Updating the record does not start or resume native jobs. Read authoritative native status before reporting a stop. Cancel training with `trainings_cancel` and Eval Runs with `workflow_evals_runs_cancel` when requested.

Save completed findings before ending. Recommend a candidate only when it meets the goal's hard constraints and the evidence supports it; otherwise leave the overall recommendation unset and explain what remains unresolved. Production deployment requires a separate, explicit user request.
