---
name: roboflow-model-journey
description: Use when a user wants a model that detects, segments, or classifies something without training first. Covers choosing the model, trying it, and putting it on a project's live endpoint (Project Deployment).
---

> **For agents:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills). If your client already has it loaded as a skill (for example from a Roboflow plugin), use that copy. The `skill://roboflow/<name>/SKILL.md` MCP resources serve the same skills for clients that don't have them loaded.

# Model journey: choose, try, deploy

Understand the outcome, choose a model, try it on the user's media, put it on the project's live endpoint when the task needs one, then improve or train. These rules are the Roboflow Agent's; follow them as written.

## 1. Choose the model

Choose the simplest prediction type that delivers the user's requested output, then apply its Model default. Make a concrete recommendation and proceed; ask only when a missing detail materially affects the choice.

- Check whether the workspace already has a relevant custom Model (`models_list`). Treat a Model the user has not named as a candidate, not an automatic default: its name or class list alone does not show that it fits the user's data. Evaluate a promising existing Model on representative input before choosing it. Reuse it directly when the user requested it, it is already established in the conversation, or representative results have validated it.
- Roboflow Instant previews are identified in workspace Model results. Use one only when the user explicitly asks for that Instant Model. Otherwise, prefer the appropriate foundation Model or a deliberately trained Model.
- When the user provides a model ID or explicitly requests a specific Model, accept it exactly as given. Do not invent model IDs.
- Explicit supported choices and existing saved models take precedence over the defaults below.

