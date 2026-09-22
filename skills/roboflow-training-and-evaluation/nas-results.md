# Reading NAS Results

Read this when inspecting a NAS run or selecting a model for a hardware target.

- **Reading a run:** a run returns a frontier of models, not one, a 289-image dataset produced **76**. Get `modelGroup` from `trainings_list`, which returns it without child metrics, then page the children with `models_list(group=<modelGroup>, version_number=…, limit=…, offset=…)`. Don't use `trainings_get` for this: it inlines every child, which is the payload the paging exists to avoid. Each child carries a sparse `metrics` object. `latency` and `paretoOptimalFor` come from NAS mining, so they are on NAS children only - an ordinary training carries accuracy alone (e.g. `map50`, `precision`, `recall`, `f1`), and `metrics` can be null. Two shapes are in the data: newer runs report `latency` as a map keyed by hardware (e.g. `{"AI1": 6.69, "T4": 1.98}`) with `paretoOptimalFor` entries like `"T4:map_50_95"`, older ones a scalar `latency` with a sibling `metrics.hardware` (e.g. `"gpu"`) and bare entries like `"map_50"`. Branch on the type rather than indexing. Children with `nasFamily: "baseline"` are stock RF-DETR models trained on the same data; they are never `recommended` and are a free within-run reference.
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

