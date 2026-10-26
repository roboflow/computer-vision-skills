---
name: roboflow-autoresearch
description: Compare data, training, and Workflow approaches with a saved experiment log and measured recommendation. Use for autoresearch, training versus zero-shot comparisons, or research that resumes across sessions. For a plain vision goal with available examples or sources and no research tracking, use workflow-from-eval. For one training task, use roboflow-training-and-evaluation.
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `roboflow://skills/<name>/...` MCP resources serve the same skills for clients that don't have them loaded.

# Roboflow Autoresearch

Own the research scope, experiment log, and recommendation. Show named resources, reviewed examples, results, and uncertainty. Handle IDs and bookkeeping without asking the user to enter them.

## Use existing skills

Read each skill when its task becomes relevant:

| Task | Guidance |
|---|---|
| Diagnose model errors and choose a data or training change | [Model Diagnosis](../roboflow-training-and-evaluation/model-diagnosis.md), `roboflow://skills/roboflow-training-and-evaluation/model-diagnosis`; use [Data Management](../roboflow-data-management/SKILL.md) for corrections |
| Define success and score Workflows | [Workflow from Eval](../workflow-from-eval/SKILL.md), `roboflow://skills/workflow-from-eval/SKILL` |
| Label, split, and version data | [Data Management](../roboflow-data-management/SKILL.md), `roboflow://skills/roboflow-data-management/SKILL` |
| Select and train models | [Training and Evaluation](../roboflow-training-and-evaluation/SKILL.md), `roboflow://skills/roboflow-training-and-evaluation/SKILL` |
| Save goals, transition experiments, or resume | [Experiment Protocol](experiment-protocol.md), `roboflow://skills/roboflow-autoresearch/experiment-protocol` |

Adopt Workflow from Eval's Goal Card approval, reviewed ground truth, scoring, provider recovery, and media review. This skill replaces its search portfolio, later checkpoints, finalists, cleanup, and report. Objective and Experiment records replace `created.json` as the research log.

## Prepare

1. Identify the goal and available source: images, video, an existing Project, or accessible storage. Use the existing ingestion skills and tools. Use a live stream only through an already configured platform tool; do not set up capture for Autoresearch. If access or coverage is insufficient, ask for representative data. Verify access to research, data, saved Workflow, and Eval tools before resource creation or paid work. Read the Eval contract through `workflow_evals_agent_manifest` and `workflow_evals_agent_resource_get`. Verify training tools when training is part of the plan.
2. Agree on a goal of about 20 words. State the target, input, and success measure. Save requirements for the resulting Workflow in the Objective's `constraints` array, one condition per item: output behavior, accuracy, latency, throughput, inference cost, runtime, or hardware. Keep research limits for labeling, training jobs, Eval Runs, concurrency, and research spend in the working plan and handoff notes. Reserve a Run for the final comparison and set a stop condition there. Do not put methodology, findings, or progress counts in Objective constraints. Save the goal, constraints, and Project associations before experiments begin. Share cost estimates in conversation only.
3. Prepare a finite set of reviewed examples through [Ground Truth](../workflow-from-eval/ground-truth.md) (`roboflow://skills/workflow-from-eval/ground-truth`). Prefer foundation-model Auto Label: `autolabel_models_list` → `autolabel_preview` → `autolabel_start` → review and correct. Predictions remain drafts until reviewed. Reuse approved Project test annotations as Eval ground truth when they fit the contract.
4. Keep Eval examples out of training and validation so the score measures unseen examples. Preserve their split during version generation; do not rebalance them into training. Check membership before training. For video, avoid near-duplicate frames across splits. If all examples come from one clip, they provide correlated evidence, not independent validation. Keep the same examples across candidates.
5. Save the initial zero-shot Workflow. Begin a baseline record in `planned` before its Eval Run. Change it to `in_progress` when evaluation starts. Finalize it with measured results after the Run completes. A baseline has no hypothesis or outcome and needs no self-comparison. Keep it for candidate comparisons.

