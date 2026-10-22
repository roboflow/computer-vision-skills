---
name: roboflow-autoresearch
description: Improve a vision goal from a video clip through measured Workflow design and native training experiments. Use when the user wants the agent to prepare reviewed examples, compare approaches, and save a recommendation and learning. Prefer native NAS when the task supports it.
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `roboflow://skills/<name>/...` MCP resources serve the same skills for clients that don't have them loaded.

# Roboflow Autoresearch

Use [Workflow from Eval](../workflow-from-eval/SKILL.md) for Workflow design, reviewed examples, and scoring.
Use [Training and Evaluation](../roboflow-training-and-evaluation/SKILL.md) for model choices, diagnosis, and training.
Use [Data Management](../roboflow-data-management/SKILL.md) for frame uploads, Label Assist, Auto Label, review, and split assignment.
Use the relative files when no installed copy is available. MCP resources are the fallback.
These native skills own execution. Autoresearch saves the goal and finalized experiment results.

The pilot starts with a video clip. The agent prepares examples, chooses experiments, reads evidence, and recommends a candidate.
The user supplies the goal, reviews proposed answers, and agrees on success criteria and experiment constraints.
Keep internal references out of the conversation. Show named resources, scored examples, gains, regressions, uncertainty, and estimates.
Do not ask users to enter native IDs or bookkeeping forms.

## Prepare the clip and save the goal

1. Inspect the supplied video clip and resolve the named Projects through native lookup tools or saved links.
   If no suitable Project exists, create one through native data management before saving the Objective.
   Agree on per-frame success criteria, important failure cases, hardware, latency, and experiment constraints.
   Share optional, advisory estimates for labeling, training, and inference before the relevant work.
   Native billing and credit checks apply when work starts.
   Once the user authorizes experiments within these constraints, do not request separate approval for each training or Eval run.
2. Find an existing saved goal with `autoresearch_objectives_list` and `autoresearch_objective_get`.
   Otherwise, use `autoresearch_objective_create` to save the goal, constraints, and Project references (`projectIds`).
   Use `autoresearch_objective_update` only to revise goal text or constraints, with its ordinary edit-concurrency revision.
   Saving a goal does not launch or gate native work. Native experiments can run concurrently.
3. Prepare representative frames with the [Workflow example guide](../workflow-from-eval/ground-truth.md).
   Cover common scenes, rare failures, negatives, and ambiguous examples. Retain frame timestamps for review.
   Draft the answer key yourself and show readable images with proposed answers.
   Use Label Assist or Auto Label for annotation drafts, then obtain reviewed truth through the native review flow.
   Predictions alone are not ground truth. Record which answers and rules the user approved.
4. Keep training data, tuning examples, and final evaluation examples separate.
   Avoid near-duplicate frames across these groups. Reserve unseen scenes or another clip for final validation.
   The Workflow suite still grows as its guide describes. Do not split an existing suite or train on its examples.
   If only one clip exists, explain coverage limits and avoid claims about unseen conditions.
   If reviewed evidence is insufficient, prepare more examples before making an improvement claim.

This pilot evaluates per-frame answers. It does not configure live streams, Active Learning, or temporal event machinery.
Use existing media and dataset tools. Do not introduce video ingestion APIs or new video entities.

## Design, run, and measure native experiments

Choose useful changes from observed failures. Workflow design and model training are equal experiment paths.
Use the native tools directly. No preliminary Autoresearch record or approval is required to start them.

| Hypothesis | Native work | Evidence |
|---|---|---|
| A Workflow change helps | Change logic, thresholds, prompts, crops, or models that native execution supports. Save a fixed candidate. | Evaluate the complete Workflow on the same reviewed examples and scorecard as the baseline. |
| Training helps | Train on a frozen native dataset version and bind the resulting model into a fixed Workflow. | Retain the exact native training parameters and resulting training/model references. Evaluate the complete Workflow. |
| Both changes help | Change the Workflow and train a model, retaining both exact inputs. | Verify the resulting complete Workflow before comparing measured outcomes. |