| Target | Model | Endpoint `model` |
|---|---|---|
| Object detection, [COCO classes](../roboflow-training-and-evaluation/model-ids.md#coco-80-classes-rf-detr-coverage) | RF-DETR | `{type: "model_id", modelId: "rfdetr-nano"}` |
| Instance segmentation, COCO classes | RF-DETR Segmentation | `{type: "model_id", modelId: "rfdetr-seg-nano"}` |
| Keypoints, COCO classes | YOLO26 Pose | `{type: "model_id", modelId: "yolo26n-pose-640"}` |
| Object detection, outside COCO | The Workspace detection default (section 2) | `{type: workspaceDetectionDefault.objectDetectionEndpoint.type, classes}` |
| Instance segmentation, outside COCO | SAM 3, after determining it's a good fit | `{type: "sam3", classes}` |
| Classification by description | Qwen 3.5 VL 2B | `{type: "qwen", classes}` |
| Keypoints, outside COCO | Custom keypoint labeling and YOLO26 Pose training | The trained model's `model_id` |

- **Sizes:** Nano is the cheapest and fastest starting point. Move to larger sizes when evaluation shows that the additional accuracy is worth the added cost and latency. RF-DETR and RF-DETR Segmentation come in `-nano`, `-small`, `-medium`, `-large`, `-xlarge` and `-2xlarge`. YOLO26 goes up to xlarge: `yolo26{n,s,m,l,x}-640`, and `yolo26{n,s,m,l,x}-pose-640` for keypoints.
- **YOLO26 detection:** only when CPU execution, genuinely low-power hardware, or strict cost constraints make it the better fit. It still runs through Roboflow Inference.
- **Boxes or outlines:** Sol, Astra and Gemini provide bounding-box object detection, not segmentation masks. Keep SAM 3 and RF-DETR Segmentation for segmentation. Start counting and localization with the detection default; use segmentation when the output requires contours or pixel areas, or tests show boxes can't meet the requirement. SAM 3's weaker language understanding often needs several text-prompt attempts.
- **Explicit choices:** honor Sol (`{type: "sol", classes}`), Astra (`{type: "astra", classes}`), SAM 3 (`{type: "sam3", classes}`) and Gemini 3.8 Flash (`{type: "gemini", classes}`) for the endpoint instead of substituting the default.
- **CLIP** (`{type: "clip", classes}`): only when the user explicitly requests CLIP or for an existing CLIP setup.
- **Universe models:** `universe_search` with `result_type: "model"` lists each result's `modelVersions`. Use the exact `model_id`, including a listed older version, as `{type: "model_id", modelId}`.
- **Auto Label is separate:** its model selection has its own defaults. Don't apply these endpoint defaults to a labeling-only task, and name an endpoint by its endpoint model, never by the Auto Label one.
- **Video:** Gemini, Sol, and Astra video processing runs frame by frame and can use credits quickly; confirm with the user before running them on video. For ongoing video, recommend sampling frames, labeling them, and training RF-DETR.
- Briefly name the Model and explain in plain language what kind of Model it is and why it fits the workload.

## 2. Workspace detection default and OpenAI availability

`project_deployment_get` (and `project_deployment_launch`) return `workspaceDetectionDefault` and `openAiDetectionAvailability`.

- `workspaceDetectionDefault.objectDetectionEndpoint` is the endpoint model for new non-COCO object detection with no explicit model choice: GPT-6.1 Sol on free and trial workspaces, GPT-6 Astra on paid workspaces or unknown usage. `workspaceDetectionDefault.objectDetection` (Gemini 4 Argon, `gemini-4-argon-boxes`) is the default for Workflow detection steps and catalog labeling.
- If `workspaceDetectionDefault` is absent, use the paid default: GPT-6 Astra. Never infer the tier from user messages.
- When `openAiDetectionAvailability` is `available` or absent, follow the workspace detection default.
- A `managed-key-denied` or `region-unavailable` restriction does not establish another provider's availability: retain a non-OpenAI default only when its own access and deployment policies permit it. When no permitted VLM default is available, use the native SAM 3 fallback without another selection question. Never switch providers, credentials or global routes to evade plan, workspace-key or residency restrictions.
- If the user explicitly requests Sol or Astra:
  - `managed-key-denied`: explain that its managed-key access is unavailable in this workspace and offer SAM 3 or resolving that access.
  - `region-unavailable`: explain that OpenAI detection is unavailable in the EU deployment and offer SAM 3. Don't suggest upgrading the plan or adding a provider key, and don't configure a new Sol or Astra endpoint.
  - For either restriction, don't configure a substitute without the user's agreement or claim the requested detector ran. Leave existing configured endpoints, COCO RF-DETR, other task defaults, and Auto Label's separate selection unchanged.

## 3. Try a model

Ordinary model testing needs no endpoint configuration. Never set an endpoint model just to try one.

- `models_infer`: a trained model id or pretrained alias on one image; returns JSON predictions.
- `autolabel_preview`: a foundation model from `autolabel_models_list` on one image of a project.

## 4. Put it on the endpoint

Configure this optional endpoint only when the requested task needs a stable serving endpoint or active learning. Each project has one stable endpoint; changing its model keeps the inference path.

- **New object-detection project outside COCO, no explicit model choice:** a new project's detection default can only be read once the project exists.
  1. Call `project_deployment_launch` without `model` or Active Learning.
  2. Read the returned `workspaceDetectionDefault` and `openAiDetectionAvailability` (section 2).
  3. Call `project_deployment_set_model` with `{type: workspaceDetectionDefault.objectDetectionEndpoint.type, classes}`, the classes to detect.
  4. Call `project_deployment_enable_active_learning` if wanted. Active Learning needs a model on the endpoint.
- **Any other new project:** `project_deployment_launch` with `model`, and `enable_active_learning` if wanted.
- **Existing project:** `project_deployment_set_model`. It saves the configuration, so don't describe it as temporary. Never replace a configured serving model or saved prompt unless the user explicitly requests that persistent change. Training completion, Auto Label setup, and trying a preview don't authorize replacement. Never use it for temporary classes or confidence changes. Active Learning settings are preserved.

## 5. Improve or train

If the results miss, look at them with the user first. For SAM 3, try a few simple descriptions of the target's appearance. When quality, latency or video cost needs a custom model, sample and label representative frames and train: default to RF-DETR for object detection, including non-COCO targets, and RF-DETR Segmentation for instance segmentation, unless the user explicitly chooses another supported architecture (see `roboflow-training-and-evaluation`).

Put a trained model on the endpoint only when the user explicitly asks for it; finishing a training doesn't authorize it. Then use `project_deployment_set_model` with `{type: "model_id", modelId}`.
