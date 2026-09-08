---
name: roboflow-model-improvement
description: Model-side levers for improving trained model accuracy once the data has been diagnosed — insufficient data, class imbalance, augmentation mistakes, overfitting, architecture switching, Instant vs full training, and the iterative improvement checklist.
---

# Model Improvement Playbook

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:roboflow-training-and-evaluation`) over fetching `roboflow://skills/roboflow-training-and-evaluation/improvement-playbook` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

## Diagnose First

Do not start here. Most "bad model" reports are data problems — mislabeled images, labelers applying different standards, a taxonomy that overlaps, conditions the dataset never shows, too few examples of a class, or leaked frames across splits — and no training setting fixes those. Run Model Evaluation and work through `roboflow://skills/roboflow-training-and-evaluation/model-diagnosis` first: it covers the confusion matrix, per-class metrics, mAP@50 vs mAP@50-95, object-size breakdown, confidence sweep, vector explorer, the recommendation types, and which data to add for each finding.

Come back to this page when the diagnosis points at the model itself:

| Finding from diagnosis | Lever on this page |
|---|---|
| Labels consistent, coverage adequate, still low mAP on a small dataset | Insufficient Data (below), then a Universe checkpoint |
| Train metrics high, test metrics low, no leakage | Overfitting |
| mAP dropped after adding augmentation, or orientation/color-sensitive classes | Wrong Augmentation |
| Plateaued across several clean data batches | Architecture Switching, larger model size |
| Small-object mAP low at adequate resolution | Larger model or higher training resolution; Tile preprocessing (see data-management) |
| Need results in minutes for a proof of concept | Roboflow Instant vs Full Training |

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

1. **Check evaluation** -- Open Model Evaluation (or run the MCP recipe in `roboflow://skills/roboflow-training-and-evaluation/model-diagnosis`), review recommendations, confusion matrix, and per-class metrics
2. **Identify weakest classes** -- Sort by lowest recall/precision; click the cells and look at the images
3. **Diagnose root cause** -- Use the symptom table in the diagnosis page: labels, taxonomy, coverage, volume, bad data, or model
4. **Take action** -- Fix labels or taxonomy first; then add the specific data the diagnosis calls for; then adjust augmentation or switch architecture
5. **Generate new version** -- New preprocessing/augmentation settings if needed
6. **Train new model** -- Use previous version as checkpoint if prior model was decent
7. **Compare** -- Check if mAP/precision/recall improved vs previous version
8. **Repeat** -- Target: mAP >70% for production use (domain-dependent)

## Related Pages

- `roboflow://skills/roboflow-training-and-evaluation/model-diagnosis` — diagnose first: evaluation panels, symptom → root cause → action, which data to add
- `roboflow://skills/roboflow-training-and-evaluation/active-learning` — set up a production feedback loop with a Project Model block and Active Learning
