---
name: roboflow-model-improvement
description: Diagnostic playbook for improving trained model accuracy — decision tree, confusion matrix analysis, per-class metrics, label-quality and taxonomy checks, common failure modes, architecture switching, and iterative improvement checklist.
---

# Model Improvement Playbook

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:roboflow-training-and-evaluation`) over fetching `roboflow://skills/roboflow-training-and-evaluation/improvement-playbook` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

## Diagnostic Decision Tree

```
Model not good enough?
├─ Can the test set be trusted?
│  ├─ Test split < 50 images or < 5% of dataset → Regenerate with a larger held-out split first
│  ├─ Frames from the same video/session in train AND test → Leakage; keep each source in one split
│  └─ Test set doesn't look like deployment (camera, lighting, distance) → Add production images to all splits
│
├─ mAP/accuracy very low (<30%)?
│  ├─ Too few images → Add more data (target 500+ per class)
│  ├─ Labeling errors → Audit annotations, use AI labeling for consistency
│  ├─ Unlabeled images in training ("missing" in Dataset Health) → Label or exclude them
│  └─ Wrong model type → Verify project type matches task (OD vs seg vs cls)
│
├─ Train metrics high, test metrics low?
│  ├─ No leakage → Overfitting; see below
│  └─ Leakage found → Fix splits, re-evaluate before anything else
│
├─ mAP@50 fine but mAP@50-95 / mAP@75 poor (finds objects, boxes are loose)?
│  ├─ Box extents vary between labelers/jobs → Write a box-extent rule, relabel the worst class
│  ├─ Small-object bucket low → Increase training resolution, Tile preprocessing, capture closer
│  └─ Crop/stretch in the version → Reduce crop, use "Fit within" resize
│
├─ High false positives (model sees objects that aren't there)?
│  ├─ Click the background FP cell → Are the "false positives" real objects?
│  │  ├─ Yes → Ground truth is missing labels; label them (the model is right)
│  │  └─ No → Add null/negative examples and hard negatives (look-alikes)
│  ├─ Check confusion matrix → Which classes are confused?
│  │  ├─ Confused both directions → Taxonomy or labeler disagreement; test a merge with Modify Classes
│  │  └─ Confused one direction → Add distinguishing examples of the weaker class
│  └─ Raise confidence threshold → Use Production Metrics Explorer optimal threshold
│
├─ High false negatives (model misses real objects)?
│  ├─ Check per-class metrics → Which classes underperform?
│  │  ├─ Specific class weak → Add more examples of that class
│  │  ├─ Misses share a condition (lighting, angle, occlusion) → Coverage gap; collect that condition
│  │  └─ Small objects missed → Increase training resolution, add small-object examples
│  └─ Lower confidence threshold → Trade precision for recall
│
├─ Some classes good, others bad?
│  ├─ Class imbalance → Check class distribution, add underrepresented classes
│  ├─ Inconsistent labeling on weak classes → Re-label with tighter guidelines
│  └─ Class definition overlaps another → Merge, split, or move the attribute to a second stage
│
├─ Good in evaluation, bad in production?
│  ├─ Deployed at a default threshold → Use the evaluation's optimal (per-class) threshold
│  └─ Distribution shift → Active Learning random sample from production, review, retrain
│
└─ Plateaued after several versions?
   ├─ Changed several things per version → Change one variable, keep the test split fixed
   ├─ Try different architecture → Switch YOLO to RF-DETR or vice versa
   ├─ Try larger model size → Nano→Small, Small→Medium
   ├─ Use Universe checkpoint → Transfer learn from domain-similar model
   └─ Review augmentations → Over-augmentation can hurt; simplify
```

For the full walkthrough behind each branch — the MCP evaluation recipe, the recommendation types and their triggers, root-cause deep dives (taxonomy, mislabeled data, inconsistent label standards, coverage gaps, too little data, bad data), and which data to add for each finding — see `roboflow://skills/roboflow-training-and-evaluation/model-diagnosis`.

## Reading the Confusion Matrix

| Cell position | Meaning | Action |
|---|---|---|
| Diagonal (dark) | Correct predictions | Goal: maximize these |
| Off-diagonal row | Model predicted class X but ground truth is class Y | Classes look similar — add distinguishing examples or merge |
| Off-diagonal, populated in both directions (X→Y and Y→X) | Neither the model nor the labelers separate the two classes | Taxonomy or label-standard problem, not a data-volume problem; test a merge with version-level Modify Classes, or write a boundary rule and relabel |
| "False Positive" column | Model detected object where none exists | Click the cell first: if the objects are real, the ground truth is missing labels. Otherwise add negative/background images and hard negatives |
| "False Negative" row | Model missed a real object | Add more examples, lower confidence, check label quality. If the misses share a condition, collect that condition |

**Tip:** Click any cell to see the actual images. Toggle between Ground Truth and Model Predictions to understand the failure mode. For each image decide: model wrong (data or model problem), label wrong (relabel), or label missing (the model is right). Select a cell and use **Add Tags** to tag its images, then search `tag:<name>` on the Images page to fix them in bulk.

The matrix is shown at the evaluation's optimal confidence threshold; drag the slider to see whether a problem disappears at a slightly different threshold. If the false-positive column empties out with little loss on the diagonal, it is a threshold problem, not a data problem.

## Reading Per-Class Metrics

