# Authoring a Workflow Eval

How to write the Spec, the Eval Dataset, its Cases, and the bindings. The generated
`reference/` folder holds the exact JSON Schemas (`reference/schemas/`), the evaluator catalog
(`reference/catalogs.json`), the engine's own authoring procedure
(`reference/procedures/create-eval.md`), and a worked example (`reference/examples/`).

## 1. The Spec

A Spec never names a Workflow or a Workflow result path. Several Workflows that produce the
same outcome share one Spec and differ only in their bindings.

```json
{
  "schemaVersion": "workflow-evals/spec/v1",
  "id": "candy-counts-v1",
  "specId": "candy-counts",
  "name": "Candy counts",
  "inputs": [{ "name": "image", "type": "InferenceImage" }],
  "outputs": [
    { "id": "pink-count", "name": "Pink candy count", "kind": "count" },
    { "id": "total-count", "name": "Total candy count", "kind": "count" }
  ],
  "checks": [
    {
      "id": "pink-count",
      "name": "Pink candy count",
      "output": "pink-count",
      "semanticType": "count",
      "checkKind": "outcome",
      "groundTruth": { "kind": "path", "path": "$.pink_count" },
      "evaluator": { "type": "count@1" },
      "passRule": { "measurement": "absoluteDelta", "operator": "<=", "value": 0 }
    },
    {
      "id": "total-count",
      "name": "Total candy count",
      "output": "total-count",
      "semanticType": "count",
      "checkKind": "outcome",
      "groundTruth": { "kind": "path", "path": "$.total_count" },
      "evaluator": { "type": "count@1" },
      "passRule": { "measurement": "absoluteDelta", "operator": "<=", "value": 2 }
    }
  ]
}
```

Here the user accepted a miss of up to two candies in the total, but no miss in the pink count.

- `inputs` use the Inference vocabulary (`name`, `type`, optional `default_value`). Declare
  the inputs the Workflow needs, with the same types.
- Each **output** has a stable `id`, a human `name`, and a value `kind`. Pick the kind from
  what the Workflow returns, then pick the evaluator.
- Each **Check** evaluates one output against one ground-truth field. Use one Check per
  definition of success.
- **Ground-truth paths** are relative to each Case's `groundTruth` object: `$.pink_count`. Use
  short `snake_case` names that describe the real world, never names derived from a Workflow,
  a step, or an array index.

### Choosing an evaluator

The catalog (`reference/catalogs.json`, or `workflow_evals_reference_get` with
`kind="evaluator"`) lists every evaluator, its accepted value kinds, its measurements, and a
`suggestedPassRule`. The common ones:

| Workflow returns | Output `kind` | Evaluator | Usual pass rule |
| --- | --- | --- | --- |
| A number of things | `count` | `count@1` | `absoluteDelta <= 0` |
| A measurement or score | `numeric` | `numeric@1` | `absoluteDelta <= <tolerance>` |
| Yes or no | `boolean` | `boolean@1` | `exactMatch == 1` |
| A class, route, or extracted name | `label` | `label@1` | `exactMatch == 1` |
| Boxes with classes | `positionedObjects` | `objectDetection@1` | `f1 >= <threshold>` |
| Coverage along one axis (cracks, seams) | `positionedIntervals` | `intervalCoverage@1` with `config.axis` | `coverageIou >= 0.8` |
| Masks by class | `segmentation` | `segmentation@1` with `config.classes` | `meanIou >= 0.8` |

Newer engines add more (for example classification label sets). Check the catalog instead of
assuming a type exists.

### Pass rules

- Start from the evaluator's `suggestedPassRule`: its measurement exists and its direction is
  right.
- Counts, booleans, and labels normally need an exact match. Allow a miss only when the user
  says so.
- Numeric tolerances must come from the user or the domain. Do not make one up.
- Detection and coverage thresholds come from the user's acceptance requirement. The
  suggested `f1 >= 1` is strict; ask before relaxing or keeping it.
- Leave `passRule` out only when no defensible rule exists. Without it the Check reports
  measurements and a performance score, but no pass or fail.

### Validate before saving

`workflow_evals_specs_validate` returns `valid`, engine diagnostics with JSON locations, the
normalized Spec, and `groundTruthRequirements`: the fields every Case must carry, with their
`valueKind`. Fix diagnostics, show the Spec to the user, then call
`workflow_evals_specs_create`. To change a saved Spec, `workflow_evals_specs_update` with its
`revision`.

## 2. The Eval Dataset

`workflow_evals_datasets_create` takes a name, `inputs`, and `ground_truth_contract`.

- `inputs`: the same input declarations as the Spec.
- `ground_truth_contract`: one entry per requirement from the Spec validation, copied as
  `{"path": "cases[].groundTruth.pink_count", "valueKind": "count"}`. Add `"optional": true`
  only for fields some Cases may lack on purpose.

`workflow_evals_specs_compatible_datasets` and `workflow_evals_datasets_compatible_specs`
show which Specs and Datasets fit together. A Dataset is reusable across Evals; adding Cases
never changes its contracts (`workflow_evals_datasets_update_contract` does, as a migration).

