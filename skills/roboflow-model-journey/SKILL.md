---
name: roboflow-model-journey
description: Use when a user wants a model that detects, segments, or classifies something without training first, or wants to see a model or saved Workflow work on their own image or video. Covers choosing the model for a project's live endpoint (Project Deployment), setting it, and opening project_deployment_preview or workflows_preview.
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `skill://roboflow/<name>/SKILL.md` MCP resources serve the same skills for clients that don't have them loaded.

# Model journey: choose, deploy, preview

Understand the outcome, choose a model, put it on the project's live endpoint, show it on the user's own media, then improve or train. Each project has one stable endpoint (its Project Deployment); changing its model keeps the inference path.

## 1. Choose the model

Choose the simplest prediction type that gives the requested output, then apply its default below. Make a concrete recommendation and proceed; ask only when a missing detail changes the choice.

- Honor a supported model the user names, and the model the project already serves. Never replace a configured serving model or saved prompt unless the user asks for that change.
- An existing custom model the user didn't name is a candidate, not the default: preview it on representative media before choosing it.
- Explain the choice in a sentence: what kind of model it is and why it fits the target.

| Target | Endpoint model |
|---|---|
| Object detection, [COCO classes](../roboflow-training-and-evaluation/model-ids.md#coco-80-classes-rf-detr-coverage) | Pretrained RF-DETR: `{type: "model_id", modelId: "rfdetr-nano"}` |
| Instance segmentation, COCO classes | Pretrained RF-DETR Segmentation: `{type: "model_id", modelId: "rfdetr-seg-nano"}` |
| Keypoints, COCO classes | Pretrained YOLO26 Pose: `{type: "model_id", modelId: "yolo26n-pose-640"}` |
| Object detection, outside COCO | The workspace detection default (below) |
| Instance segmentation, outside COCO | SAM 3, `{type: "sam3", classes}`, when a test shows it finds the right objects |
| Classification by description | Qwen 3.5 VL 2B, `{type: "qwen", classes}` |
| Keypoints, outside COCO | No zero-shot endpoint: label keypoints and train YOLO26 Pose |

**Workspace detection default** for object detection outside COCO:

- Free and trial workspaces: GPT-6.1 Sol, `{type: "sol", classes}`.
- Paid workspaces, or when the plan is unknown: GPT-6 Astra, `{type: "astra", classes}`.
- When OpenAI detection is unavailable to the workspace (managed-key access denied, or the EU deployment): SAM 3, `{type: "sam3", classes}`. Never switch providers or credentials to get around it. If the user asked for Sol or Astra, explain why it's unavailable and offer SAM 3 instead of configuring it silently.

Don't infer the plan from the user's messages. Explicit supported choices win over the default: Sol, Astra, SAM 3, and Gemini 3.8 Flash (`{type: "gemini", classes}`).

More rules:

- Sizes: Nano is the cheapest and fastest start. Move to a larger size (`-small`, `-medium`, `-large`, `-xlarge`, `-2xlarge`) when evaluation shows the accuracy is worth the cost and latency.
- YOLO26 detection (`yolo26n-640` and up) only when CPU execution, low-power hardware, or strict cost makes it the better fit.
- Sol, Astra and Gemini return boxes, not masks. Use SAM 3 or RF-DETR Segmentation when the output needs outlines or pixel areas.
- For counting and locating, start with the detection default; SAM 3's strength is precise outlines once it recognizes the target, and it often needs a few simple appearance descriptions.
- CLIP (`{type: "clip", classes}`) only when the user asks for it or the project already uses it.

## 2. Put it on the endpoint

- New project: `project_deployment_launch` with `model`. For a zero-shot start, offer `enable_active_learning: true` so production images become reviewable data for training later.
- Existing project: `project_deployment_set_model`. It saves the change; it isn't a temporary test.
- Check an endpoint with `project_deployment_get`. A preview needs a model set on it.

## 3. Preview on the user's media

After choosing or deploying a model, offer to show it on the user's own image or video. For a saved Workflow, offer the Workflow preview. Both open an interactive player in the chat.

| | `project_deployment_preview` | `workflows_preview` |
|---|---|---|
| Shows | The project's endpoint model: detections with confidence and class filters | A saved Workflow's output images, values and JSON |
| Needs | `project_id` with a model set | `workflow_id` of a saved Workflow with exactly one image input |
| Media | `source_id` (image) or `video_id` (video) from the workspace | Same |
| Options | `classes` (SAM 3 projects only, for this preview; the endpoint keeps its saved prompt), `confidence` | `parameters` for the Workflow's other inputs, `disable_sinks` |
| Video | `trim_start_ms`, `trim_duration_ms`: a clip of 60 s at most | Same |

- **Media:** only images and videos already in the workspace. Find them with `images_workspace_search` (`media_types: ["video"]` for videos). The preview doesn't upload; if the user's file isn't in Roboflow yet, upload it first with their go-ahead (see `roboflow-data-management`).
- **Cost:** every call runs inference and spends credits. A video runs as a job on the clip. Sol, Astra and Gemini process video frame by frame and can use credits quickly: say so and get the user's go-ahead before a video preview with them.
- **Sinks:** a Workflow's sink blocks (webhooks, uploads, notifications) run unless `disable_sinks: true`. Ask when the Workflow has them.
- **Refusals:** the platform refuses a Workflow it can't preview (more than one image input, an unknown parameter, no image output for video) before running it. Relay the returned sentence.
- **What you get back:** counts per class, the output names, or the job id. The user sees the results in the player; don't describe detections you weren't given.

The player handles the rest. The user filters by confidence and class without a new run, runs the preview again, stops a video job with **Stop**, and on SAM 3 projects types other classes and runs again. The player calls `preview_rerun`, `preview_job_get`, `preview_job_cancel` and `preview_media_refresh` itself: never call them, and don't call the opening tool again to check a video's progress.

## 4. Improve or train

If the results miss, look at them with the user first. For SAM 3, try a few simple descriptions of the target's appearance. When quality, latency or video cost needs a custom model, sample and label representative frames and train: RF-DETR for detection (outside COCO too), RF-DETR Segmentation for instance segmentation (see `roboflow-training-and-evaluation`). Then set the trained model on the endpoint with `project_deployment_set_model` (`{type: "model_id", modelId}`) and preview it on the same media.
