# Autoresearch Experiment Protocol

Read this page before saving a goal, changing an experiment state, or resuming research.

## Lifecycle

| When | Call | Fields |
|---|---|---|
| Find saved work | `autoresearch_objectives_list` → `autoresearch_objective_get` | — |
| Save a goal | `autoresearch_objective_create` | `request_id`, `goal`, `project_ids`; optional `constraints` |
| Revise a goal | `autoresearch_objective_update` | `objective_id`, `expected_revision`, `goal`; optional `constraints`, replacement `project_ids` |
| Begin a measured baseline | `autoresearch_experiment_begin` | `objective_id`, `request_id`, `name`, `kind="baseline"`, `workflow` |
| Begin a candidate comparison | `autoresearch_experiment_begin` | `objective_id`, `request_id`, `name`, `kind="comparison"`, `hypothesis`, `baseline_workflow`; optional `changes` |
| Record progress or resume | `autoresearch_experiment_update` | `objective_id`, `experiment_id`, `expected_revision`, `state`, optional `native_references` |
| Record baseline evidence | `autoresearch_experiment_finalize` | `objective_id`, same `request_id`, `kind="baseline"`, `workflow`, `evidence`, `rationale` |
| Record comparison evidence | `autoresearch_experiment_finalize` | `objective_id`, same `request_id`, `kind="comparison"`, `hypothesis`, `baseline_workflow`, `candidate_workflow`, `evidence`, `outcome`, `rationale` |
| Select an overall recommendation | `autoresearch_objective_recommend` | `objective_id`, completed `experiment_id`, goal `expected_revision` |

Write a goal in about 20 words. State the target, input or source, and success measure.

Save each requirement for the resulting Workflow as one condition in `constraints`. For example: `["Run on Roboflow Serverless.", "Keep p95 latency below 200 ms."]` Research rounds, job counts, concurrency, search strategy, and research spend belong in the working plan and handoff notes. Do not put methodology, findings, or progress counts in Objective constraints. Use `rationale` for measured findings and limits. Use `next_steps` for future actions. Omit `constraints` to retain the saved list on update. Send `[]` to clear it. Each item must have 1 to 500 characters. Send no more than 50 items.

`kind` is immutable. A baseline uses `workflow` and has no hypothesis. A comparison requires `hypothesis` and `baseline_workflow`. `changes` records performed work with `data`, `training`, and/or `workflow`. Include `training` only when the experiment runs a training job; model ancestry alone does not count. The field is descriptive and cannot change at finalize.

Reuse the same `request_id` to finalize a record. Training references can stand alone to preserve reused-model lineage. If `training` is supplied, also supply `training_reference`. Put only values sent to `trainings_create` in `training`. Do not reconstruct defaults.

`experiment.begin` creates `planned`. This state adds no approval gate. Use it while waiting for prerequisites. Record the wait reason in `note`; the protocol has no dependency API. Change to `in_progress` when data editing, Workflow creation, training, or evaluation starts. Clear an obsolete wait note with `note=""`. `experiment.update` can keep the current state or move `planned` to `in_progress` or `stopped`, move `in_progress` to `stopped` or `failed`, or resume `stopped` and `failed` as `planned` or `in_progress`. Do not move `in_progress` back to `planned`. A completed record is immutable. Only `experiment.finalize` produces `completed`, and only from `in_progress`. `autoresearch_experiment_get` reads any state; `autoresearch_objective_get` lists recent records.

## Objective revisions

Create a suitable Project first if none exists. Use Project slugs or `workspace/project` references in `project_ids`; MCP resolves the workspace. Projects can be shared across Objectives. When supplied on update, `project_ids` replaces the complete list. Omitted Projects and constraints remain unchanged. The update requires `goal` even when its text stays the same.

Save the agreed Workflow requirements in `constraints` before the first experiment. Changing the research plan does not require an Objective update or clear its recommendation. A change to goal text, constraints, or Project associations advances the Objective revision and clears its recommendation. Unchanged updates preserve both. `autoresearch_objective_get` returns recent `objectiveChanges` with before/after values and any cleared recommendation. Earlier experiments retain their revision, evidence, and outcomes, but cannot become the new revision's recommendation. After an edit, begin a new comparison under the current revision. Associate a training Project before beginning its experiment.

