---
name: roboflow-autoresearch
description: Improve a vision goal from a video clip through measured Workflow design and native training experiments. Use when the user wants the agent to prepare reviewed examples, compare approaches, and save a recommendation and learning. Prefer native NAS when the task supports it.
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `roboflow://skills/<name>/...` MCP resources serve the same skills for clients that don't have them loaded.

# Roboflow Autoresearch

Use [Workflow from Eval](../workflow-from-eval/SKILL.md) (`roboflow://skills/workflow-from-eval/SKILL`) for Workflow design, reviewed examples, and scoring.
Use [Training and Evaluation](../roboflow-training-and-evaluation/SKILL.md) (`roboflow://skills/roboflow-training-and-evaluation/SKILL`) for model choices, diagnosis, and training.
Use [Data Management](../roboflow-data-management/SKILL.md) (`roboflow://skills/roboflow-data-management/SKILL`) for frame uploads, labeling, review, and split assignment.
Use relative files when no installed copy is available; use the exact MCP resource URIs when resource access is available.
If a delegated agent cannot read MCP resources, include the needed skill guidance and exact tool parameters in its text handoff.
These native skills own execution. Autoresearch saves the goal, experiment progress, finalized results, and any supported overall recommendation.

The pilot starts with a video clip. The agent prepares examples, chooses experiments, reads evidence, and recommends a candidate.
The user supplies the goal, reviews proposed answers, and agrees on success criteria and experiment constraints.
Keep internal references out of the conversation. Show named resources, scored examples, gains, regressions, uncertainty, and estimates.
Do not ask users to enter native IDs or bookkeeping forms.

## Prepare the clip and save the goal

1. Inspect the supplied video clip and resolve the named Projects through native lookup tools or saved links.
   If no suitable Project exists, create one through native data management before saving the Objective.
   Agree on per-frame success criteria, important failure cases, hardware, latency, and experiment constraints.
   Share optional, advisory estimates for labeling, training, and inference before the relevant work.
   For training estimates, report `typicalEstimatedCredits` as the typical estimate and `estimatedCredits` as the full-runtime estimate. Neither is a spending cap.
   Native billing and credit checks apply when work starts.
   Once the user authorizes experiments within these constraints, do not request separate approval for each training or Eval run.
2. Find an existing saved goal with `autoresearch_objectives_list` and `autoresearch_objective_get`.
   Otherwise, use `autoresearch_objective_create` to save the goal, constraints, and Project references (`projectIds`).
   Let MCP resolve the authenticated workspace. Pass each Project by slug or `workspace/project` reference.
   Use `autoresearch_objective_update` only to revise goal text or constraints, with its ordinary edit-concurrency revision.
   Saving a goal does not launch or gate native work. Native experiments can run concurrently.
3. Prepare representative frames with the [Workflow example guide](../workflow-from-eval/ground-truth.md) (`roboflow://skills/workflow-from-eval/ground-truth`).
   Cover common scenes, rare failures, negatives, and ambiguous examples. Retain frame timestamps for review.
   Draft the answer key yourself and show readable images with proposed answers.
   Use Label Assist or Auto Label for annotation drafts, then obtain reviewed truth through the native review flow.
   Predictions alone are not ground truth. Record which answers and rules the user approved.
4. Before training or tuning, save and evaluate a zero-shot baseline Workflow on the reviewed Eval suite.
   Keep the selected examples, scoring, bindings, and runtime fixed across Workflows within each Run. The reviewed suite can grow between Runs.
   Never train on Eval suite examples.
   Use training frames outside the suite. If there are not enough, ask for more training data or skip training and limit the claim.
   Frames from the same clip are not independent validation, even when their timestamps differ.
   If only one clip is available, call the result a search on that clip and state that independent validation is unavailable.
   Do not claim generalization to unseen scenes without a separate source or genuinely unseen examples.
   If reviewed evidence is insufficient, prepare more examples before making an improvement claim.

This pilot evaluates per-frame answers. It does not configure live streams, Active Learning, or temporal event machinery.
An Eval's per-execution latency is not sustained stream throughput. For a serial pipeline, an N-FPS target gives a latency budget of 1000/N milliseconds per frame; concurrency and sustained throughput need a separate stream test.
Per-frame results can flicker across time. Duration rules and stream-level smoothing need a separate evaluation and are outside this pilot.
Use existing media and dataset tools. Do not introduce video ingestion APIs or new video entities.

## Design, run, and measure native experiments

Choose useful changes from observed failures. The zero-shot baseline is the first measured comparison point.
Keep the first zero-shot baseline for the final comparison. Use the current strongest eligible candidate as the baseline for new approaches; use a candidate's direct parent for its tuned variants.
For each Autoresearch round, evaluate the selected baseline and at most two challenger Workflows. This limit overrides larger portfolio counts in Workflow from Eval for this pilot.
Threshold variants count toward the two-challenger limit. Variants that test one question share one experiment log, but still count as separate challengers.
Start the experiment log before launching native work. Update the same log entry when the run completes, stops, or fails.
Use the native tools directly. No separate approval is required for each run after the user authorizes the agreed experiment constraints.

| Hypothesis | Native work | Evidence |
|---|---|---|
| A Workflow change helps | Change logic, thresholds, prompts, crops, or models that native execution supports. Save a fixed candidate. | Evaluate the complete Workflow on the same reviewed examples and scorecard as the baseline. |
| Training helps | Train on a frozen native dataset version and bind the resulting model into a fixed Workflow. | Retain the exact native training parameters and resulting training/model references. Evaluate the complete Workflow. |
| Both changes help | Change the Workflow and train a model, retaining both exact inputs. | Verify the resulting complete Workflow before comparing measured outcomes. |

