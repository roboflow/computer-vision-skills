---
name: roboflow-labeling
description: Annotation tools, AI labeling features (Label Assist, Smart Polygon, Auto Label), annotation jobs, and labeling workflows in Roboflow.
---

# Labeling & Annotation on Roboflow

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:data-management`) over fetching `roboflow://skills/data-management/labeling` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

## Annotation Tools

| Tool | Shortcut | Use Case |
|------|----------|----------|
| Drag & Select | `D` | Select, move, resize existing annotations |
| Bounding Box | `B` | Draw rectangular annotations |
| Polygon | `P` | Draw multi-point polygon outlines |
| Brush (Mask) | `U` | Paint pixel-precise mask regions (add/subtract modes) |
| Smart Polygon | `S` | SAM-powered single-click segmentation (green=include, red=exclude) |
| Label Assist | Magic wand icon | Model-assisted auto-labeling per image |
| Mark Null | `N` | Mark image as background / clear all annotations |

### Annotation Type Compatibility

| Project Type | Supported Annotations |
|--------------|----------------------|
| Object Detection | BBox, Polygon*, Mask* |
| Instance Segmentation | Polygon, Mask |
| Semantic Segmentation | Polygon, Mask |
| Keypoint Detection | Keypoints (skeleton) |
| Classification | Image-level labels only |

_*Polygons/masks auto-converted to bounding boxes for object detection._

### Multi-Select & Context Menu

Hold `Shift` + click or drag-select multiple annotations. Right-click for bulk actions:

| Action | Description |
|--------|-------------|
| Convert to Box / Polygon / Mask / Smart Mask | Change annotation type |
| Merge Masks | Combine selected masks into one (all must be masks) |
| Bring to Front / Send to Back | Reorder annotation layering |

### Other Controls

- **Undo / Redo** — standard undo/redo while in B, P, or S mode
- **Repeat Previous** — reapply last annotations in same positions
- **Zoom** — bottom-left zoom tool, supports zoom lock
- **Class Selector** — appears on annotation; type to filter/create classes

## AI Labeling Features

All AI labeling features consume credits. See `roboflow.com/credits` for rates.

| Feature | Trigger | What It Does | Best For |
|---------|---------|--------------|----------|
| **Label Assist** | Magic wand in annotator | Runs a trained model (yours or public) on each image as you navigate | Labeling after you have a trained model |
| **Smart Polygon (SAM)** | `S` -> "Enhanced" | Segment Anything runs in-browser; hover for mask preview, click to apply | First dataset version, segmentation tasks |
| **Box Prompting** | Box Prompting tool in toolbar | Draw 1+ example boxes, model finds similar objects in image | Many identical objects per image (screws, cells) |
| **Auto Label** | Upload -> "Auto Label" | Foundation model (Grounding DINO / Grounded SAM / CLIP) labels entire batch | Common objects in bulk (vehicles, people, cans) |

### Label Assist Details

1. Open image in annotator -> click magic wand
2. Select model: "Your Models" tab or "Public Models" tab (star on Universe first)
3. Configure class mapping (remap model classes to project classes)
4. Predictions appear as you navigate images

### Smart Polygon (SAM) Details

1. Enable Smart Polygon (`S`) -> select "Enhanced"
2. Hover to preview mask, click to create
3. Refine: click outside mask to expand, inside to shrink
4. Toggle polygon complexity: Convex Hull / Smooth / Complex
5. Press `Enter` to accept

### Box Prompting Details

1. Draw at least one bbox example per class
2. Activate Box Prompting tool
3. Predictions appear as dotted lines; adjust confidence slider
4. Right-click false positives -> "Convert to Negative"
5. Click "Approve Predictions" to save
6. Model improves as you annotate more images in the session

**Limitation:** Best with images under 1000px; degrades on 2000px+ with small objects.

### Auto Label Details

1. Upload images -> select "Auto Label"
2. Define classes + optional text descriptions
3. "Generate Test Results" on 4-image subset (free, no credits)
4. Adjust confidence per class
5. "Auto Label with This Model" to run on full batch

Models used: Grounding DINO (detection), Grounded SAM (segmentation), CLIP (classification), or your own Roboflow-trained model.

## Annotation Workflow

```
Upload -> Batch (Unassigned) -> Assign Job -> Annotating -> Review -> Dataset
                                                  ^                    |
                                                  |--- Rejected -------|
```

### Batches

Each upload creates a batch. Batches track images through the pipeline.

| Column | Status |
|--------|--------|
| Unassigned | Uploaded, not yet assigned |
| Annotating | Assigned to labeler, in progress |
| Review | Submitted for review (paid plans) |
| Dataset | Approved and ready for version generation |

Batches can only be deleted from Unassigned. Move back first if needed.

### Jobs & Assignment

- Assign a batch (or subset) to one or more team members
- Unassigned images in a partially-assigned batch split into a new batch
- Add labeling instructions before assigning ("Add Instructions" -> "Edit")
- Labelers receive notifications when assigned

### Review Mode

Reviewer sees images in Approved / Rejected / To Do tabs:
- **Approve** — image moves to Dataset
- **Reject** — image returns to Annotating for rework

### Collaboration Features

| Feature | Description |
|---------|-------------|
| Job assignment | Divide work across team members |
| Labeling instructions | Per-batch guidance for labelers |
| Jobs board | At-a-glance view of all jobs and progress |
| Job details | Per-job image list, reassignment |
| Comments | Add comments to images, view history |
| Revert changes | Undo annotation edits |
| Notifications | Alerts when work is assigned |

## Annotation Groups

Projects sharing the same annotation group share classes and annotations. Useful for:
- Multiple detection tasks on the same images (e.g., "chess pieces" vs "board games")
- Shared images counted once toward usage
- Editing annotations in one project affects all linked projects

Enable at project creation: "Share image annotations with other projects". Look for the chain-link icon on shared images/projects.

## MCP Tools Available

| Tool | Purpose |
|------|---------|
| `annotations_save` | Save annotations (bboxes, polygons, classifications) to a project image |
| `annotation_batches_list` | List all batches in a project |
| `annotation_batches_get` | Get details of a specific batch |
| `annotation_jobs_create` | Create a labeling job (assign batch to team members) |