For training, read the training skill's [model IDs](../roboflow-training-and-evaluation/model-ids.md) and native availability.
Prefer NAS whenever native training supports the task, including detection, instance segmentation, and semantic segmentation.
Apply the same rule to future supported tasks. Respect the user's explicit model choice.
For recipe changes, read `trainings_describe_recipe` first. Keep native defaults unless the hypothesis requires a change.
Pass `model_type`, `train_recipe`, `epochs`, and other supported training fields as separate native parameters.
Record the submitted values directly in `training`, using native field names such as `modelType` and `trainRecipe`.
The native resolved training configuration remains authoritative.
When useful, call `trainings_estimate` with the same inputs as `trainings_create` and share its advisory estimate.
Native billing and credit checks apply when training starts.
Use native status and cancellation behavior.
For NAS, select a concrete child using hardware, accuracy, and latency constraints.
Read [NAS results](../roboflow-training-and-evaluation/nas-results.md) for frontier metrics and their limits.
Model metrics select a model. They are not the Workflow Eval result.

If a candidate uses a Project BASE dependency, resolve it with `project_deployment_get`.
Use `workflows_list_versions` and `workflows_get.version_id` to inspect saved dependencies.
Save fixed candidates with `workflows_save_draft`.
Pin nested Workflow and concrete model dependencies. Saving an outer Workflow alone does not freeze mutable child graphs or Project defaults.
Keep the pilot candidate focused on per-frame outputs.

Use native Workflow Eval start or replay to evaluate baseline and candidate together in the same frozen Run.
Preserve its examples, scoring, bindings, and runtime. Compatible results from separate Runs do not satisfy the record contract.
Native Eval execution suppresses collection sinks automatically.
Read completed results and inspect scored examples, regressions, latency, and uncertainty.
If native work is incomplete or its evidence is incompatible, explain the limitation without recording it.
Only completed, comparable results can be saved. A completed comparison with uncertain conclusions can use the `inconclusive` outcome.

## Record the completed result

After native work completes, call `autoresearch_experiment_record` with:

- The saved goal, a stable identity for this record, and the tested hypothesis.
- Exact `baseline_workflow` and `candidate_workflow` references, each with `workflowId` and `versionId`.
- Native `evidence` with `evalId`, `runId`, `baselineExecutionId`, and `candidateExecutionId`.
- An `outcome` of `recommended`, `rejected`, or `inconclusive`, with an evidence-based `rationale`.
- For training, the complete native `training` object and `training_reference` with Project, version, training, and selected model references.
- Optional advisory `estimate` values and notes.

The server verifies native evidence and provenance. The agent assesses the result and explains its recommendation.
Recording a result starts no jobs and changes no production state.
Use `autoresearch_experiment_get` to resume from a saved result and its native references.

## Recommend and save learning

Explain the candidate, scored-example links, measured gains, regressions, latency, uncertainty, and cost estimates.
State which Workflow and training hypotheses helped, failed, or remain unresolved.
Distinguish search results from results on unseen evaluation examples.
A candidate label is descriptive. The native evaluation artifact supplies the evidence.

Save completed experiments and their rationale before finishing the pilot.
Use the saved goal and result references to resume future research without repeating completed experiments.
A recommendation and saved learning complete the pilot, even if no candidate meets the goal.
Explain the remaining evidence or constraints when the result is inconclusive.

Production deployment is a separate, optional task that requires an explicit user request.
That future task must use native deployment tools and their exact configuration approval requirements.
It is not a prerequisite for completing this pilot.

## Resume or stop

Native training and Eval jobs continue after the agent disconnects. Resume through native references and authoritative state.
Stop training with `trainings_cancel` and Evals with `workflow_evals_runs_cancel`.
Read native status before reporting that work stopped.
