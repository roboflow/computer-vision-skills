---
name: roboflow-model-diagnosis
description: Diagnose why a model underperforms before changing anything — run Model Evaluation, read the confusion matrix, per-class metrics, object-size mAP, confidence sweep and vector explorer, map each symptom to a root cause (taxonomy, mislabeled data, inconsistent label standards, coverage gaps, too little data, bad data), and decide exactly which data to add next.
---

# Diagnosing an Underperforming Model

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:roboflow-training-and-evaluation`) over fetching `roboflow://skills/roboflow-training-and-evaluation/model-diagnosis` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

"Improve my model" has no default fix. The same low mAP can come from a taxonomy that no model can learn, from mislabeled images, from labelers applying different standards, from conditions the dataset never shows, from too few examples, from leaked or duplicated data, or simply from the wrong confidence threshold. Each has a different cure, and several cures are cheaper than training again.

Two rules:

1. **Diagnose before you change anything.** Run Model Evaluation, find the single biggest failure, and confirm its cause by looking at the images behind it.
2. **More data is usually the right answer, but the diagnosis decides *which* data.** Adding images labeled to a bad standard, or to a taxonomy that overlaps, makes the model worse and the problem harder to see.

This page is the entry point when a user asks "why is my model bad" or "how do I improve it". Once the cause is model-side (architecture, size, resolution, augmentation, overfitting), continue in `roboflow://skills/roboflow-training-and-evaluation/improvement-playbook`.

## Quick Reference: Symptom → Cause → First Action

| Symptom | Check first | Most likely cause | First action |
|---|---|---|---|
| Overall mAP very low (< 30%) | Dataset Health: image + annotation counts, missing annotations; project type | Too little data, broken/missing labels, wrong project type, resize destroying small objects | Fix labels and counts before any training change (see **Not enough data**, **Mislabeled data**) |
| Train split metrics high, test low | `map-results` per split; how splits were made | Overfitting, or test set from a different distribution, or the reverse: train leaked into test | Check for duplicate/near-duplicate frames across splits; if clean, see **Overfitting** in the playbook |
| mAP@50 fine, mAP@50-95 / mAP@75 poor | `map-results` `map50` vs `map50_95`; box tightness on clicked cells | Inconsistent box extents between labelers, low training resolution, crop augmentation | Write a box-extent rule, relabel the weakest class, raise resolution (see **Improve localization / IoU**) |
| One class has low recall | Performance by Class; `missed_detection` recommendation | Too few examples, small objects, high visual variety, occlusion | Add that class specifically under the conditions where it is missed |
| Two classes confused both ways | Confusion matrix off-diagonal pair; `wrong_class` | Taxonomy overlap or labeler disagreement | Test a merge with version-level Modify Classes; or write a boundary rule and relabel |
| Background false-positive column full | Click the cell, toggle Ground Truth vs Predictions; `overconfident_fp` | **Unlabeled real objects in ground truth** (most common), no negative images, threshold too low | If the "false positives" are real objects: label them. Otherwise add null and hard-negative images |
| Small-object bucket low | `map-results` `byObjectSize.small` | Objects too small at training resolution, resize mode, crop | Tile preprocessing, higher resolution, dynamic crop, capture closer |
| One vector cluster has low F1 | Vector Explorer; sample the cluster | A condition (lighting, camera, angle, background) the dataset under-covers | Name the condition, tag those images, collect more of exactly that |
| Precision/recall swing hard with threshold | Confidence sweep | Threshold left at a default rather than the F1-optimal value | Deploy at the optimal threshold (global or per class); this is a deployment fix, not a data fix |
| `dataset_health` recommendation | Split sizes on the version | Test or valid split too small to trust any metric | Regenerate the version with a bigger held-out split before iterating |
| Great in evaluation, bad in production | Compare production images to the test set | Test set does not represent deployment (camera, lighting, distance, resolution) | Turn on Active Learning, review a random production sample, add it to all splits |
| Metrics barely move version to version | What changed between versions | Several variables changed at once, or the bottleneck is labels not data | Change one thing per version; audit labels of the weakest class |

## Step 0 — Decide What "Better" Means and Trust the Test Set

