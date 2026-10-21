---
name: roboflow-autoresearch
description: Improve a Roboflow vision goal with native Active Learning, Workflow design, training, and Workflow Evals. Use when the user wants measured experiments and a production recommendation that they approve. Save the goal and completed results without a separate orchestration service.
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `roboflow://skills/<name>/...` MCP resources serve the same skills for clients that don't have them loaded.

# Roboflow Autoresearch

Use [Workflow from Eval](../workflow-from-eval/SKILL.md) for Workflow design, reviewed examples, and scoring.
Use [Training and Evaluation](../roboflow-training-and-evaluation/SKILL.md) for model choices, diagnosis, and training.
Read its [Active Learning guide](../roboflow-training-and-evaluation/active-learning.md) for collection and review.
Use the relative files when no installed copy is available. MCP resources are the fallback.
These native skills own execution. Autoresearch saves the goal and finalized experiment results.

The agent chooses experiments, reads native evidence, and recommends a production candidate.
The user supplies the goal, reviews ambiguous examples, agrees on success criteria, and approves production changes.
Keep internal references out of the conversation. Show named resources, scored examples, gains, regressions, uncertainty, collection behavior, and estimates.
Do not ask users to enter native IDs or bookkeeping forms.

## Save the goal and use native Active Learning

1. Resolve the named stream with `video_sources_list` and the Projects through native lookup tools or saved links.
   Agree on success criteria, important failure cases, hardware, latency, collection limits, and experiment constraints.
   Explain the estimated collection, labeling, training, inference, and deployment costs before the relevant work.
   Estimates are advisory. Normal native billing and credit checks apply.
   Once the user authorizes experiments within these constraints, do not request separate approval for each training or Eval run.
2. Find an existing saved goal with `autoresearch_objectives_list` and `autoresearch_objective_get`.
   Otherwise, save it with `autoresearch_objective_create`, including the goal, constraints, Project references, and source reference.
   Use `autoresearch_objective_update` only to revise goal text or constraints, with its ordinary edit-concurrency revision.
   Saving a goal does not launch or gate native work. Native experiments can run concurrently.
3. Read existing collection with `project_deployment_get` and `project_deployment_list_review_queues`.
   Reuse the Project Model block and native Active Learning.
   When collection needs changes, use `project_deployment_configure_active_learning` with supported limits and filters.
   Explain the destination, sampling, quotas, and saved prediction behavior.
   Use Dataset Upload only for explicit custom routing that native Active Learning does not cover.
   Do not create a separate collector or stop existing collection merely to save the goal.
4. Review predictions through native annotation tools and Label Assist in the annotator.
   Use the [data-management skill](../roboflow-data-management/SKILL.md) for Auto Label, review, and native split assignment.
   Predictions alone are not ground truth. Keep test data out of candidate tuning.
   If reviewed evidence is insufficient, collect more before making an improvement claim.

## Design, run, and measure native experiments

Choose useful changes from observed failures. Workflow design and model training are equal experiment paths.
Use the native tools directly. No preliminary Autoresearch record or approval is required to start them.

| Hypothesis | Native work | Evidence |
|---|---|---|
| A Workflow change helps | Change logic, thresholds, prompts, crops, or models that native execution supports. Save a fixed candidate. | Evaluate the complete Workflow on the same reviewed examples and scorecard as the baseline. |
| Training helps | Train on a frozen native dataset version and bind the resulting model into a fixed Workflow. | Retain the exact native configuration and resulting training/model references. Evaluate the complete Workflow. |
| Both changes help | Change the Workflow and train a model, retaining both exact inputs. | Verify the resulting complete Workflow before comparing measured outcomes. |

For training, read the training skill's [model IDs](../roboflow-training-and-evaluation/model-ids.md) and native availability.
Prefer NAS whenever native training supports the task, including detection, instance segmentation, and semantic segmentation.
Apply the same rule to future supported tasks. Respect the user's explicit model choice.
For recipe changes, read `trainings_describe_recipe` first. Keep native defaults unless the hypothesis requires a change.
Pass the complete native configuration directly as `training_config`, including `modelType` and any `trainRecipe`.
Get its native estimate with `trainings_estimate`.
Pass that same configuration and estimate to `trainings_create` with a stable native request identity.
Retain that same object as the completed record's `training` field. Do not introduce `training.extra` or a fixed architecture.
This field reports the agent's submitted inputs. The native resolved training configuration remains authoritative.
Use native estimates, request identities, status, retry, and cancellation behavior.
For NAS, select a concrete child using hardware, accuracy, and latency constraints.
Read [NAS results](../roboflow-training-and-evaluation/nas-results.md) for frontier metrics and their limits.
Model metrics select a model. They are not the Workflow Eval result.

Resolve the Project BASE dependency with `project_deployment_get`.
Use `workflows_list_versions` and `workflows_get.version_id` to inspect saved dependencies.
Save fixed candidates with `workflows_save_draft`.
Pin nested Workflow and concrete model dependencies. Saving an outer Workflow alone does not freeze mutable child graphs or Project defaults.
Preserve the intended native Active Learning configuration in the evaluated candidate.

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

## Explain and approve the production candidate

Explain the named stream and candidate, scored-example links, measured gains, regressions, uncertainty, and intended collection behavior.
Show the processor size, frame rate, runtime input values, image output, recovery behavior, and native cost estimate.
A candidate label is descriptive. The native evaluation artifact supplies the evidence.

Read `workflow_evals_executions_configuration` for the completed candidate's frozen graph and input configuration.
Use that exact evaluated graph and configuration for production. Do not reread a mutable current Workflow as a substitute.
A prior fixed Workflow can be another candidate, measured and approved through the same native operations.

Before replacing existing processing, use `video_jobs_list` to find active work on the source.
Explain the planned interruption and obtain explicit approval to stop existing production before cancellation.
Explain that declining the later create prompt leaves the stream stopped. Do not promise an automatic restart.
After that approval, cancel with `video_jobs_cancel` and read `video_jobs_get` until native state confirms processing stopped.
If stop state is uncertain, do not start overlapping production work.

Use `video_jobs_estimate` for the exact frozen graph and selected processor size.
Call `video_jobs_create` with the exact source, graph, parameters, fixed processor size, frame rate, output, and recovery behavior.
Its human elicitation approves that exact request and estimate. A refusal or unavailable prompt starts no job.
A configuration change requires fresh approval. The tool does not stop other jobs or maintain a separate deployment record.
Native jobs own permissions, billing, status, cancellation, resizing protection, and recovery.
Read native health after creation. Let Active Learning return fresh observations to the same saved goal and review queue.

Native production creation and durable training currently require an API key.
If credentials or production elicitation are unavailable, explain the limitation and do not claim that work started.

## Resume or stop

Native jobs continue after the agent disconnects. Resume through native job references and authoritative state.
Reuse native request identities for identical retries after lost responses.
Stop training with `trainings_cancel`, Evals with `workflow_evals_runs_cancel`, and video processing with `video_jobs_cancel`.
Read native status before reporting that work stopped. Do not add another retry, cancellation, or recovery system.