For training, read the training skill's [model IDs](../roboflow-training-and-evaluation/model-ids.md) (`roboflow://skills/roboflow-training-and-evaluation/model-ids`) and native availability.
Prefer NAS whenever native training supports the task, including detection, instance segmentation, and semantic segmentation.
Apply the same rule to future supported tasks. Respect the user's explicit model choice.
For recipe changes, read `trainings_describe_recipe` first. Use supported recipe preprocessing and augmentation. Create a new Dataset Version only for data or split changes, or for transforms the recipe cannot express.
Keep native defaults unless the hypothesis requires a change.
Pass `model_type`, `train_recipe`, `epochs`, and other supported training fields as separate native parameters.
Record only values actually submitted in `training`, using native field names such as `modelType` and `trainRecipe`.
Do not reconstruct omitted defaults. Native validation owns model-specific input sizes and compatibility; use its accepted values and errors.
When useful, call `trainings_estimate` with the same inputs as `trainings_create` and share both returned credit estimates with their labels. They estimate cost; they do not cap the run.
Native billing and credit checks apply when training starts.
Use native status and cancellation behavior.
For NAS, select a concrete child using hardware, accuracy, and latency constraints.
Read [NAS results](../roboflow-training-and-evaluation/nas-results.md) (`roboflow://skills/roboflow-training-and-evaluation/nas-results`) for frontier metrics and their limits.
Model metrics select a model. They are not the Workflow Eval result.

If a candidate uses a Project BASE dependency, resolve it with `project_deployment_get`.
Use `workflows_list_versions` and `workflows_get.version_id` to inspect saved dependencies.
Save every recordable candidate with `workflows_save_draft` before creating its Eval Run. Give it a useful `version_name`; this creates a saved version without publishing it.
Use `workflows_list_versions` and inspect the saved version before running. Build each Run subject as `savedWorkflowVersion` and retain the exact Workflow ID and version ID.
If a save response is unclear, inspect Workflow versions and the saved draft before trying again.
Pin nested Workflow and concrete model dependencies. Saving an outer Workflow alone does not freeze mutable child graphs or Project defaults.
Keep the pilot candidate focused on per-frame outputs.

Use native Workflow Eval start or replay to evaluate the selected baseline and up to two challengers together in the same frozen Run.
Preserve its examples, scoring, bindings, and runtime. Compatible results from separate Runs do not satisfy the record contract.
Native Eval execution suppresses collection sinks automatically.
Read completed results and inspect scored examples, regressions, latency, and uncertainty.
Retain the exact Eval ID, Run ID, and execution IDs for every comparison.
Record a comparison when its baseline and candidate executions and case checks are complete, even if another candidate in the Run failed. Do not record a comparison whose own evidence is incomplete.
If native work is incomplete or its evidence is incompatible, explain the limitation without recording it.
Only completed, comparable results can finalize an experiment. A completed comparison with uncertain conclusions can use the `inconclusive` outcome.

When testing confidence thresholds on the same Eval suite, state that the threshold was tuned on that suite. Report the selected threshold and treat its score as a search result, not independent validation.

## Record the completed result

Before launching native training or Eval work, call `autoresearch_experiment_begin` with a name, hypothesis, fixed baseline, and stable `request_id`. Reuse that identity for the whole hypothesis, including small variants. Finalize with the most informative comparison; summarize the other variants in its rationale and link their native results.
After launch, update that same entry with `autoresearch_experiment_update` using `state="in_progress"` and any available native references.
If work stops or fails, update the same entry with `state="stopped"` or `state="failed"` and a short note. Do not create a second entry for the status change.
To resume, update that entry back to `state="in_progress"` with its latest revision and current native references before continuing.

After native work completes and its evidence is verified, call `autoresearch_experiment_finalize` with the same `request_id` and experiment name to finalize that entry. The server marks it completed only after it verifies the evidence. Include:

- The saved goal, a stable identity for this record, and the tested hypothesis.
- Exact `baseline_workflow` and `candidate_workflow` references, each with `workflowId` and `versionId` from the `savedWorkflowVersion` Run subjects.
- Native `evidence` with `evalId`, `runId`, `baselineExecutionId`, and `candidateExecutionId`.
- An `outcome` of `recommended`, `rejected`, or `inconclusive`, assessed only against the named baseline. `recommended` does not set the objective's current pick; use `autoresearch_objective_recommend` for that.
- A `rationale` shown on the recommendation card. State measured evidence, limitations, uncertainty, and the next step. Summarize other variants and link their native results when one comparison represents a group.
- For training, only the values actually submitted in `training`, plus `training_reference` with Project, version, training, and selected model references.
- Optional advisory `estimate` values and notes.

The server verifies native evidence and provenance. The agent assesses the result and explains its recommendation.
Recording a result starts no jobs and changes no production state.
Use `autoresearch_experiment_get` to resume from a saved result and its native references.

## Recommend and save learning

Explain the candidate, scored-example links, measured gains, regressions, per-execution latency, uncertainty, and labeled cost estimates.
State which Workflow and training hypotheses helped, failed, or remain unresolved. At the end, evaluate the selected candidate against the original zero-shot Workflow in the same Run and record that comparison. Name an overall recommendation only when the evidence supports one.
When the evidence supports a winner, call `autoresearch_objective_recommend` with its completed experiment ID and the current goal revision. If no candidate is supported, leave the objective without an overall recommendation and explain the evidence gap.
Distinguish search results from independent validation. If thresholds were tuned on the Eval suite or only one clip was available, say so.
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
