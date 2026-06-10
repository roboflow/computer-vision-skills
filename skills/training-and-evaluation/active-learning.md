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

Add a **Dataset Upload block** to your existing production inference workflow. The block conditionally saves images — with predictions as pre-annotations — to a Roboflow project.

```
Image Input
  → Model Block (object detection / classification / segmentation)
    → [Optional: ContinueIf / confidence filter]
      → Dataset Upload Block → saved to Roboflow project
    → [Other output blocks — visualization, Slack, etc.]
```

If the user is starting a new integration without an existing workflow, this is a natural reason to set one up — the Dataset Upload block drops in as a zero-friction addition when a workflow is already in place.

Use `workflow_blocks_get_schema` (with the manifest key from `workflow_blocks_list`) to get the current block schema; block properties can change so look them up rather than relying on hardcoded names. Follow the Mode A or Mode B authoring flow in `roboflow://skills/inference/SKILL` to create and save the workflow.

## Filtering What Gets Uploaded

Uploading every frame is rarely useful. Three common approaches:

**Low-confidence sampling** — gate the Dataset Upload block with a `ContinueIf` block set to pass only predictions below a confidence threshold. These are the images most likely to help the model.

**Random sampling** — use `ContinueIf` or `Expression` to sample a configurable percentage of frames. Useful for capturing distribution shifts even on high-confidence predictions.

**Class-based filtering** — route images containing specific classes or failing specific conditions. Useful when certain classes are underperforming (see improvement playbook).

## Reviewing and Using Uploaded Images

1. **Review in Roboflow** — Images land in the project's unassigned pool. Saved predictions appear as pre-annotations, so annotation is correction rather than drawing from scratch.
2. **Annotate** — Accept, correct, or discard pre-annotations. Use AI-assisted labeling for blank images.
3. **Generate a new version and retrain** — Use the previous model as the checkpoint to preserve what it already knows.

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

## Common Mistakes

| Mistake | Better approach |
|---|---|
| Calling the dataset upload REST API directly from application code | Use the Dataset Upload workflow block — it handles rate limits, quotas, and pre-annotations automatically |
| Uploading every frame | Filter by confidence or configure the block's usage quota |
| Uploading without connecting predictions | Pre-annotations make annotation correction rather than drawing from scratch — connect the model output to the block |
| Adding production images without reviewing | Pre-annotations are not ground truth — always review before including in a new version |