## Experiment

Begin each record before launching work. It starts in `planned`; this state adds no approval gate. Keep it `planned` while waiting for access, data, or label review, and save the wait reason in `note`; there is no dependency API. Change it to `in_progress` when data editing, Workflow creation, training, or evaluation starts. Clear an obsolete wait note with `note=""`. Use `kind="comparison"` for a candidate and state one small, coherent hypothesis. Group related parameter variants under one hypothesis and one Eval Run. Begin one comparison record per challenger with that shared hypothesis.

Before each round, inspect failed examples to decide whether the prediction, label, or both are wrong. Use [Model Diagnosis](../roboflow-training-and-evaluation/model-diagnosis.md) for root causes and [Data Management](../roboflow-data-management/SKILL.md) for data edits. Choose one coherent intervention:

| Lever | Examples |
|---|---|
| `data` | Correct taxonomy or labels; improve consistency, coverage, class balance, or hard negatives. |
| `training` | Change architecture, recipe, resolution, or augmentation. |
| `workflow` | Change models, prompts, thresholds, blocks, or logic. |

Set `changes` from work performed. Include `data` for collection or label corrections, `training` when a training job runs, and `workflow` for logic or parameter changes, including model reuse. Use multiple labels when the work includes multiple interventions. Data correction followed by retraining uses `data` and `training`. Reusing a model does not count as new training. Eval ground-truth corrections change the measurement: rerun the baseline and candidate on the same corrected suite, and do not claim a gain from the changed benchmark.

Explore at most two distinct candidate approaches per round. A parameter sweep of one Workflow, such as several thresholds, counts as one approach; its variants do not consume separate candidate slots. For example, a five-threshold sweep and a new model approach use two slots. Keep sweeps within the agreed work and Eval Run limits. Evaluate related variants together with their shared baseline. Record one comparison per variant, using the baseline and that variant's executions from the same Run. For a new approach, use the strongest measured candidate as baseline; for a tuned variant, use its parent. Group candidates that need different baselines into separate Runs, within the agreed limit.

For training, follow the training skill's task discovery and prefer NAS wherever supported. Prefer online recipe transforms when available; inspect the version for transforms already baked into its images. Bind trained models as `workspace/model-id`: autoresearch verifies a concrete model, not a Project version alias. The protocol explains the training evidence fields.

Save candidates with meaningful Workflow and version names. Follow [Workflow gotchas](../workflow-from-eval/gotchas.md) (`roboflow://skills/workflow-from-eval/gotchas`) for saved versions, dependency pinning, and block-specific behavior.

Compare each pair on the same frozen Eval examples, Spec, bindings, and runtime. If latency affects the choice, add the supported `latency@1` check to the Spec before the Run. Apply the approved hard limit when applicable, and set `execution_reuse="never"` for fresh measurements. Per-execution latency does not establish stream throughput.

Read scored examples and regressions. For stochastic outputs, compare fresh executions of an unchanged baseline across Runs with unchanged evaluation settings to estimate variation. Reused results do not measure noise. If the allowance cannot resolve a small gain, report uncertainty instead of claiming an improvement. Count repeats and the final original-baseline comparison within the agreed limits. State when thresholds were tuned on this same suite.

Finalize complete evidence through the protocol. Save a `training_reference` when a candidate reuses a trained model. Add `training` only when the experiment starts new training, and include only values sent to the training call. Stop at the agreed limit or stop condition; request an extension before more work. For long jobs, save their references and status, then report the pending work. Resume through the protocol without duplicating launches.

## Report

Explain measured gains, regressions, hard-constraint results, and evidence limits. Each Experiment outcome applies to its named baseline. Save completed findings even when no candidate meets the goal. Use the protocol to retain or replace the overall recommendation. Production deployment requires a separate, explicit user request.
