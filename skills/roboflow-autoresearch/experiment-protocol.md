# Autoresearch Experiment Protocol

Read this page before the first experiment record and when resuming research.

## Lifecycle

| When | Call | Required fields |
|---|---|---|
| Find saved work | `autoresearch_objectives_list` → `autoresearch_objective_get` | — |
| Save a goal | `autoresearch_objective_create` | `request_id`, `goal`, `project_ids` |
| Revise a goal | `autoresearch_objective_update` | `objective_id`, `expected_revision`, `goal` |
| Begin before launching work | `autoresearch_experiment_begin` | `objective_id`, `request_id`, `name`, `hypothesis`, `experiment_type`, `baseline_workflow` |
| Record progress or resume | `autoresearch_experiment_update` | `objective_id`, `experiment_id`, `expected_revision`, `state`, optional `native_references` |
| Record completed evidence | `autoresearch_experiment_finalize` | `objective_id`, same `request_id`, `hypothesis`, `baseline_workflow`, `candidate_workflow`, `evidence`, `outcome`, `rationale` |
| Select an overall recommendation | `autoresearch_objective_recommend` | `objective_id`, completed `experiment_id`, goal `expected_revision` |

Use `experiment_type="workflow"`, `"training"`, or `"combined"`. Set it at begin. It is immutable for that record. Reuse the same `request_id` to finalize it. A workflow experiment omits both `training` and `training_reference`. A training or combined experiment must include both. Put only parameters submitted to `trainings_create` in `training`; if none were submitted, pass `{}`. Do not add native defaults.

`autoresearch_experiment_get` reads an experiment in any lifecycle state. Use `autoresearch_objective_get` to list recent experiments and find their IDs. On resume, read the experiment record and native status before taking action.

The goal's `project_ids` use Project slugs or `workspace/project` references. Create the goal with every Project needed for training; its Project associations cannot be extended later. `request_id` is a stable identity for saving that goal or experiment. It does not make native jobs idempotent.

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
  "rationale": "The candidate passed every required rule and improved the primary score beyond measured run noise. Latency missed the advisory target, which was not a required gate."
}
```

For training and combined records, include `training` with only values submitted to `trainings_create` and `training_reference` with `projectId`, `versionId`, `trainingId`, and the selected `modelId`. Use the exact `trainings_get.versionId` value as a string. Read the selected model ID from `trainings_get.models[].modelId`; use the `workspace/model-id` form. Do not add `estimate` to any autoresearch record; share `trainings_estimate` only as advisory conversation.

Only finalize a comparison when its Run is terminal with state `completed` or `partially_completed`, both selected executions are complete, and all selected Case checks are complete. A failed unrelated challenger can make the Run `partially_completed`; it does not block a complete baseline-candidate comparison. Do not finalize missing or incomplete evidence.

Use `recommended` only when the candidate improves the approved scorecard beyond measured Run noise and passes every required constraint. If latency is a hard constraint, a latency miss cannot receive `recommended`. Use `rejected` when complete evidence shows that the candidate does not improve the scorecard or fails a required constraint. Use `inconclusive` only when complete, comparable evidence cannot support either conclusion.

One Run can compare one baseline with up to two challengers. Finalize each complete baseline-candidate comparison with its own baseline and candidate executions. The original baseline and candidate must be different saved Workflow versions. Do not record a baseline against itself or combine evidence from separate Runs into one comparison. Count the final comparison within the user's authorized Run limit.

## Recovery and recommendation

On resume, list goals, read the goal, inspect experiment records, and then read each referenced native job. Reconcile active and completed jobs before creating new ones. If a training or Eval launch response was lost, search native jobs for a matching submission. Do not repeat an ambiguous launch until its state is clear.

Call `autoresearch_experiment_update` with `state="in_progress"` when work will continue. Use `stopped` or `failed` when it will not. Include the latest `expected_revision` and any known `native_references`.

If a stopped or failed experiment has complete native results, first update its record to `in_progress` with the latest revision and native references. Then finalize those results. This record update does not start or resume native jobs. Do not restart completed work to finalize it.

An experiment-level `recommended` outcome does not change the goal's current recommendation. Call `autoresearch_objective_recommend` only when completed evidence supports a new overall pick. If no new candidate qualifies, keep the current valid recommendation. The recommendation call needs the current goal revision.