## 3. Cases

A Case is one Workflow invocation: `name`, `inputs` keyed by declared input name, and
`ground_truth` keyed by field name. Optional `slices` group results (camera, lighting,
"hard cases").

### Images

Image inputs must be `{"artifactId": "..."}`. URLs and base64 strings are rejected with
`inputs.image does not match the Dataset input type`. Two ways to get an artifact:

**Upload a local file**

1. `workflow_evals_case_assets_upload` with `asset_name`, `content_type` (`image/jpeg`,
   `image/png`, `image/webp`, `image/gif`), and the exact `expected_size` in bytes. Check the
   real type of the bytes: an image downloaded from a `.jpg` URL can be a PNG.
2. HTTP `PUT` the raw bytes to `uploadUrl` with exactly the `requiredHeaders`. The response's
   `instructions` show a `curl` command with the path quoted. Substitute the real path, keep the
   quoting, and never build the command by pasting a file name into a shell unquoted.
3. `workflow_evals_case_assets_upload_complete`. The server checks size, type, and that the
   bytes decode as an image, and returns the `artifactId`.

**Import from Roboflow**

`workflow_evals_cases_import` takes `input_field` (the image input) and `items`: images by id
(`{"kind": "source", "sourceId": ...}`, ids from `images_search` or
`images_workspace_search`), a project dataset split (`{"kind": "dataset", ...}`), or uploaded
artifacts. Poll `workflow_evals_case_imports_get`. Imported Cases have incomplete ground truth.

### Ground-truth state

Every Case is `complete` or `incomplete`.

- `complete` (the default) requires every non-optional contract field, with the right type.
- `incomplete` is a draft: present values are still type-checked, missing ones are allowed.
  Create one with `workflow_evals_cases_create(..., ground_truth_state="incomplete")`.
- Approve a draft with `workflow_evals_cases_replace` and `ground_truth_state="complete"`.
  Editing a draft keeps it a draft only if you send `"incomplete"` again.
- A Run that selects an incomplete Case fails with `EVAL_NOT_READY` and lists
  `incompleteCaseIds`. Filter with `workflow_evals_cases_list(ground_truth_completeness=...)`.

If a server rejects `ground_truth_state` on create (`Unknown WorkflowEvalCase field`), create
the Case complete when you can, or import it and fill it in with a replacement.

## 4. Bindings

A BindingSet maps Dataset Case inputs to Workflow inputs, and Spec output ids to paths in the
Workflow's result.

```json
{
  "schemaVersion": "workflow-evals/binding-set/v1",
  "id": "candy-counts-on-sam3",
  "inputs": { "image": { "kind": "path", "path": "$.image" } },
  "outputs": {
    "pink-count": { "value": { "kind": "path", "path": "$[0].pink_count" } },
    "total-count": { "value": { "kind": "path", "path": "$[0].total_count" } }
  }
}
```

- **Input keys** are Workflow input names. Paths read the Case's `inputs` (`$.image`).
- **Output keys** are Spec output ids. A Roboflow Workflow returns a list with one record per
  image, keyed by the Workflow's declared output names, so paths look like
  `$[0].<workflow output name>`.
- **Path syntax** is dot-separated, with `[n]` only for list indexes. Names with spaces or
  hyphens work as written (`$[0].pink count`). Quoted brackets such as `$[0]["pink count"]`
  do not resolve, and a name that contains a dot cannot be addressed.
- Other binding kinds derive values: `array_length` turns a list of detections into a count,
  `count_where` counts items with a matching field. Item-scoped Checks bind both `items` (the
  collection) and `value` (read inside each item).

`workflow_evals_bindings_suggest` proposes a BindingSet with `assumptions` and `diagnostics`.
Before you accept it, compare every output path with the outputs from `workflows_get`. Then
call `workflow_evals_bindings_validate`. It returns `valid`, diagnostics, and the capture
contract (the result fields a Run will keep). A valid BindingSet is what
`workflow_evals_runs_start` takes, one per Workflow.

## 5. The Eval

`workflow_evals_create` with `spec_id`, `eval_dataset_id`, a subject, and a runtime:

- Subject: `{"kind": "savedWorkflow", "workflowId": ..., "subjectKey": ...}` for the current
  saved Workflow, `savedWorkflowVersion` for a pinned version, or `inline` with a raw manifest.
- Runtime: `{"kind": "serverless"}`, or `{"kind": "dedicated", "url": "https://<name>.roboflow.cloud"}`.

The Eval is `ready` when the Spec and Dataset are compatible, otherwise `draft` with
`readinessDiagnostics`. `workflow_evals_update` needs the Eval's `revision`; existing Runs
never change.

## Synthetic ground truth

For smoke tests and demos you may write ground truth yourself, for example by copying
annotation counts from a labeled project. Put those Cases in a `synthetic-ground-truth` slice,
describe them that way in the Dataset description, and say in every summary that the results
test the setup, not the Workflow's quality.
