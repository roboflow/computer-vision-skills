# Reading NAS Results

Read this when you start a NAS run, inspect its results, compare it with named architectures, or select a model for deployment.

## Run and deploy

1. Read `versions_get.splits.valid`. NAS needs at least 15 validation images. A smaller split fails with `insufficient_validation_images_for_nas`; generate a version with more validation images.
2. Use the task-supported parent selected in the Model Selection Quick Guide.
3. Call `trainings_create` with the supported `model_type`. NAS uses the normal training tool. Save the returned `trainingId` and monitor it with `trainings_get`.
4. After training, read the `modelGroup` from `trainings_list`. Page child models with `models_list(group=<modelGroup>, version_number=…, limit=…, offset=…)`.
5. Deploy a selected child through the standard inference paths. NAS inference types include `rfdetr-nas`, `rfdetr-nas-seg`, and `rfdetr-nas-sem`.

If `trainings_create` returns `nas_not_available_for_plan`, treat it as a plan limit and do not retry. Choose a supported named model. Tell the user that the workspace plan needs NAS access.

- **Reading child metrics:** a 289-image dataset produced 76 candidates in one run. Do not use `trainings_get` to list them; it inlines every child. Each child has sparse `metrics`. NAS children can include `latency` and `paretoOptimalFor`; ordinary training metrics hold accuracy only, such as `map50`, `precision`, `recall`, and `f1`. The `metrics` field can be null. Newer runs report `latency` as a map keyed by hardware (for example, `{"AI1": 6.69, "T4": 1.98}`) with `paretoOptimalFor` entries such as `"T4:map_50_95"`. Older runs report a scalar `latency`, sibling `metrics.hardware` (for example, `"gpu"`), and bare entries such as `"map_50"`. Branch on the type of `latency`. Children with `nasFamily: "baseline"` are stock RF-DETR models trained on the same data. They are never `recommended` and provide a within-run reference.
- **Picking for a specific hardware target needs the authoritative map.** The platform scores a separate winner per hardware, but `models_list` flattens that into one `recommended` boolean, true if the child won *any* bucket, so it cannot tell you which hardware, and `paretoOptimalFor` is unrelated frontier metadata, not the recommendation. The exact mapping is `recommendedByHardware` from `trainings_get`, but it is only built on the legacy version-based summary, a modern MMPV training returns no such field, which is the common case. So for most runs there is no exact per-hardware lookup at all. Do not infer one: report the candidates and ask which accuracy/latency tradeoff, or which latency budget, matters.

## Comparing against named architectures

One trap is specific
to comparison: **pick the representative to match the question, or you will understate NAS.** The platform picks a
winner per (metric, hardware) bucket by balancing accuracy against measured latency, and
`models_list` exposes only the flattened union of those winners as a `recommended` boolean. So a
flagged child won *some* bucket, which is not the same as being the most accurate: in one
76-model run the two flagged children scored **72.86** and **71.91** mAP50-95 while the best child
scored **78.00**, a 5–6 point gap.
For a pure-accuracy comparison take the highest `metrics.map5095` child. For a deployment
decision, use the authoritative `recommendedByHardware` entry if the run exposes one; otherwise
report the candidates' accuracy and latency for the target (reading latency per the shapes above),
say that no per-hardware recommendation is exposed, and let the user pick the tradeoff. The run's own `nasFamily: "baseline"` children are a useful
check on whether the search actually beat stock RF-DETR.

