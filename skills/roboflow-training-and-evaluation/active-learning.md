---
name: roboflow-active-learning
description: Production feedback loop — use the Project Model Workflow block with Active Learning to collect real-world inference images for review, annotation, retraining, and model improvement.
---

# Active Learning on Roboflow

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:training-and-evaluation`) over fetching `roboflow://skills/training-and-evaluation/active-learning` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

Active learning closes the gap between your training dataset and the real world. Run production inference through a Project Model block, collect useful images for review, annotate or correct them, retrain, and update the project's model without rebuilding the Workflow.

This is the right answer when a user asks how to:
- improve their model using end-user or production images
- add images from their running application to their dataset
- set up a feedback loop between deployment and retraining
- implement active learning, data flywheel, or continuous learning

## The Core Pattern

Use a **Project Model block** in the production Workflow and enable Active Learning for its project. The block runs the project's stable API and follows its default model unless explicitly pinned. Active Learning collects production inference images, with predictions as pre-annotations, into review queues.

```
Image Input
  → Project Model Block
    ├→ Predictions → [Other output blocks — visualization, Slack, etc.]
    └→ Project-level Active Learning collection
      → Review → annotate/correct → generate version → train → update project model
```

The Project Model block is managed by the Roboflow Workflow builder rather than exposed as a normal block manifest through `workflow_blocks_list`. Do not substitute a regular model block plus Dataset Upload just because Project Model is absent from that catalog.

Use a **Dataset Upload block** only when the user explicitly needs bespoke collection routing or a different target project that project-level Active Learning does not cover. For that exception, use `workflow_blocks_get_schema` with the manifest key from `workflow_blocks_list` instead of relying on hardcoded properties. Follow the Mode A or Mode B authoring flow in `roboflow://skills/inference/SKILL` to create and save the Workflow.

## Filtering What Gets Collected

Collecting every frame is rarely useful. Three common approaches:

**Low-confidence sampling** — collect predictions below a confidence threshold. These are the images most likely to help the model.

**Random sampling** — sample a configurable percentage of frames. Useful for capturing distribution shifts even on high-confidence predictions.

**Class-based filtering** — route images containing specific classes or failing specific conditions. Useful when certain classes are underperforming (see improvement playbook).

## Reviewing and Using Collected Images

1. **Review in Roboflow** — Images land in Active Learning review queues. Saved predictions appear as pre-annotations, so annotation is correction rather than drawing from scratch.
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

See `roboflow://skills/training-and-evaluation/improvement-playbook` for the full diagnostic decision tree.

## Common Mistakes

| Mistake | Better approach |
|---|---|
| Adding a standalone Dataset Upload block next to a regular model block | Use a Project Model block with project-level Active Learning; reserve Dataset Upload for bespoke routing |
| Collecting every frame | Configure Active Learning collection limits and filters |
| Collecting without predictions | Run through the Project Model block so predictions become pre-annotations |
| Adding production images without reviewing | Pre-annotations are not ground truth — always review before including in a new version |
