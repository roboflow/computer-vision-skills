---
name: roboflow-model-improvement
description: Diagnostic playbook for improving trained model accuracy — confusion matrix analysis, per-class metrics, common failure modes, architecture switching, and iterative improvement checklist.
---

# Model Improvement Playbook

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:training-and-evaluation`) over fetching `roboflow://skills/training-and-evaluation/improvement-playbook` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

## Diagnostic Decision Tree

```
Model not good enough?
├─ mAP/accuracy very low (<30%)?
│  ├─ Too few images → Add more data (target 500+ per class)
│  ├─ Labeling errors → Audit annotations, use AI labeling for consistency
│  └─ Wrong model type → Verify project type matches task (OD vs seg vs cls)
│
├─ High false positives (model sees objects that aren't there)?
│  ├─ Check confusion matrix → Which classes are confused?
│  │  ├─ Two classes confused → Visually similar? Merge or add distinguishing examples
│  │  └─ Background false positives → Add null/negative examples (images with no objects)
│  └─ Raise confidence threshold → Use Production Metrics Explorer optimal threshold
│
├─ High false negatives (model misses real objects)?
│  ├─ Check per-class metrics → Which classes underperform?
│  │  ├─ Specific class weak → Add more examples of that class
│  │  └─ Small objects missed → Increase training resolution, add small-object examples
│  └─ Lower confidence threshold → Trade precision for recall
│
├─ Some classes good, others bad?
│  ├─ Class imbalance → Check class distribution, add underrepresented classes
│  └─ Inconsistent labeling on weak classes → Re-label with tighter guidelines
│
└─ Plateaued after several versions?
   ├─ Try different architecture → Switch YOLO to RF-DETR or vice versa
   ├─ Try larger model size → Nano→Small, Small→Medium
   ├─ Use Universe checkpoint → Transfer learn from domain-similar model
   └─ Review augmentations → Over-augmentation can hurt; simplify
```

## Reading the Confusion Matrix

| Cell position | Meaning | Action |
|---|---|---|
| Diagonal (dark) | Correct predictions | Goal: maximize these |
| Off-diagonal row | Model predicted class X but ground truth is class Y | Classes look similar — add distinguishing examples or merge |
| "False Positive" column | Model detected object where none exists | Add negative/background images |
| "False Negative" row | Model missed a real object | Add more examples, lower confidence, check label quality |

**Tip:** Click any cell to see the actual images. Toggle between Ground Truth and Model Predictions to understand the failure mode.

## Reading Per-Class Metrics

| Metric | Low value means | Fix |
|---|---|---|
| Precision (class) | Too many false positives for this class | Add negative examples, improve label boundaries |
| Recall (class) | Too many missed detections | Add more positive examples, check label completeness |
| Both low | Class is fundamentally hard for model | More data, bigger model, or re-evaluate class definition |

## Common Issues & Roboflow-Specific Fixes

### Insufficient Data

| Action | How in Roboflow |
|---|---|
| **Production pipeline (active learning)** | If you have a deployed workflow, add a Dataset Upload block to pipe production images back to your project automatically. Best for capturing real-world distribution. See `roboflow://skills/training-and-evaluation/active-learning` |
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

1. **Check evaluation** -- Open Model Evaluation, review confusion matrix and per-class metrics
2. **Identify weakest classes** -- Sort by lowest recall/precision
3. **Diagnose root cause** -- Use decision tree above
4. **Take action** -- Add data, fix labels, adjust augmentation, or switch architecture
5. **Generate new version** -- New preprocessing/augmentation settings if needed
6. **Train new model** -- Use previous version as checkpoint if prior model was decent
7. **Compare** -- Check if mAP/precision/recall improved vs previous version
8. **Repeat** -- Target: mAP >70% for production use (domain-dependent)

## Related Pages

- `roboflow://skills/training-and-evaluation/active-learning` — set up a production feedback loop with the Dataset Upload workflow block
