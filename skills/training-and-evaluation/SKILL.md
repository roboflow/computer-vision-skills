---
name: roboflow-training-and-evaluation
description: Use when training Roboflow models, improving accuracy, or setting up a production feedback loop — covers architecture selection, model IDs, checkpoints, evaluation metrics, the iterative improvement playbook, and active learning via the Dataset Upload workflow block.
---

> **For agents — source-of-truth:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills) and shipped with the Roboflow plugin. If your client has loaded the plugin (you'll see `roboflow:<name>` skills in your available skills list), use those local skills — they're read fresh from disk every session. The same content served as MCP resources at `roboflow://skills/<name>/...` is a fallback for clients without the plugin and may lag this repo. **Don't call `ReadMcpResourceTool` for `roboflow://skills/...` URIs when a local `roboflow:<name>` skill is available.**

# Training & Evaluation on Roboflow

## Training Flow

```
Upload/Annotate Images
  → Generate Dataset Version (preprocessing + augmentation + train/val/test split)
    → Pick Model Architecture + Size
      → Pick Checkpoint (COCO, Universe model, or previous version)
        → Train
          → Evaluate (auto-runs for paid users)
```

**Version = frozen snapshot.** Changes to the project after version creation do not affect it. Configure preprocessing (resize, contrast, etc.) and augmentation (flip, rotate, mosaic, etc.) during version generation.

## Available Model Architectures

### Object Detection

| Architecture | Sizes | Default Resolution | Notes |
|---|---|---|---|
| **RF-DETR** | Pico, Nano, Small, Base, Medium, Large, XL, 2XL | 384-880 (varies by size) | Best accuracy, recommended default |
| Roboflow 3.0 | Fast, Accurate, Medium, Large, XL | 640x640 | YOLOv8-based. Medium+ require paid plan |
| YOLO26 | n/s/m/l/x | 640x640 | Also supports seg + pose |
| YOLOv12 | n/s/m/l/x | 640x640 | OD only |
| YOLOv11 | n/s/m/l/x | 640x640 | Also supports seg + pose |
| YOLOv8 | n/s/m/l/x | 640x640 | Also supports seg + pose |
| YOLO-NAS | Small, Medium | 640x640 | |
| YOLOLite CPU | n/s/m/l/x | 640x640 | Edge-optimized, beta |
| YOLOLite GPU | n/s/m/l/x | 640x640 | Edge-optimized, beta |
| **Roboflow Instant** | single | N/A (no resize) | Few-shot, free, OD only |

### Instance Segmentation

| Architecture | Sizes | Default Resolution |
|---|---|---|
| **RF-DETR Seg** | Nano, Small, Medium, Large, XL, 2XL | 312-768 (varies) | Pico and Base not available for seg |
| Roboflow 3.0 Seg | Fast, Accurate, Medium, Large, XL | 640x640 |
| YOLO-seg | v8/v11/v26 (n/s/m/l/x each) | 640x640 |
| SAM 3 (Segment Anything 3) | Large | 1008x1008 |

### Semantic Segmentation

| Architecture | Sizes | Default Resolution |
|---|---|---|
| DeepLabV3+ | Base | >=512x512 |

### Classification

| Architecture | Sizes | Default Resolution |
|---|---|---|
| ViT | Base | 224x224 |
| ResNet | 18/34/50/101 | 224x224 |
| DINOv3 | Base, Small | 224x224 |

### Keypoint / Pose

| Architecture | Sizes | Default Resolution |
|---|---|---|
| YOLO-pose | v8/v11/v26 (n/s/m/l/x each) | 640x640 |

### Multimodal / VLM

| Architecture | Sizes | Default Resolution |
|---|---|---|
| **Qwen3.5** | 0.8B, 2B | 448x448 |
| Qwen3 VL | 2B | 448x448 |
| SmolVLM | 256M, 2B | 384x384 |
| Florence 2 | Base, Large | 768x768 |
| PaliGemma 2 | 3B | 448x448 |
| Qwen2.5 VL | 7B | 448x448 |

## Model Selection Decision Tree

Follow this flowchart to pick the right model. Start at Step 1.

1. **Task type?** OD / Instance Seg / Keypoint → Step 2. Classification / Semantic Seg / VLM → use specialized block directly.
2. **Target classes in COCO 80?** Yes → Step 3. No → Step 6.
3. **Real-time?** No (images/recorded video) → Step 4. Yes (live video) → Step 5.
4. **Non-real-time, COCO** — Pick model family by task, default Medium size (Small for constrained HW, XL for accuracy-first): OD → RF-DETR, Inst Seg → RF-DETR Seg, Keypoint → YOLO26 pose. **Done.**
5. **Real-time, COCO** — Same families, pick Nano–Small, prioritize latency. **Done.**
6. **Non-COCO, which sub-task?** OD → Step 7. Inst Seg → Step 8. Keypoint → Step 9.
7. **OD, non-COCO** — Check Rapid exclusions (see below). If excluded → Step 13. Otherwise → recommend **Roboflow Rapid** (default) or SAM3 zero-shot as secondary option → Step 10.
8. **Inst Seg, non-COCO** — SAM3 zero-shot (`sam3/sam3_final`, set `class_names`). Rapid does not support segmentation → Step 10.
9. **Keypoint, non-COCO** — Not real-time → YOLO26 pose Medium–XL. Real-time → YOLO26 pose Nano–Small. **Done.**
10. **Real-time?** No → try model (Step 11). Yes → warn about latency, try model (Step 12).
11. **Non-real-time trial** — User confirms works → **Done.** Poor results → Step 13.
12. **Real-time trial** — User confirms works → **Done.** Poor results → Step 13.
13. **Universe Model Search** — search community models on Roboflow Universe. Good match → **Done.** No match → Step 14.
14. **Custom Training** — Fine-tune RF-DETR on user data. Size by HW constraints. **Done.**

## Model ID Reference

Use these exact `model_id` values. Do not guess — wrong IDs cause training failures.

### Object Detection

| Family | model_id values |
|---|---|
| **RF-DETR** (recommended) | `rfdetr-pico`, `rfdetr-nano`, `rfdetr-small`, `rfdetr-base`, `rfdetr-medium`, `rfdetr-large`, `rfdetr-xlarge`, `rfdetr-2xlarge` |
| YOLO26 | `yolo26n`, `yolo26s`, `yolo26m`, `yolo26l`, `yolo26x` |
| YOLOv12 | `yolov12n`, `yolov12s`, `yolov12m`, `yolov12l`, `yolov12x` |
| YOLOv11 | `yolov11n`, `yolov11s`, `yolov11m`, `yolov11l`, `yolov11x` |
| YOLOv8 | `yolov8n`, `yolov8s`, `yolov8m`, `yolov8l`, `yolov8x` |
| YOLO-NAS | `yolo_nas_s`, `yolo_nas_m`, `yolo_nas_l` |
| YOLOLite CPU | `yololite-edge-n`, `yololite-edge-s`, `yololite-edge-m`, `yololite-edge-l`, `yololite-edge-xl` |
| YOLOLite GPU | `yololite-n`, `yololite-s`, `yololite-m`, `yololite-l`, `yololite-xl` |

### Instance Segmentation

| Family | model_id values |
|---|---|
| **RF-DETR Seg** (recommended) | `rfdetr-seg-nano`, `rfdetr-seg-small`, `rfdetr-seg-medium`, `rfdetr-seg-large`, `rfdetr-seg-xlarge`, `rfdetr-seg-2xlarge` |
| YOLO26 Seg | `yolo26n-seg`, `yolo26s-seg`, `yolo26m-seg`, `yolo26l-seg`, `yolo26x-seg` |
| YOLOv11 Seg | `yolov11n-seg`, `yolov11s-seg`, `yolov11m-seg`, `yolov11l-seg`, `yolov11x-seg` |
| YOLOv8 Seg | `yolov8n-seg`, `yolov8s-seg`, `yolov8m-seg`, `yolov8l-seg`, `yolov8x-seg` |
| SAM3 | `sam3-large` |

### Keypoint / Pose

| Family | model_id values |
|---|---|
| YOLO26 Pose | `yolo26n-pose`, `yolo26s-pose`, `yolo26m-pose`, `yolo26l-pose`, `yolo26x-pose` |
| YOLOv11 Pose | `yolov11n-pose`, `yolov11s-pose`, `yolov11m-pose`, `yolov11l-pose`, `yolov11x-pose` |
| YOLOv8 Pose | `yolov8n-pose`, `yolov8s-pose`, `yolov8m-pose`, `yolov8l-pose`, `yolov8x-pose` |

### Classification

| Family | model_id values |
|---|---|
| ViT | `vit-base-patch16-224-in21k` |
| ResNet | `resnet18`, `resnet34`, `resnet50`, `resnet101` |
| DINOv3 | `vit_base_patch16_dinov3.lvd1689m`, `vit_small_patch16_dinov3.lvd1689m` |

### Semantic Segmentation

| Family | model_id values |
|---|---|
| DeepLabV3+ | `deeplabv3plus` |

### Multimodal / VLM

| Family | model_id values |
|---|---|
| Qwen3.5 VL | `qwen3_5-2b-peft`, `qwen3_5-0.8b-peft` |
| Qwen3 VL | `qwen3vl-2b-instruct`, `qwen3vl-2b-instruct-peft` |
| SmolVLM | `smolvlm2-peft`, `smolvlm-256m-peft` |
| Florence 2 | `florence-2-base`, `florence-2-large`, `florence-2-base-peft`, `florence-2-large-peft` |
| PaliGemma 2 | `paligemma2-3b-pt-224`, `paligemma2-3b-pt-448`, `paligemma2-3b-pt-896`, `paligemma2-3b-pt-224-peft` |
| Qwen2.5 VL | `qwen25-vl-7b`, `qwen25-vl-7b-peft` |

### Other

| Model | model_id | Notes |
|---|---|---|
| SAM3 (zero-shot, workflows) | `sam3/sam3_final` | Always set `class_names`; no other props unless user asks |
| Custom / workspace | `workspace/model` or `dataset/version` | e.g., `construction-safety/2` |

### COCO 80 Classes (RF-DETR coverage)

person, bicycle, car, motorcycle, airplane, bus, train, truck, boat, traffic light, fire hydrant, stop sign, parking meter, bench, bird, cat, dog, horse, sheep, cow, elephant, bear, zebra, giraffe, backpack, umbrella, handbag, tie, suitcase, frisbee, skis, snowboard, sports ball, kite, baseball bat, baseball glove, skateboard, surfboard, tennis racket, bottle, wine glass, cup, fork, knife, spoon, bowl, banana, apple, sandwich, orange, broccoli, carrot, hot dog, pizza, donut, cake, chair, couch, potted plant, bed, dining table, toilet, tv, laptop, mouse, remote, keyboard, cell phone, microwave, oven, toaster, sink, refrigerator, book, clock, vase, scissors, teddy bear, hair drier, toothbrush.

## Model Selection Quick Guide

| Goal | Recommended |
|---|---|
| Best accuracy, object detection | RF-DETR (Large or XL) |
| Fast inference, object detection | RF-DETR Nano or YOLOv11n |
| Best speed/accuracy tradeoff for specific hardware | RF-DETR NAS (see section below) |
| Best accuracy, instance segmentation | RF-DETR Seg |
| Quick proof-of-concept (<1000 images) | Roboflow Instant |
| Classification | ViT or DINOv3 |
| Multimodal / text prompts | Qwen3.5 or SmolVLM |

## RF-DETR NAS (Neural Architecture Search)

Instead of picking a single RF-DETR size manually, NAS trains many variants and reports the speed/accuracy frontier so you can pick the one that fits your hardware budget.

- **What:** A NAS run explores the RF-DETR architecture search space, then trains the surviving candidates and reports each one's mAP and measured latency on a target hardware (e.g., Jetson, T4 GPU). The output is a set of models on a Pareto frontier, plus an auto-selected "recommended" model chosen using Roboflow's current ranking heuristic to balance validation accuracy and measured latency on the target hardware.
- **Tasks:** Object Detection (`rfdetr-nas`) and Instance Segmentation (`rfdetr-nas-seg`).
- **When to use:** When you want the best speed/accuracy tradeoff for a specific deployment target and don't want to A/B-test sizes manually. Especially valuable for edge hardware where latency budgets are tight.
- **Phases:**
  1. **Mining** — explores architectures and builds a Pareto frontier (latency vs mAP). Live updates while running.
  2. **Training** — trains each frontier candidate end-to-end. Each becomes a regular model you can deploy.
- **Plan gating:** Requires the `canTrainNas` workspace feature flag. Self-serve plans (basic/starter/sandbox/research/trial) need to upgrade; enterprise/legacy plans need to contact sales.
- **Start a run:** Train page with `?engine=nas` (UI: pick **Neural Architecture Search** as the training engine). Results land at `/{workspace}/{project}/nas-runs/{versionId}`.
- **Deploy:** Each NAS-produced model deploys like any other — pick one (typically the recommended) and use it as a normal Roboflow model. Inference type is `rfdetr-nas` / `rfdetr-nas-seg`, but it's served through the standard inference paths.
- **References:** [RF-DETR paper (arxiv)](https://arxiv.org/html/2511.09554v2), [ICLR 2026](https://openreview.net/forum?id=qHm5GePxTh), [What is NAS? (blog)](https://blog.roboflow.com/neural-architecture-search/).

## Roboflow Instant / Rapid

### Roboflow Instant
- **What:** Few-shot model, trains in minutes, free
- **Task:** Object Detection only
- **When to use:** PoC, <1000 images, quick iteration
- **Auto-trains** when you approve a batch and no Instant model exists yet
- **No preprocessing/augmentation** -- uses images as-is
- **Deploy:** Available in Workflows like any trained model
- Manual trigger: Project > Models > Train Model > Roboflow Instant Model

### Roboflow Rapid
- **What:** Interactive annotation-and-training workflow — SAM3 pre-annotates a small image set, user reviews/corrects, a fast custom OD model trains automatically. Model keeps improving as it captures more production data.
- **Task:** Object Detection only, non-COCO classes
- **When to use:** Default path for non-COCO object detection when exclusions don't apply

**Do NOT use Rapid when:**

| Exclusion | Why |
|---|---|
| OCR / text detection (characters, serial numbers, labels, receipts, license plates) | SAM3 cannot reliably segment individual characters |
| Blueprints, floor plans, schematics, technical drawings | Abstract symbols and line-based elements not handled by SAM3 text prompting |
| More than 5 target classes | SAM3 text prompting accuracy degrades significantly with many classes |
| Fine-grained visual distinctions (correct vs incorrect orientation, pass/fail, subtle defects) | SAM3 cannot differentiate nearly identical objects; fine-tuned model needed |
| High-precision measurement / metrology (distances, dimensions, tolerances) | SAM3 auto-labeling annotation precision insufficient for calibrated measurement |

When Rapid is excluded → recommend custom training with RF-DETR fine-tuning.

## Checkpoint Training

| Option | When to use |
|---|---|
| **Public Checkpoint** (COCO) | First model version, default recommended |
| **Universe Checkpoint** | Star a Universe project first, then it appears as checkpoint option. Good for domain-specific transfer learning |
| **Previous Version** | Already have a good model, want to improve with more data (all types except classification and SAM3) |
| **Random Initialization** | Advanced users only, usually worse results |

## Training Controls

- **Cancel Training:** Stops job, no weights saved. Refund if early in training.
- **Early Stopping:** Stops job, saves weights. Use when graphs show convergence with many epochs remaining. Charges for used credits.
- **NAS Training:** Shows paired charts (mining progress + Pareto curve, then per-model training curves). May auto-stop on convergence. See **RF-DETR NAS** section below.

## Post-Training Metrics

Metrics vary by project type:

| Project Type | Metrics Shown |
|---|---|
| Object Detection | mAP@50, Precision, Recall, F1 |
| Classification | Accuracy |
| Instance Segmentation / Keypoint | mAP@50, Precision, Recall |
| Semantic Segmentation | mIoU |
| Multimodal | Perplexity |

## Model Evaluation (Paid Plans)

Auto-runs after training. Access: Models > click model version > View Evaluation.

| Feature | What it shows |
|---|---|
| **Production Metrics Explorer** | Precision/Recall/F1 at all confidence thresholds; recommends optimal confidence |
| **Model Improvement Recommendations** | Actionable suggestions (false negatives, false positives, confused classes, insufficient data) |
| **Performance by Class** | Correct predictions, misclassifications, false negatives, false positives per class; filterable |
| **Confusion Matrix** | Ground truth vs predictions grid; click cells to see specific images; adjustable confidence threshold |
| **Vector Explorer** | Interactive embedding clusters showing where model succeeds/fails |

## Viewing & Comparing Models

- **Models page:** Project sidebar > Models. Shows all Instant + fine-tuned models with metrics, architecture, license, dataset version used.
- **Universe tab:** Starred Universe models available for transfer learning.
- **Visualize:** Quick test on test-set images, uploaded images, or webcam. Works for OD, segmentation, classification, keypoint. Not supported for multimodal.

## MCP Tools Reference

| Action | Tool |
|---|---|
| Generate version | `versions_generate` |
| Start training | `models_train` |
| Check training status | `models_get_training_status` |
| Get model info | `models_get` |
| List models | `models_list` |

## Related Pages

- `roboflow://skills/roboflow-model-improvement/SKILL` — diagnostic decision tree, confusion matrix guide, per-class metrics, architecture switching, iterative improvement checklist
- `roboflow://skills/training-and-evaluation/active-learning` — production feedback loop: Dataset Upload workflow block, confidence-based sampling, review and retrain cycle