`request_id` identifies a goal or experiment submission. It does not make training or Eval launches idempotent.

## Finalize evidence

Use the exact saved Workflow references from the Run subjects and its completed evidence. Keep snake_case tool arguments and camelCase keys inside dictionaries. A baseline records one execution and has no outcome:

```json
{
  "objective_id": "goal_123",
  "request_id": "zero-shot-baseline",
  "kind": "baseline",
  "workflow": {"workflowId": "wf_base", "versionId": "ver_base"},
  "evidence": {"evalId": "eval_123", "runId": "run_456", "executionId": "exec_base"},
  "rationale": "The zero-shot Workflow found 18 of 20 damaged boxes."
}
```

A comparison records the baseline and candidate executions from the same Run:

```json
{
  "objective_id": "goal_123",
  "request_id": "stage-rule-v1",
  "kind": "comparison",
  "hypothesis": "A stricter completion rule prevents early completion.",
  "baseline_workflow": {"workflowId": "wf_base", "versionId": "ver_base"},
  "candidate_workflow": {"workflowId": "wf_candidate", "versionId": "ver_candidate"},
  "evidence": {
    "evalId": "eval_123",
    "runId": "run_456",
    "baselineExecutionId": "exec_base",
    "candidateExecutionId": "exec_candidate"
  },
  "outcome": "recommended",
  "rationale": "The candidate passed each required rule and improved the primary score. Fresh baseline repeats showed less variation than the gain.",
  "next_steps": ["Review latency before deployment."]
}
```

For a new training job, include `training` with only values submitted to `trainings_create` and `training_reference` with `projectId`, `versionId`, `trainingId`, and selected `modelId`. A reused model needs only its `training_reference`. Use the exact `trainings_get.versionId` value as a string. Read the selected model ID from `trainings_get.models[].modelId`; use the `workspace/model-id` form. Do not add `estimate` to any autoresearch record; share `trainings_estimate` only as advisory conversation.

Finalize the zero-shot baseline after its measured Run completes. Do not compare it with itself. Only finalize a comparison when its Run is terminal with state `completed` or `partially_completed`, both selected executions are complete, and all selected Case checks are complete. A failed unrelated challenger can make the Run `partially_completed`; it does not block a complete baseline-candidate comparison. Do not finalize missing or incomplete evidence.

Use `recommended` only when complete evidence supports improvement on the agreed scorecard and every hard constraint passes. Account for measured variation; do not assume an unmeasured noise band is zero. If latency is a hard constraint, a latency miss cannot receive `recommended`. Use `rejected` when complete evidence shows that the candidate does not improve the scorecard or fails a required constraint. Use `inconclusive` only when complete, comparable evidence cannot support either conclusion.

Use the selected baseline and candidate executions from one Run, with different saved Workflow versions. Each challenger in a grouped Run gets its own comparison record. Never combine separate Runs into one finalized comparison.

## Recovery and recommendation

On resume, list goals, read the goal and its constraints, inspect experiments, then read each referenced training or Eval job. Recover the agreed research limits from the working plan or handoff notes, not Objective constraints. Account for completed and active work against those limits, including the reserved final comparison. Reconcile active and completed jobs before creating new ones. If a training or Eval launch response was lost, search native jobs for a matching submission. Do not repeat an ambiguous launch until its state is clear.

After launch, save known `native_references` with `autoresearch_experiment_update` and the latest `expected_revision`. Keep `in_progress` while work continues. Before reporting a stop, read the authoritative job status. When cancellation is requested, use `trainings_cancel` or `workflow_evals_runs_cancel`, then record `stopped` or `failed` as appropriate.

If a stopped or failed experiment has complete native results, first update its record to `in_progress` with the latest revision and native references. Then finalize those results. This record update does not start or resume native jobs. Do not restart completed work to finalize it.

An experiment-level `recommended` outcome does not change the goal's current recommendation. Call `autoresearch_objective_recommend` only when completed evidence supports a new overall pick. If no new candidate qualifies, keep the current valid recommendation. If none exists, leave it unset and explain the evidence gap. The recommendation call needs the current goal revision.