**Pick the metric that matches the job.** A single mAP number hides what the user cares about.

| Use case | Metric to track | Why |
|---|---|---|
| "Does it find the objects?" (counting, presence, alerts) | mAP@50, per-class recall | Loose overlap is fine; a box that touches the object counts |
| Box tightness matters (measurement, cropping, downstream OCR, tracking) | mAP@50-95, mAP@75 | These reward precise localization; mAP@50 does not |
| Missing an object is expensive (safety, defects) | Recall at a fixed acceptable precision, read off the confidence sweep | Optimize the threshold for recall, then work on precision |
| False alarms are expensive (automated actions, alerts to humans) | Precision at a fixed acceptable recall | The reverse trade |
| Semantic segmentation | mIoU, per-class IoU | Pixel-level; confusion-matrix counts are pixels, not objects |
| Classification | Accuracy plus the confusion matrix | Accuracy alone hides class imbalance |

**Make sure the test set can be trusted.** Every metric below is only as good as the held-out data.

- **Held out and representative.** The test split should look like deployment: same cameras, distances, lighting, and object mix. If deployment conditions are missing from the test set, a high score means nothing.
- **No leakage.** Near-duplicate images across train and test inflate every metric. Video is the usual culprit: consecutive frames from one clip end up in both splits. Keep all frames from one video, session, or scene in the same split, and lower the frame sampling rate on upload. Roboflow drops exact duplicates on upload, not near-duplicates.
- **Big enough.** The evaluation engine currently flags a `dataset_health` recommendation when the test split has fewer than 50 images, or, on versions without augmentation, when test is under 5% or valid under 10% of the dataset. Below those sizes a single image moves the number.
- **Stable across versions.** Keep the same images in the test split from one version to the next so a metric change means the model changed, not the exam. Add new images to all splits; do not rebalance the test split when regenerating.

## Step 1 — Run the Evaluation

Model Evaluation runs automatically for paid workspaces after every training (and for uploaded weights). It scores the model on the **test and valid** splits. It can take minutes for hundreds of images and hours for thousands.

**Web UI:** Project > Models > click the model version > **View Evaluation**. Deep link: `https://app.roboflow.com/{workspace}/{project}/evaluation/{versionId}`.

**MCP recipe.** Run these in order; each reads one panel of the evaluation page.

| Order | Tool | What to read |
|---|---|---|
| 1 | `models_list` / `models_get` | Which model and version the user means; note `map50` for context |
| 2 | `model_evals_list(project_id=…, version_number=…, status="done")` | Find the `evalId`. Filters are mutually exclusive: pass one of `project_id`, `version_number`, or `model_id` |
| 3 | `model_evals_get(eval_id)` | Headline mAP@50, precision, recall at the F1-optimal threshold; `app_url` deep link to hand back to the user |
| 4 | `model_evals_get_recommendations(eval_id)` | The engine's own findings (see the five types below). `{"generated": false}` means the eval is done but recommendations were never produced; move on |
| 5 | `model_evals_get_performance_by_class(eval_id, split="test")` | Per-class `map50`, `map50_95`, precision, recall, F1, `optimalThreshold`. Sort by recall then precision to find the weakest class |
| 6 | `model_evals_get_map_results(eval_id)` | `map50` vs `map50_95` vs `map75` per split, and `byObjectSize` small/medium/large. Compare train vs test for overfitting or leakage |
| 7 | `model_evals_get_confusion_matrix(eval_id, split="test")` | Off-diagonal pairs and the background row/column. Defaults to the optimal threshold; pass `confidence` (0-100) to see how it moves |
| 8 | `model_evals_get_confidence_sweep(eval_id)` | Precision/recall/F1 per threshold, global and per class; the F1-optimal threshold |
| 9 | `model_evals_get_vector_analysis(eval_id)` then `model_evals_get_image_predictions(eval_id, split="test", limit=…)` | Clusters with low `f1Mean`; per-image TP/FP/FN and `cluster.id` to find the images in a weak cluster |
| 10 | `projects_health(project_id)` | Class distribution per split, missing vs null annotations, image dimensions. First call or `regenerate=True` can take a couple of minutes |

