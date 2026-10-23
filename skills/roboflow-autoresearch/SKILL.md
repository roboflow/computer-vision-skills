---
name: roboflow-autoresearch
description: Compare Workflow and training approaches with a saved experiment log and measured recommendation. Use for autoresearch, training versus zero-shot comparisons, or research that resumes across sessions. For a plain vision goal plus images or video without research tracking, use workflow-from-eval. For one training task, use roboflow-training-and-evaluation.
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `roboflow://skills/<name>/...` MCP resources serve the same skills for clients that don't have them loaded.

# Roboflow Autoresearch

Own the research scope, experiment log, and recommendation. Show named resources, reviewed examples, results, and uncertainty. Handle IDs and bookkeeping without asking the user to enter them.

## Use existing skills

Read each skill when its task becomes relevant:

| Task | Guidance |
|---|---|
| Define success and score Workflows | [Workflow from Eval](../workflow-from-eval/SKILL.md), `roboflow://skills/workflow-from-eval/SKILL` |
| Label, split, and version data | [Data Management](../roboflow-data-management/SKILL.md), `roboflow://skills/roboflow-data-management/SKILL` |
| Select and train models | [Training and Evaluation](../roboflow-training-and-evaluation/SKILL.md), `roboflow://skills/roboflow-training-and-evaluation/SKILL` |
| Save goals, transition experiments, or resume | [Experiment Protocol](experiment-protocol.md), `roboflow://skills/roboflow-autoresearch/experiment-protocol` |

Adopt Workflow from Eval's Goal Card approval, reviewed ground truth, scoring, provider recovery, and media review. This skill replaces its search portfolio, later checkpoints, finalists, cleanup, and report. Objective and Experiment records replace `created.json` as the research log.

## Prepare

1. Inspect the supplied clip. Verify access to research, data, saved Workflow, and Eval tools before dependent resource creation or paid work. Read the Eval contract through `workflow_evals_agent_manifest` and `workflow_evals_agent_resource_get`. Verify training tools when training is part of the plan.
2. Agree on per-frame success criteria, hard constraints, hardware, and latency. Set limits for labeling, training jobs, Eval Runs, and concurrency, plus a stop condition. Reserve a Run for the final comparison. Save these agreements in the Objective's `constraints` before experiments begin, using the protocol. Settle its goal and Project associations at the same time. Share cost estimates in conversation only.
3. Prepare reviewed examples through [Ground Truth](../workflow-from-eval/ground-truth.md) (`roboflow://skills/workflow-from-eval/ground-truth`). Prefer foundation-model Auto Label: `autolabel_models_list` → `autolabel_preview` → `autolabel_start` → review and correct. Predictions remain drafts until reviewed. Reuse approved Project test annotations as Eval ground truth when they fit the contract.
4. Keep Eval examples out of training and validation so the score measures unseen examples. Preserve their split during version generation; do not rebalance them into training. Verify membership before training. One clip still gives correlated search evidence, not independent validation. Temporal separation and live streams are outside this pilot.
5. Save and measure a zero-shot Workflow first. Retain it for the final comparison. The baseline alone needs no Experiment record or self-comparison.

## Experiment

Begin each record before launching work, using the protocol's immutable experiment type. Each Run has one baseline and at most two challengers. For a new approach, use the strongest measured candidate as baseline; for a tuned variant, use its parent. Group challengers that need different baselines into separate Runs, within the agreed limit.

For training, follow the training skill's task discovery and prefer NAS wherever supported. Prefer online recipe transforms when available; inspect the version for transforms already baked into its images. Bind trained models as `workspace/model-id`: autoresearch verifies a concrete model, not a Project version alias. The protocol explains the training evidence fields.

Save candidates with meaningful Workflow and version names. Follow [Workflow gotchas](../workflow-from-eval/gotchas.md) (`roboflow://skills/workflow-from-eval/gotchas`) for saved versions, dependency pinning, and block-specific behavior.

Compare each pair on the same frozen Eval examples, Spec, bindings, and runtime. If latency affects the choice, add the supported `latency@1` check to the Spec before the Run. Apply the approved hard limit when applicable, and set `execution_reuse="never"` for fresh measurements. Per-execution latency does not establish stream throughput.

Read scored examples and regressions. For stochastic outputs, compare fresh executions of an unchanged baseline across Runs with unchanged evaluation settings to estimate variation. Reused results do not measure noise. If the allowance cannot resolve a small gain, report uncertainty instead of claiming an improvement. Count repeats and the final original-baseline comparison within the agreed limits. State when thresholds were tuned on this same suite.

Finalize complete evidence through the protocol. Stop at the agreed limit or stop condition; request an extension before more work. For long jobs, save their references and status, then report the pending work. Resume through the protocol without duplicating launches.

## Report

Explain measured gains, regressions, hard-constraint results, and evidence limits. Each Experiment outcome applies to its named baseline. Save completed findings even when no candidate meets the goal. Use the protocol to retain or replace the overall recommendation. Production deployment requires a separate, explicit user request.
