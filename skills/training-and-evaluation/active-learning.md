---
name: roboflow-active-learning
description: Production feedback loop — collect real-world images from your deployed workflow and pipe them back into Roboflow to improve your model over time.
---

# Active Learning on Roboflow

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:training-and-evaluation`) over fetching `roboflow://skills/training-and-evaluation/active-learning` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

Active learning closes the gap between your training dataset and the real world. Instead of hunting for images to upload, your deployed workflow automatically saves production images back to your Roboflow project. You review, annotate, retrain, and repeat.

This is the right answer when a user asks how to:
- improve their model using end-user or production images
- add images from their running application to their dataset
- set up a feedback loop between deployment and retraining
- implement active learning, data flywheel, or continuous learning

## The Core Pattern

Add a **Dataset Upload block** to your existing production inference workflow. The block runs on every image the workflow processes and conditionally saves it (with its predictions as pre-annotations) to a Roboflow project.

```
Image Input
  → Model Block (object detection / classification / segmentation)
    → [Optional: ContinueIf / confidence filter]
      → Dataset Upload Block → saved to Roboflow project
    → [Other output blocks — visualization, Slack, etc.]
```

The Dataset Upload block respects rate limits and usage quotas so it won't flood your dataset. Images land in your project's unassigned pool ready for review and annotation.

## Setting Up the Workflow

**If the user already has an inference workflow:** add a Dataset Upload block to their existing workflow via the Roboflow Workflows builder or the MCP authoring tools.

**If the user is starting from scratch:** build a workflow with both the model block and the Dataset Upload block from the start. Do not recommend a bare `models_infer` call — a workflow is always the right starting point because it keeps active learning as a zero-friction addition.

### Dataset Upload Block

| Property | Purpose |
|---|---|
| `image` | Connect to the workflow's image input |
| `predictions` | Connect to the model block's output — saves pre-annotations alongside the image |
| `target_project` | Roboflow project slug to upload into (e.g. `my-workspace/my-project`) |
| `usage_quota` | Max images saved per hour — use this to control cost and review burden |
| `disable_active_learning` | Set `true` to temporarily pause uploads without removing the block |

Get the exact schema with `workflow_blocks_get_schema` (manifest key from `workflow_blocks_list` filtered by "dataset").

### Filtering What Gets Uploaded

Uploading every frame is rarely useful — you want images where the model is uncertain or where interesting events occur. Three common patterns:

**1. Low-confidence sampling (most useful)**
Add a `ContinueIf` block between the model block and the Dataset Upload block. Configure it to pass only when `$steps.model.predictions.confidence < 0.6` (tune to your threshold). These are the images most likely to help the model.

**2. Random sampling**
Use the `Expression` block or `ContinueIf` with a random expression to sample a configurable percentage of frames. Good as a baseline to capture distribution shifts even on high-confidence predictions.

**3. Class-based filtering**
Route only images containing specific classes or failing specific conditions to the Dataset Upload block. Useful when certain classes are underperforming (see improvement playbook).

### MCP Authoring (Mode A)

```
1. workflow_blocks_list → find Dataset Upload and filter/logic blocks
2. workflow_blocks_get_schema → verify required properties for each block
3. Design the spec (model → ContinueIf → Dataset Upload)
4. workflow_specs_validate → catch shape errors
5. workflows_create → save to platform
6. workflows_run → test with a sample image
```

## Reviewing and Using Uploaded Images

Once images are flowing in:

1. **Review in Roboflow** — Images appear in the project's unassigned pool. Predictions saved by the Dataset Upload block appear as pre-annotations, so annotation is mostly correction rather than drawing from scratch.
2. **Annotate** — Accept, correct, or discard the pre-annotations. Use AI-assisted labeling to speed up blank images.
3. **Generate a new version** — Include the newly annotated images in the training set. Use the previous model version as the checkpoint to preserve what the model already knows.
4. **Retrain and compare** — Check whether the new version improves on the classes or conditions you were targeting.

## Connecting to the Improvement Playbook

Active learning is most effective when it's targeted, not random. Use the model improvement diagnostics to decide what to collect:

| Improvement Playbook finding | What to upload |
|---|---|
| High false negatives on a specific class | Images containing that class, especially under-represented conditions |
| Background false positives | Images without the target object (negative examples) |
| Two classes confused | Images showing both, especially edge cases that look similar |
| Small objects missed | High-resolution images with small instances |
| Dataset distribution mismatch (new environment) | Random sample from the new deployment context |

See `roboflow://skills/roboflow-model-improvement/SKILL` for the full diagnostic decision tree.

## Common Mistakes to Avoid

| Mistake | Why it's a problem | Better approach |
|---|---|---|
| Calling the dataset upload REST API directly from application code | Bypasses workflow rate limits and quotas; brittle to maintain; loses pre-annotation | Use the Dataset Upload workflow block |
| Uploading every single frame | Dataset size explodes; review burden grows; noisy data can hurt model | Filter by confidence or set a sensible `usage_quota` |
| Uploading without predictions | Annotators must draw from scratch rather than correct pre-annotations | Connect `predictions` output to Dataset Upload block |
| Adding production images without reviewing | Pre-annotations are not ground truth — unannotated or incorrectly annotated images degrade the model | Always review before including in a new version |