Panel tools return `409 model_eval_not_done` while the evaluation is still running; wait and retry rather than concluding the data is missing. Evaluation is a paid-plan feature: if `model_evals_list` returns nothing for a trained model on a free workspace, say so and fall back to the training-page metrics plus Dataset Health.

**How to report it.** Lead with the one biggest problem and the numbers behind it (for example: "`helmet` recall is 0.41; 63 of 107 test instances are missed, and 40 of those are in the low-light cluster"). Name the likely cause, say how you confirmed it (which cell you looked at), and propose one change for the next version. Do not list every panel.

## Step 2 — Read Each Panel

### Recommendations

The engine currently emits five recommendation types. The triggers are current platform behavior and may be tuned; the meaning underneath is the useful part.

| Type | Current trigger | What it usually means | Do this |
|---|---|---|---|
| `missed_detection` | The class with the most false negatives | Too few or too varied examples of that class; small or occluded instances; or labels that mark objects the model was never shown enough of | Click the false-negative cell for the class. If the misses share a condition, collect that condition. If they look like the training data, add more of the class |
| `wrong_class` | The most common off-diagonal pair (correct location, wrong class) | Taxonomy overlap or labeler disagreement between the two classes, far more often than model capacity | Check whether the confusion is symmetric. If both directions are populated, the classes are not separable as defined: merge, redefine, or write a boundary rule |
| `class_imbalance` | A class with fewer than `max(30, 0.05 × √total instances)` instances, or under 25% of the median class count | The model has not seen enough of the class to learn it | Add images of that class specifically; augmentation does not fix imbalance |
| `overconfident_fp` | A class with ≥ 30 predictions, ≥ 30 false positives, and precision under 65% | Very often **real objects that were never labeled** (the model is right, the ground truth is wrong); otherwise missing negative examples or a threshold that is too low | Open the background false-positive cell and toggle Ground Truth vs Predictions before doing anything else |
| `dataset_health` | Test < 50 images, or test < 5% / valid < 10% on unaugmented versions | The metrics are too noisy to act on | Regenerate with a larger held-out split, then re-evaluate |

### Performance by Class

| Pattern | Meaning | Next step |
|---|---|---|
| Precision low, recall fine | The model over-predicts this class | Background false positives (missing labels or missing negatives) or confusion with another class; check the confusion matrix row and column |
| Recall low, precision fine | The model is conservative or has not seen enough variety | More examples under the missed conditions; check object size; consider a lower per-class threshold |
| Both low | The class is hard as currently defined, or its labels are inconsistent | Audit labels for this class first; then consider the taxonomy; then data volume |
| mAP is `null` | No instances of the class in this split | The test split does not cover the class; fix the split before judging the class |
| Optimal threshold far from the global one | The class needs its own operating point | Deploy with per-class thresholds |

### Confusion Matrix

Rows are ground truth, columns are predictions, and `background` is the extra row and column.

| Cell | Meaning | Interpretation |
|---|---|---|
| Diagonal | Correct class at an overlapping location | The goal; low diagonal for one class with a high row total means it is being called something else |
| Off-diagonal, class A row → class B column | Model found the object but called it B | If A→B and B→A are both populated: taxonomy or label disagreement. If only one direction: A lacks examples that distinguish it, or A instances were labeled B in some batches |
| Background column (row = class A) | Ground truth has A, model predicted nothing | A false negative: missed object. Data volume, object size, occlusion, or condition gap |
| Background row (column = class A) | Model predicted A where ground truth has nothing | A false positive: check whether the object is really there. If yes, the label is missing. If no, add negatives or raise the threshold |

**Click-through checklist.** For every cell you act on, open it and inspect at least a handful of images with the Ground Truth / Model Predictions toggle. Decide per image:

1. **Model wrong, label right** → a data or model problem; note the condition the failures share.
2. **Label wrong** (wrong class, sloppy box) → a labeling problem; fix the label, and look for the same mistake elsewhere.
3. **Label missing** (object present, not annotated) → a labeling-completeness problem; the model is doing its job.

**Tag the cell, fix in the dataset.** Select a cell and use **Add Tags** to tag every image in it (for example `eval-fp-helmet-v3`). Then search `tag:eval-fp-helmet-v3` on the Images page, fix or relabel, and generate the next version. This is the fastest loop from evaluation to corrected data.

