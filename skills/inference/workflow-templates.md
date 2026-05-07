# Workflow Templates

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:inference`) over fetching `roboflow://skills/inference/workflow-templates` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

Quick-reference catalog of built-in workflow templates. Use these as starting points when building workflows via the editor or `workflow_specs_run`.

## Detection & Counting

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **detect-count-common-objects** | Count everyday objects (people, cars, trucks) with class filter | `[Object Detection Model]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image -> annotated image, count, predictions |
| **vehicle-detection** | Count and locate vehicles for traffic/parking monitoring | `[Object Detection Model]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image -> annotated image, vehicle count, predictions |
| **people-detection** | Detect and count people for security/retail analytics | `[Object Detection Model]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image -> annotated image, people count, predictions |
| **pothole-detection** | Detect road potholes for infrastructure monitoring | `[Object Detection Model]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image -> annotated image, pothole count, predictions |
| **detect-and-count-fish** | Count fish using zero-shot detection (no custom model needed) | `[YOLO-World Model]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image -> annotated image, fish count, predictions |

## SAHI (Small Object Detection)

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **sahi** | Compare sliced vs full-image detection for small objects | `[Image Slicer]` `[Object Detection Model]` `[Detections Stitch]` `[Bounding Box Visualization]` `[Label Visualization]` | Image -> two annotated images (SAHI vs standard), both predictions |
| **people-detection-sahi** | Detect small/distant people in wide-angle or aerial images | `[Image Slicer]` `[Object Detection Model]` `[Detections Stitch]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image -> annotated image, people count, stitched predictions |
| **vehicle-detection-sahi** | Detect small vehicles in aerial/satellite imagery | `[Image Slicer]` `[Object Detection Model]` `[Detections Stitch]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image -> annotated image, vehicle count, stitched predictions |

## Segmentation & Masking

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **sam2** | Auto-generate segmentation masks from detected bounding boxes | `[Object Detection Model]` `[Segment Anything 2 Model]` `[Bounding Box Visualization]` `[Halo Visualization]` `[Polygon Visualization]` `[Label Visualization]` | Image -> three annotated images (bbox, halo, polygon) |
| **bg-removal** | Remove background via bbox or instance segmentation (two paths) | `[Object Detection Model]` `[Instance Segmentation Model]` `[Background Color Visualization]` | Image -> two bg-removed images (rectangular vs precise), predictions |

## Multi-Model Pipelines

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **read-license-plates** | Chain: detect cars -> find plates -> OCR text, with active learning upload | `[Object Detection Model]` x2 `[Dynamic Crop]` x2 `[OpenAI]` `[Continue If]` `[Roboflow Dataset Upload]` `[Bounding Box Visualization]` `[Label Visualization]` | Image + project URL -> plate text, cropped plates, annotated image, upload confirmation |
| **recognize-emotions** | Chain: detect faces -> crop -> classify emotion per face | `[Object Detection Model]` `[Dynamic Crop]` `[Single-Label Classification Model]` `[Detections Classes Replacement]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image -> annotated image with emotion labels, emotion list, face crops |
| **rock-paper-scissors** | Detect hand gestures, determine winner by position and rules | `[Object Detection Model]` `[Detections Transformation]` `[Property Definition]` `[Expression]` `[Continue If]` `[Dynamic Crop]` `[Bounding Box Visualization]` `[Label Visualization]` | Image -> winner (LEFT/RIGHT/TIE), gesture list, annotated image, winning hand crop |

## Conditional Branching

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **branching** | Classify first, then route to specialized segmentation model per class | `[Single-Label Classification Model]` `[Continue If]` `[Instance Segmentation Model]` `[Polygon Visualization]` `[Label Visualization]` | Image -> classification result, branch-specific annotated image |
| **animal-classifier** | Classify animal species, route to species-specific segmentation | `[Single-Label Classification Model]` `[Continue If]` `[Instance Segmentation Model]` `[Polygon Visualization]` `[Label Visualization]` | Image -> animal type, branch-specific annotated image |

