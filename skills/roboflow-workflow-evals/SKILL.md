---
name: roboflow-workflow-evals
description: Use when someone wants to know whether a Roboflow Workflow is good enough, whether a change to a Workflow improved or regressed it, or how two Workflows compare on the same images. Covers designing a Workflow Eval (Spec, Eval Dataset, Cases, ground truth, bindings), running it, reading per-Check results, comparing and exporting Runs, and cleaning up. Not for a trained model's mAP on its dataset version (use roboflow-training-and-evaluation) or one-off inference.
---

> **For agents — source-of-truth:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills) and shipped with the Roboflow plugin. If your client has loaded the plugin (you'll see `roboflow:<name>` skills in your available skills list), use those local skills — they're read fresh from disk every session. The same content served as MCP resources at `roboflow://skills/<name>/...` is a fallback for clients without the plugin and may lag this repo. **Don't call `ReadMcpResourceTool` for `roboflow://skills/...` URIs when a local `roboflow:<name>` skill is available.**

# Workflow Evals

A Workflow Eval measures a Roboflow Workflow against ground truth that someone trusts. It
answers three questions: is this Workflow good enough, did a change make it better or worse,
and what tradeoff changed. Every answer is per Check and per Case. There is no overall score
or ship decision, and you must not invent one.

## When to use it, and when not

Use Workflow Evals when the user:

- wants acceptance criteria for a Workflow's outputs ("the pink count must be exact", "the
  defect flag must be right", "boxes need F1 of at least 0.9");
- changed a Workflow (a model, a threshold, a block) and wants to know if it regressed;
- wants to compare two Workflows, or two versions of one, on the same images;
- needs repeatable results to show someone else (exports, per-Case evidence).

Use something else when:

| The user wants | Use instead |
| --- | --- |
| mAP, precision, or recall of a trained model on its dataset version | `roboflow-training-and-evaluation` (`model_evals_*` tools) |
| To see what a Workflow returns for one image | `workflow_specs_run` or `workflows_run` (`roboflow-inference`) |
| Predictions over thousands of images without ground truth | `roboflow-batch-processing` |
| To label data for training | `roboflow-data-management` |

A Workflow Eval needs ground truth. If the user has none, offer to create it with them
(Case preparation gives candidate outputs to correct, see `lifecycle.md`). Never present
results computed against made-up ground truth as a judgment of the Workflow. If you create
synthetic ground truth for a test, put the Cases in a `synthetic-ground-truth` slice and say
so in every summary.

## The model in one paragraph

A **Spec** says what success means without naming any Workflow: semantic **outputs** (for
example "pink candy count", kind `count`) and **Checks** that compare each output to a
ground-truth field with an evaluator and an optional pass rule. An **Eval Dataset** holds
**Cases**: concrete inputs (images) plus ground truth, under declared input and ground-truth
contracts. A **BindingSet** connects one Spec and one Dataset to one concrete Workflow: Case
inputs to Workflow inputs, and Spec outputs to paths in the Workflow's result. An **Eval** ties
a Spec, a Dataset, and a default Workflow and runtime together. A **Run** freezes all of that
and executes it; it holds one **Execution** per Workflow evaluated. Results are per Case and
per Check, plus aggregates per Check.

## Check the engine version first

Call `workflow_evals_capabilities` before authoring. It returns `engine.version` and which
actions the credential allows (`workflow-evals:read`, `write`, `run`, `export`).

This skill ships a generated snapshot of the engine's schemas, evaluator catalog, procedure,
and examples in `reference/`, for the version in `reference/manifest.json` (`engineVersion`).

- Same version: read `reference/` directly.
- Different version: the guides below still apply, but take schemas, evaluator types,
  measurements, and examples from `workflow_evals_reference_get` instead of `reference/`
  (`kind` = `evaluator`, `schema`, `skill`, `asset`, or `agent_manifest`). Older MCP servers
  expose the same reads as `workflow_evals_evaluators_list`, `workflow_evals_schema_get`, and
  `workflow_evals_agent_resource_get`.

## The loop

1. **Understand the Workflow.** `workflows_get` gives its declared inputs and outputs. Output
   names matter: bindings point at them.
2. **Agree on success with the user.** Which outputs matter, what the ground truth is per
   image, and what counts as a pass. Counts and labels usually need an exact match; numeric
   values need a tolerance the user can defend; detections need an F1 or coverage threshold.
3. **Write the Spec yourself** following `authoring.md` (or `reference/procedures/create-eval.md`).
   Iterate with `workflow_evals_specs_validate` until it is valid, show it to the user, then
   save it with `workflow_evals_specs_create`.
4. **Create the Eval Dataset** with `workflow_evals_datasets_create`. Copy the
   `groundTruthRequirements` from the Spec validation into its `ground_truth_contract`, and
   declare the Workflow's inputs.
5. **Add Cases.** Upload images and create Cases, or bulk import from a Roboflow project
   (`authoring.md`). Image inputs are always `{"artifactId": ...}`.
6. **Create the Eval** with `workflow_evals_create` (Spec, Dataset, a `savedWorkflow` subject,
   `{"kind": "serverless"}` runtime). It turns `ready` when the Spec and Dataset are compatible.
7. **Bind the Workflow.** `workflow_evals_bindings_suggest`, check every output path against
   the Workflow's declared outputs, then `workflow_evals_bindings_validate`.
8. **Dry run, then run.** Start a Run on one Case (`case_selection` explicit), check its
   result, then run all Cases. Poll `workflow_evals_runs_get` (`lifecycle.md`).
9. **Read results.** `workflow_evals_results_overview`, then
   `workflow_evals_results_cases_list` with `failed_check=true`, then
   `workflow_evals_results_case_get` for the failures.
10. **Compare or export** when the user needs it, and **clean up** what you created for tests.

## Rules that save Runs

- **Confirm before spending.** Case preparation and Runs on server runtimes cost inference.
  Say how many Cases and which Workflow before you start one.
- **Idempotency keys.** Create and start commands take `idempotency_key` (UUID v4). Generate
  one per intended action and reuse it only to retry that exact request. Reusing it with a
  different payload returns `409 CONFLICT`.
- **Revisions.** Updates and replacements need the resource's current `revision`. A `412`
  means someone else changed it: read it again, reapply your change, retry.
- **Replacements are complete.** `workflow_evals_cases_replace` replaces the whole Case.
  Send the current name, inputs, ground truth, `ground_truth_state`, and slices.
- **Deletion is two steps.** Evals and Runs return an impact summary and a `deletion_key`
  first. Show the impact to the user, get a clear yes, then call again with the key.
- **Signed URLs are secrets.** Upload URLs, read URLs, and export URLs are short-lived and
  grant access. Use them, never paste them into chat, logs, or reports.
- **Judgment is per Check.** Report pass rates and failing Cases per Check. Do not average
  Checks into one number or declare a winner unless the user defined that rule.

## Guides in this skill

- `authoring.md`: Specs, evaluators and pass rules, Eval Datasets, Cases and uploads,
  ground-truth state, and bindings.
- `lifecycle.md`: Case preparation, Runs and polling, retries, replay and rescore, results,
  comparison, exports, embeddings, and cleanup.
- `troubleshooting.md`: error codes, common failures, and known issues.
- `reference/`: generated engine snapshot (schemas, catalogs, conceptual model, procedure,
  examples). Do not edit it by hand.