Drag the confidence slider (or pass `confidence` to the MCP tool) to see whether a problem is a threshold problem: if the background row empties out at a slightly higher threshold with little loss on the diagonal, deploy at that threshold.

### Improve Localization / IoU (mAP@50 vs mAP@50-95, object size)

`map50` counts a prediction as correct at 50% overlap. `map50_95` averages over overlap thresholds from 50% to 95% and rewards tight boxes; `map75` is the single strict point. A large gap between `map50` and `map50_95` means the model finds objects but draws them loosely, and the cause is almost always in the data or the input pipeline rather than the architecture.

| Cause | How to confirm | Fix |
|---|---|---|
| Labelers draw boxes differently (tight vs padded, include vs exclude shadows/handles/occluded parts) | Click diagonal cells and compare box edges across images labeled in different jobs (`job:<id>` search) | Write an explicit box-extent rule; relabel the class with the widest variation |
| Training resolution too low for the object size | `byObjectSize.small` far below medium/large | Raise the model's training resolution; use Tile preprocessing for high-resolution sources; Dynamic Crop around a parent class |
| Resize mode distorts aspect ratio | Dimension Insights shows wide aspect ratios; "Stretch to" resize in the version | Use "Fit within" or a letterbox resize |
| Crop or aggressive augmentation cuts objects | mAP@50-95 dropped after adding augmentation | Reduce crop, disable it for small objects, compare against a version without it |
| Mixed annotation types (polygons converted to boxes vs hand-drawn boxes) | Some boxes hug the object, others do not | Standardize on one annotation method for the class |
| Objects genuinely tiny in frame | Small-object bucket low even at high resolution | Capture closer or with a longer lens; the model cannot localize what it cannot see |

For instance and semantic segmentation the same logic applies to mask edges: inconsistent polygon detail across labelers shows up as low IoU with fine mAP@50. Smart Polygon with a consistent complexity setting produces more uniform edges than hand-drawn polygons.

### Confidence Sweep

The sweep shows precision, recall, and F1 at every threshold and marks the F1-optimal one, globally and per class. Once evaluation completes, that optimal threshold becomes the model's inference default, with per-class thresholds where available.

- If the user's complaint is "too many false alarms" or "it misses things" **in production**, check which threshold they deploy at before touching data. Many "bad model" reports are a default threshold of 0.5 on a model whose optimal is 0.3.
- Choose the operating point from the use case (Step 0): a safety detector wants the threshold where recall is acceptable; an automation trigger wants the precision point.
- The threshold cannot fix a class with both precision and recall low; that is a data or taxonomy problem.

### Vector Explorer

The evaluation embeds every image, projects to 2D, and clusters them. Each cluster carries mean F1, precision, and recall. A cluster with low F1 is a **condition the dataset under-covers**: a camera, a lighting regime, a background, a viewpoint, a time of day. Cluster `-1` is unclustered noise.

1. Open the weakest cluster (or filter `model_evals_get_image_predictions` by `cluster.id`).
2. Look at a dozen images and name what they share.
3. Tag them, then collect more images of exactly that condition for all splits.

This is the most reliable way to turn "the model is bad sometimes" into a concrete collection list.

### Dataset Health

Project sidebar > Health Check (`/{workspace}/{project}/health`, MCP `projects_health`).

| Panel | What to look for |
|---|---|
| Class balance per split | A class present in train but nearly absent from test (or the reverse); a class under a few dozen instances |
| Missing vs null annotations | **Missing** = uploaded but never labeled: exclude or label before training. **Null** = deliberately empty background images: you want some (see negatives below) |
| Dimension Insights | Mixed resolutions or aspect ratios that a stretch resize will distort |
| Annotation heatmap | Objects concentrated in one region of the frame; the model may learn position instead of appearance. Collect objects elsewhere in the frame or use crop/translate augmentation |
| Object-count histogram | If deployment images have many objects but training images have one, add dense scenes (and the reverse) |

## Step 3 — Root-Cause Deep Dives

### Taxonomy problems

