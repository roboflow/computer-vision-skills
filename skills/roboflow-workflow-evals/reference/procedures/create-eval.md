---
name: create-eval
description:
    Draft and validate Workflow Evals Spec, Dataset, and BindingSet JSON from desired quality
    outcomes, workflow results, and ground truth. Use when creating evaluation logic, choosing
    supported bindings or evaluators, defining acceptance rules, or repairing an invalid Workflow
    Evals authoring artifact.
---

# Create a Workflow Eval

Load every asset in `bundle:create-eval` before authoring. Use `resource:engine-catalogs` as the
supported vocabulary and the schemas as the output contract.

A Spec defines success and never names a Workflow. A BindingSet wires one Spec and one Dataset to
exactly one concrete Workflow subject.

## Author the Spec

1. State the business question and the semantic outcome each check measures.
2. Declare the subject-independent `inputs` contract with Inference's `name`, `type`, and optional
   `default_value` fields. Do not replace that vocabulary with a separate required flag.
3. Declare one semantic output per measurable Workflow result. Give it a stable id, a human name,
   and the canonical value kind. Identify that value kind before choosing an evaluator; prefer a
   catalog preset only when it matches.
4. Write one check per definition of success. Outcome checks name a semantic output, bind ground
   truth, and select an evaluator. Runtime latency checks use `checkKind: "runtime"`,
   `semanticType: "latency"`, and `latency@1` with a required positive `maxLatencyMs` in
   milliseconds; they have no output, groundTruth, items, or applicability.
5. Keep ground-truth paths relative to each case's `groundTruth` object. Use a short semantic
   `snake_case` field name, such as `$.led_strip_count` or `$.package_count`.
    - When the confirmed representative example provides a signal ground-truth path, preserve that
      path exactly: it is the human-confirmed data contract.
    - Never derive a ground-truth field name from a workflow id or name, output array index, source
      path index, timestamp, or generated ordinal. Do not produce names such as
      `panel_assembly_0_led_strip_count_1`.
    - Ground truth describes the real-world case, not a workflow. Several Workflow subjects
      measuring the same outcome share one Spec and one ground-truth field; they differ only in
      their BindingSets.
6. Use explicit numeric ground-truth fields for explicit scalar outputs. Use `array_length` only
   when both sides derive a count from arrays.
7. Turn every selected success outcome into a clear pass/fail judgment whenever the policy is
   defensible. A generated evaluation should normally be decision-ready, not only report a score.
    - Start from the evaluator catalog's `suggestedPassRule`; its measurement is supported and its
      direction is correct.
    - Counts, booleans, labels, and presence checks normally require exact acceptance. Use the
      suggested exact rule unless the confirmed success description explicitly allows a miss.
    - For continuous numeric measurements, use `absoluteDelta` with a static tolerance when the
      user's success description, domain wording, or representative example establishes a reasonable
      allowable deviation. Keep the tolerance understandable and conservative; do not fabricate an
      arbitrary percentage or unsupported measurement.
    - For detection and interval metrics, use the catalog's suggested F1 or coverage threshold
      unless the user gives a stricter or looser acceptance requirement.
    - Omit `passRule` when no defensible pass/fail policy can be inferred. Never insert a rule
      implicitly.
    - Judgment is per check. Never invent an overall verdict, ship/no-ship decision, or
      baseline-versus-candidate winner inside a Spec.
8. Prefer `objectDetection@1` for class-aware positioned objects. Prefer `intervalCoverage@1` for
   coverage along one axis. Use `segmentation@1` to compare masks by class from either semantic or
   instance models. Bind the full Inference envelope when possible; select exact class names with
   `evaluator.config.classes` (for example `["corrosion"]`). Prefer COCO RLE ground truth and output
   for pixel-exact comparisons. The default background name is `background`; configure
   `backgroundClass` for a different label. `meanIou` is a per-case macro class mean; pooled dataset
   mIoU lives separately at `CheckAggregate.segmentation.meanIou`. Do not substitute box mAP or
   interval IoU for mask coverage.
9. Use `keypoints@1` for pose instances. Supply the complete per-class skeleton IDs/names in config;
   never infer K from a sparse prediction array. Bind the full image/predictions envelope. Ground
   truth uses image dimensions plus objects with center boxes and point visibility 0/1/2. Default
   sigmas are uniform 1/K; COCO-human is explicit. Case AP is diagnostic; pooled AP/AR and F1@mOKS
   live in `CheckAggregate.keypoints`, with confidence optimized on the evaluation Dataset itself.
   Do not substitute case averages for these metrics, pair instances by detection ID, or add item
   scope. Upstream confidence/NMS filtering cannot be undone by rescoring. Missing predicted points
   contribute zero in default mode; strict mode requires complete vectors. No graphical skeleton
   editor or temporal support is implied.
10. Use `classification@1` for single-label and multi-label classifiers (a preset over
    `labelSet@1`). Ground truth is one class name or an array of class names; `[]` means no class.
    Bind the classifier's full response: the preset reads `top` for single-label and
    `predicted_classes` for multi-label, never the confidence map, so the Workflow's threshold stays
    the decision being evaluated. Do not use `label@1` for multi-label. Class names are exact after
    trimming. Primary performance is per-case F1 (partial credit); suggest `exactMatch == 1` or an
    `f1` threshold only when the user wants judgment. Add `evaluator.config.classes` only for a
    fixed, exhaustively annotated vocabulary; it enables true negatives, `labelAccuracy`, and
    `hammingLoss`, which must not be the headline. Subset accuracy, mean case F1, and micro/macro
    precision/recall/F1 live in `CheckAggregate.labelSet`; they are not interchangeable.
11. Emit `workflow-evals/spec/v1` Specs, `workflow-evals/dataset/v1` Datasets, and
    `workflow-evals/binding-set/v1` BindingSets.

## Author the BindingSet

1. Map every Dataset case input the Workflow needs to a Workflow input name. The two mappings —
   inputs and outputs — are independent.
2. Map every outcome semantic Spec output id to the concrete Workflow result path that produces it.
   A Spec output with no binding, or a binding for an output the Spec never declared, fails linking.
3. For a check with an `items` scope, give its output binding both an `items` collection binding
   over the Workflow result and a `value` binding resolved inside each matched item.
4. For a latency-only Spec use `outputs: []` and BindingSet `outputs: {}`. Its Dataset cases can use
   `groundTruth: {}` and an empty ground-truth contract; normal Workflow input bindings remain
   required. The budget belongs only in the Spec, never per case.
5. Author one BindingSet per Workflow subject. Comparing versions means running each one and reading
   the comparison afterwards.

## Validate

Parse and compile the Spec, then compare its input and ground-truth requirements against the
Dataset's declared `inputs` and `groundTruthContract` with `compareWorkflowEvalContracts`. Validate
Case values separately before running any Workflow. Link the BindingSet to confirm the wiring is
complete. When live tools are unavailable, use the declared `tool:describe-ground-truth` and
`tool:validate-spec` contracts to shape the equivalent local engine calls. Return validation issues
with their check and ground-truth paths; do not paper over missing data.

## Deliver

Return the Spec, the Dataset or required ground-truth shape, the BindingSet, and a short rationale
mapping each check to its semantic output, evaluator, performance measurement, and optional pass
rule. Do not include provider-specific prompts or unsupported evaluator names.
