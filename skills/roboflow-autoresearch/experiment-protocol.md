# Autoresearch Experiment Protocol

Read this page before saving a goal, changing an experiment state, or resuming research.

## Lifecycle

| When | Call | Fields |
|---|---|---|
| Find saved work | `autoresearch_objectives_list` → `autoresearch_objective_get` | — |
| Save a goal | `autoresearch_objective_create` | `request_id`, `goal`, `project_ids`; optional `constraints` |
| Revise a goal | `autoresearch_objective_update` | `objective_id`, `expected_revision`, `goal`; optional `constraints`, replacement `project_ids` |
| Begin before launching work | `autoresearch_experiment_begin` | `objective_id`, `request_id`, `name`, `hypothesis`, `experiment_type`, `baseline_workflow` |
| Record progress or resume | `autoresearch_experiment_update` | `objective_id`, `experiment_id`, `expected_revision`, `state`, optional `native_references` |
| Record completed evidence | `autoresearch_experiment_finalize` | `objective_id`, same `request_id`, `hypothesis`, `baseline_workflow`, `candidate_workflow`, `evidence`, `outcome`, `rationale` |
| Select an overall recommendation | `autoresearch_objective_recommend` | `objective_id`, completed `experiment_id`, goal `expected_revision` |

Use `experiment_type="workflow"`, `"training"`, or `"combined"`. Set it at begin. It is immutable for that record. Reuse the same `request_id` to finalize it. A workflow experiment omits both `training` and `training_reference`. A training or combined experiment must include both. Put only parameters submitted to `trainings_create` in `training`; if none were submitted, pass `{}`. Do not add native defaults.

`experiment.begin` creates `in_progress`. `experiment.update` keeps that state or changes it to `stopped` or `failed`. Only `experiment.finalize` produces `completed`, and only from `in_progress`. A completed record cannot resume. `autoresearch_experiment_get` reads any state; `autoresearch_objective_get` lists recent records.

## Objective revisions

Create a suitable Project first if none exists. Use Project slugs or `workspace/project` references in `project_ids`; MCP resolves the workspace. Projects can be shared across Objectives. When supplied on update, `project_ids` replaces the complete list. Omitted Projects and constraints remain unchanged. The update requires `goal` even when its text stays the same.

Save the agreed success criteria and work limits in `constraints` before the first experiment. **Every Objective edit** advances its revision and clears the recommendation, including goal text, constraints, or Projects. Earlier experiments retain their revision and history, but cannot become the new revision's recommendation. After an edit, begin a new comparison under the current revision. Associate a training Project before beginning its experiment.

`request_id` identifies a goal or experiment submission. It does not make training or Eval launches idempotent.

## Finalize evidence

Use the exact saved Workflow references from the Run subjects and its completed evidence. Keep snake_case tool arguments and camelCase keys inside dictionaries:

```json
{
  "objective_id": "goal_123",
  "request_id": "stage-rule-v1",
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
  "rationale": "The candidate passed every required rule and improved the primary score. Fresh baseline repeats showed less variation than the gain. Latency missed the advisory target, which was not a required gate."
}
```

For training and combined records, include `training` with only values submitted to `trainings_create` and `training_reference` with `projectId`, `versionId`, `trainingId`, and the selected `modelId`. Use the exact `trainings_get.versionId` value as a string. Read the selected model ID from `trainings_get.models[].modelId`; use the `workspace/model-id` form. Do not add `estimate` to any autoresearch record; share `trainings_estimate` only as advisory conversation.

Only finalize a comparison when its Run is terminal with state `completed` or `partially_completed`, both selected executions are complete, and all selected Case checks are complete. A failed unrelated challenger can make the Run `partially_completed`; it does not block a complete baseline-candidate comparison. Do not finalize missing or incomplete evidence.

Use `recommended` only when complete evidence supports improvement on the agreed scorecard and every hard constraint passes. Account for measured variation; do not assume an unmeasured noise band is zero. If latency is a hard constraint, a latency miss cannot receive `recommended`. Use `rejected` when complete evidence shows that the candidate does not improve the scorecard or fails a required constraint. Use `inconclusive` only when complete, comparable evidence cannot support either conclusion.

Use the selected baseline and candidate executions from one Run, with different saved Workflow versions. Never combine separate Runs into one finalized comparison.

## Recovery and recommendation

On resume, list goals, read the goal and its constraints, inspect experiments, then read each referenced training or Eval job. Account for completed and active work against the saved limits, including the reserved final comparison. Reconcile active and completed jobs before creating new ones. If a training or Eval launch response was lost, search native jobs for a matching submission. Do not repeat an ambiguous launch until its state is clear.

After launch, save known `native_references` with `autoresearch_experiment_update` and the latest `expected_revision`. Keep `in_progress` while work continues. Before reporting a stop, read the authoritative job status. When cancellation is requested, use `trainings_cancel` or `workflow_evals_runs_cancel`, then record `stopped` or `failed` as appropriate.

If a stopped or failed experiment has complete native results, first update its record to `in_progress` with the latest revision and native references. Then finalize those results. This record update does not start or resume native jobs. Do not restart completed work to finalize it.

An experiment-level `recommended` outcome does not change the goal's current recommendation. Call `autoresearch_objective_recommend` only when completed evidence supports a new overall pick. If no new candidate qualifies, keep the current valid recommendation. If none exists, leave it unset and explain the evidence gap. The recommendation call needs the current goal revision.