The class list itself is the bug: two classes are not visually separable, one class is really an attribute of another, or definitions overlap so labelers choose differently.

| | |
|---|---|
| **Signs** | Symmetric off-diagonal confusion between two classes; a `wrong_class` recommendation that persists across versions; annotators disagree when shown the same image; classes with names like `defect-minor` / `defect-major` or `person-standing` / `person-walking` |
| **Confirm** | Show five images from the confused cell to two people and ask them to label; if they disagree, the model cannot do better. Check whether the distinction is visible in a single frame at the deployed resolution |
| **Fix** | Test a merge without touching the project: generate a version with the **Modify Classes** preprocessing step mapping both classes to one, train, compare. If the merged model is better, apply the merge at project level. Move attributes (color, state, severity) into a second stage: a classification project on Isolate Objects crops, or a Workflow step after detection. Split a class only when the sub-classes look different and each will have enough examples |

### Mislabeled data

| | |
|---|---|
| **Signs** | The background false-positive cell is full of real objects; false-negative cells show obvious, large, unoccluded objects; training-split mAP is surprisingly low; precision and recall are both low for one class |
| **Confirm** | Click through cells with the Ground Truth toggle. Search the dataset by `class:<name>` and scan for wrong classes. Run Label Assist with the current model on already-labeled images: disagreements between the model and the label are the images to review. Search `max-annotations:0` (excluding nulls) for unlabeled images that slipped into training |
| **Fix** | Tag the bad images from the confusion matrix, relabel them, and route future batches through Review mode. Turn on **Lock Annotation Classes** so typos do not create new classes. Re-run the evaluation after relabeling before adding any new data |

### Inconsistent label standards

Different people, or the same person on different days, apply different rules: whether to box occluded objects, how much padding to leave, whether a stack of items is one object or many, what the minimum size is, whether to label objects at the frame edge.

| | |
|---|---|
| **Signs** | mAP@50 acceptable but mAP@50-95 poor; recall for a class varies by batch; boxes on the diagonal cells vary in tightness; the model "misses" small or partial objects that some labelers boxed and others did not |
| **Confirm** | Search `job:<id>` for two different labeling jobs and compare how the same class was drawn. On premium plans, Annotation Insights shows per-labeler rejection counts and first-pass approval rate; a labeler with a much lower approval rate is applying a different standard |
| **Fix** | Write labeling instructions per batch (Add Instructions on the batch) that answer the specific ambiguities you found: box extent, occlusion rule, minimum size, group vs individual, edge-of-frame rule, when to mark null. Keep one reviewer as the arbiter. Relabel the weakest class first rather than the whole dataset. Prefer one annotation method per class (all boxes, or all Smart Polygon) |

### Missing data (coverage gaps)

The dataset never shows the model what it fails on.

| | |
|---|---|
| **Signs** | A vector cluster with low F1; production failures under conditions absent from the dataset (night, rain, a new camera, a new product variant); the annotation heatmap is concentrated; false negatives share a visible condition |
| **Confirm** | Name the condition from the failing images. Search the dataset for it (free-text semantic search works: `night`, `occluded`, `reflection`). If there are only a handful of matches, it is a coverage gap |
| **Fix** | Build a targeted collection list: conditions, viewpoints, distances, backgrounds, object variants. Include **negatives** (images with no target, marked null) and **hard negatives** (things that look like the target but are not). Set up Active Learning with a class or condition filter so production supplies these automatically; see `roboflow://skills/roboflow-training-and-evaluation/active-learning` |

### Not enough data

| | |
|---|---|
| **Signs** | Low mAP across all classes; `class_imbalance` recommendations; large gap between train and test metrics; the model improves every time data is added |
| **Heuristics** | Order-of-magnitude rules only: roughly 100–200 well-labeled instances per class before a class is learnable at all; 500+ per class for robust results; 1,000+ images before a larger model size pays off. Instances matter more than images for rare classes |
| **Fix** | Add real images of the weak classes. Augmentation multiplies what you have but does not add new information, so it cannot fix imbalance or coverage. Fork a domain-similar Universe dataset, then check it matches your cameras and labeling standard. Use Roboflow Rapid or Instant to bootstrap a labeler for your own images. Use the previous model as the checkpoint when retraining |