## Zone Analytics

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **detect-backup** | Monitor a conveyor zone for package accumulation, trigger alerts | `[Object Detection Model]` `[Detections Filter]` `[Bounding Box Visualization]` `[Relative Static Crop]` `[Property Definition]` `[Expression]` | Image -> zone crop, package count, backup boolean, predictions |
| **detect-people-in-target-zone** | Check occupancy of defined zones (checkout counters, restricted areas) | `[Relative Static Crop]` `[Object Detection Model]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` `[Expression]` | Image -> per-zone annotated image, people count, occupied boolean |

## Privacy & Safety

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **blur-faces** | Anonymize faces for privacy compliance | `[Object Detection Model]` `[Blur Visualization]` `[Bounding Box Visualization]` | Image -> blurred image, bbox image (for review), predictions |
| **fire-detection** | Detect fire/smoke using fine-tuned + zero-shot models in parallel | `[Object Detection Model]` `[YOLO-World Model]` `[Bounding Box Visualization]` `[Label Visualization]` | Image -> two annotated images (fine-tuned vs zero-shot), both predictions |

## Data Collection

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **active-learning** | Run inference and auto-upload images + predictions to a dataset | `[Object Detection Model]` `[Bounding Box Visualization]` `[Label Visualization]` `[Roboflow Dataset Upload]` | Image + project URL -> upload confirmation, annotated image, predictions |

## Parallel Comparison

| Template | Use Case | Key Blocks | Input -> Output |
|----------|----------|------------|-----------------|
| **animal-detection** | Compare COCO model vs YOLO World zero-shot on configurable species list | `[Object Detection Model]` `[YOLO-World Model]` `[Bounding Box Visualization]` `[Label Visualization]` `[Property Definition]` | Image + species list + confidence -> per-model annotated images, counts, predictions |

## Block Index

All blocks referenced across templates:

| Block | Category | Used In |
|-------|----------|---------|
| `[Object Detection Model]` | model | Most templates |
| `[Instance Segmentation Model]` | model | bg-removal, branching, animal-classifier |
| `[Single-Label Classification Model]` | model | branching, animal-classifier, recognize-emotions |
| `[Segment Anything 2 Model]` | model | sam2 |
| `[YOLO-World Model]` | model | animal-detection, fire-detection, detect-and-count-fish |
| `[OpenAI]` | model | read-license-plates (OCR) |
| `[Bounding Box Visualization]` | visualization | Most templates |
| `[Label Visualization]` | visualization | Most templates |
| `[Polygon Visualization]` | visualization | sam2, branching, animal-classifier |
| `[Halo Visualization]` | visualization | sam2 |
| `[Blur Visualization]` | visualization | blur-faces |
| `[Background Color Visualization]` | visualization | bg-removal |
| `[Image Slicer]` | transformation | sahi, people-detection-sahi, vehicle-detection-sahi |
| `[Dynamic Crop]` | transformation | recognize-emotions, read-license-plates, rock-paper-scissors |
| `[Relative Static Crop]` | transformation | detect-backup, detect-people-in-target-zone |
| `[Detections Stitch]` | fusion | sahi, people-detection-sahi, vehicle-detection-sahi |
| `[Detections Transformation]` | transformation | rock-paper-scissors |
| `[Detections Filter]` | transformation | detect-backup |
| `[Detections Classes Replacement]` | formatter | recognize-emotions |
| `[Property Definition]` | formatter | Counting templates, recognize-emotions, rock-paper-scissors |
| `[Expression]` | formatter | detect-backup, detect-people-in-target-zone, rock-paper-scissors |
| `[Continue If]` | flow_control | branching, animal-classifier, read-license-plates, rock-paper-scissors |
| `[Roboflow Dataset Upload]` | sink | active-learning, read-license-plates |