| Metric | Low value means | Fix |
|---|---|---|
| Precision (class) | Too many false positives for this class | Add negative examples, improve label boundaries |
| Recall (class) | Too many missed detections | Add more positive examples, check label completeness |
| Both low | Class is fundamentally hard for model | Audit this class's labels first; then re-evaluate the class definition; then more data or a bigger model |
| mAP@50 fine, mAP@50-95 low | Objects found but boxes are loose | Inconsistent box extents between labelers, low resolution, or crop augmentation; see the localization branch above |
| mAP `null` | No instances of the class in the test split | The test set does not cover the class; fix the split before judging the class |
| Optimal threshold far from the global one | The class needs its own operating point | Deploy with per-class thresholds from the confidence sweep |

Evaluation also reports mAP by object size (small / medium / large). A low small-object bucket with healthy medium and large points at resolution, tiling, or capture distance rather than labels.

## Reading the Model Improvement Recommendations

The evaluation's recommendations panel is generated from the confusion matrix. Current types and what they usually mean underneath:

| Type | Usually means | First check |
|---|---|---|
| `missed_detection` | The class with the most false negatives lacks examples, or its misses share a condition | Click the class's false-negative cell |
| `wrong_class` | The most common misclassified pair; usually taxonomy overlap or labeler disagreement | Is the confusion symmetric? |
| `class_imbalance` | A class far below the median count | Add that class specifically; augmentation does not fix imbalance |
| `overconfident_fp` | A class with many confident false positives; very often unlabeled real objects | Toggle Ground Truth vs Predictions on the background FP cell |
| `dataset_health` | Test or valid split too small to trust the metrics | Regenerate with a larger held-out split |

MCP: `model_evals_list` → `model_evals_get_recommendations`, `model_evals_get_performance_by_class`, `model_evals_get_confusion_matrix`, `model_evals_get_map_results`, `model_evals_get_confidence_sweep`; dataset stats via `projects_health`. The full recipe is in the model-diagnosis page.

## Common Issues & Roboflow-Specific Fixes

### Insufficient Data

| Action | How in Roboflow |
|---|---|
| **Production pipeline (active learning)** | Use a Project Model block with Active Learning so production inference images become reviewable data for annotation, retraining, and model improvement. Best for capturing real-world distribution. See `roboflow://skills/roboflow-training-and-evaluation/active-learning` |
| Fork from Universe | Universe > find similar dataset > fork to your project. Adds labeled images directly |
| AI Labeling | Upload unlabeled images > use AI-assisted labeling to annotate faster |
| Augmentation | Version settings > enable flip, rotation, crop, mosaic, etc. to synthetically expand training set |

### Class Imbalance

| Symptom | Fix |
|---|---|
| Majority class dominates predictions | Add more images of minority classes |
| Rare class has near-zero recall | Target 500+ annotations per class minimum |
| Check distribution | Look at per-class counts in dataset overview |

### Wrong Augmentation

| Problem | Solution |
|---|---|
| Objects are orientation-sensitive but flip is on | Disable horizontal/vertical flip |
| Small objects disappear after crop | Reduce crop aggressiveness or disable |
| Color-dependent task with heavy color jitter | Reduce or disable hue/saturation/brightness augmentation |
| Over-augmented (mAP worse than no augmentation) | Generate new version with fewer augmentations and compare |

### Overfitting

Signs: Training loss drops but validation loss increases or plateaus.

| Fix | How |
|---|---|
| Add more data | Upload + annotate, or fork from Universe |
| Increase augmentation | New version with more augmentation steps |
| Use smaller model | e.g., switch from Large to Medium |
| Early stopping | Use "Stop Training Early" when graphs show divergence |

## Architecture Switching Guide

| Current → Try | When |
|---|---|
| YOLO → RF-DETR | Want better accuracy, can accept slightly slower inference |
| RF-DETR → YOLO | Need faster inference, edge deployment |
| Small → Large (same family) | Have enough data (1000+ images), accuracy matters more than speed |
| Large → Small (same family) | Overfitting, or need faster inference |
| Any → Roboflow Instant | Quick PoC, want results in minutes (OD only) |

## Roboflow Instant vs Full Training

| | Roboflow Instant | Full Training |
|---|---|---|
| Speed | Minutes | Hours |
| Cost | Free | Credits-based |
| Task types | Object Detection only | All types |
| Data size | <1000 images ideal | Any size |
| Preprocessing | None | Full control |
| Augmentation | None | Full control |
| Accuracy | Good for PoC | Production-grade |
| **Use when** | Prototyping, validating concept | Production deployment |

## mAP Field Reference

The mAP@50 metric appears under different field names depending on the endpoint:

| Source | Field | Type |
|---|---|---|
| `versions_get` | `map` | string |
| `models_list` | `map50` | number |

Both are mAP@50. Cast to number before comparing.

## Iterative Improvement Checklist

1. **Check evaluation** -- Open Model Evaluation (or run the MCP tools above), review recommendations, confusion matrix, and per-class metrics
2. **Identify weakest classes** -- Sort by lowest recall/precision; click the cells and look at the images
3. **Diagnose root cause** -- Use decision tree above; for deep dives see `roboflow://skills/roboflow-training-and-evaluation/model-diagnosis`
4. **Take action** -- Fix labels or taxonomy first; then add the specific data the diagnosis calls for; then adjust augmentation or switch architecture
5. **Generate new version** -- New preprocessing/augmentation settings if needed
6. **Train new model** -- Use previous version as checkpoint if prior model was decent
7. **Compare** -- Check if mAP/precision/recall improved vs previous version
8. **Repeat** -- Target: mAP >70% for production use (domain-dependent)

## Related Pages

- `roboflow://skills/roboflow-training-and-evaluation/model-diagnosis` — full diagnosis walkthrough: evaluation panels, MCP recipe, root-cause deep dives, which data to add
- `roboflow://skills/roboflow-training-and-evaluation/active-learning` — set up a production feedback loop with a Project Model block and Active Learning