### Bad data

| | |
|---|---|
| **Signs** | Metrics that look too good (leakage); a test set that is a copy of train; blurry or tiny images; off-domain Universe images mixed in; frames from one video in every split |
| **Confirm** | Search `like-image:<id>` on a test image and see whether near-duplicates appear in train. Check Dimension Insights for outlier sizes. Compare a random test sample to production frames |
| **Fix** | Keep all frames from one video or session in one split. Lower the frame rate on video upload. Remove off-domain images or keep them in train only. Use Random Sample in version generation to thin dense near-duplicate sets. Drop images below the resolution the model will see in production |

### Model-side causes

If labels are consistent, coverage is adequate, and the class list is learnable, the remaining levers are the model's: architecture family, size, training resolution, checkpoint, epochs, and augmentation. Those live in `roboflow://skills/roboflow-training-and-evaluation/improvement-playbook`. Reach for them after the data checks above, not before, because they cost credits and cannot fix a data problem.

## Step 4 — Which Data to Add

Use the diagnosis to decide what goes into the next batch. "More of the same" only helps when the dataset is small and otherwise healthy.

| Diagnosis | Add | Do not |
|---|---|---|
| Labels are wrong or inconsistent | Nothing yet. Fix the standard and relabel the weakest class first | Add images labeled to the old standard |
| Class imbalance | Images containing the minority class, ideally several instances each | Rely on augmentation or oversampling |
| Background false positives (after confirming the labels are complete) | Null images of the deployment scene with no target, plus hard negatives: look-alike objects, reflections, printed pictures of the target | Add more positives; that raises confidence on false alarms too |
| Two classes confused | Contrastive examples: both classes side by side, and the borderline cases the boundary rule now settles | Add only the majority class of the pair |
| Small objects missed | Higher-resolution captures, closer viewpoints, images where the object is small but clearly visible | Upscale existing images |
| Coverage gap (a named condition) | That condition specifically, across all splits, under the same labeling standard | A random grab bag |
| Good in eval, bad in production | A random sample of production images collected through Active Learning, reviewed and added to train, valid, and test | Hand-picked "interesting" production frames only |
| Small dataset, otherwise healthy | More of everything, keeping class balance and condition mix | Duplicate frames from the same clips |

**How much, and how.** Add in batches of roughly 20–30% of the current dataset, retrain, and re-evaluate before adding the next batch. Change one thing per version so the metric delta has one explanation. As a starting share, a few percent up to about 10% null background images is enough for most detection projects; more if false positives on empty scenes are the main complaint.

## Step 5 — Iterate

1. **Baseline.** Record mAP@50, mAP@50-95, per-class recall and precision for the current version, on the test split, at the optimal threshold.
2. **One change.** Relabel, merge, add a batch, or change one training setting. Not several.
3. **Keep the exam fixed.** Same test-split membership, same metric, same split, same threshold policy when comparing.
4. **Retrain from the previous checkpoint** when the prior model was decent and the data change is incremental; start from a public checkpoint after large taxonomy or labeling changes.
5. **Re-evaluate and compare.** Did the targeted class or cluster move? Did anything else regress?
6. **Stop when** the metric meets the use-case target from Step 0, or when three consecutive data batches move it by less than the run-to-run noise. Then switch to model-side levers, or accept the model and tune the threshold.
7. **Hand the loop to production.** Once the model is deployed, Active Learning keeps supplying the conditions it still fails on. Filter collection by low confidence or by the weak classes rather than sampling everything.

## Related Pages

- `roboflow://skills/roboflow-training-and-evaluation/improvement-playbook` — model-side levers: architecture switching, model size, augmentation, overfitting, Instant vs full training
- `roboflow://skills/roboflow-training-and-evaluation/active-learning` — collect the missing conditions from production with a Project Model block and Active Learning
- `roboflow://skills/roboflow-data-management/labeling` — annotation tools, Label Assist, Smart Polygon, labeling instructions, jobs and review
- `roboflow://skills/roboflow-data-management/SKILL` — RoboQL search, tags, Modify Classes, Filter Null, Tile and Resize preprocessing, Dataset Analytics
