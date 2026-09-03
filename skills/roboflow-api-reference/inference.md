# Roboflow Inference API Reference

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:api-reference`) over fetching `roboflow://skills/api-reference/inference` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

> **Tip:** If you're connected to the [Roboflow MCP server](https://mcp.roboflow.com), prefer `models_infer` (single-model) or `workflow_specs_run` / `workflows_run` (chained pipelines with annotated images) over raw HTTP calls — same operations, but auth is handled and responses are typed. The REST patterns below stay relevant if you're not using MCP.

## Serverless Inference (Hosted API v2)

Single endpoint for all model types and Workflows. V2 is credit-billed by execution time (seconds); the older v1 hosted API was billed per inference count — v2 is the current default for all new projects.

```
POST https://serverless.roboflow.com/{dataset_id}/{version_id}
POST https://serverless.roboflow.com/{workspace_name}/workflows/{workflow_id}
```

## Inference SDK (Recommended Client)

The `inference-sdk` Python package is the preferred way to call Roboflow models. It handles auth, retries, and response parsing.

```bash
pip install inference-sdk
```

```python
from inference_sdk import InferenceHTTPClient

client = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key="YOUR_KEY"
)
result = client.infer("image.jpg", model_id="my-project/1")
```

Works with local files, URLs, numpy arrays, and PIL images. Points at serverless by default; change `api_url` for dedicated deployments or local inference server.

## Dedicated Deployments

Same API as serverless, but at your deployment URL:
```
POST https://<deployment-name>.roboflow.cloud/{projectId}/{versionNumber}
```

## Request Format

### Image Input (choose one)

| Method | How |
|--------|-----|
| Base64 POST body | Set `Content-Type: application/x-www-form-urlencoded`, body = base64 string |
| Image URL param | `?image=https%3A%2F%2F...` (URL-encoded) |

### Query Parameters

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `api_key` | string | required | Workspace API key |
| `confidence` | number | 40 | Prediction threshold (0-100). Lower = more predictions |
| `overlap` | number | 30 | Max overlap % before NMS merges boxes (0-100) |
| `classes` | string | all | Comma-separated class filter (e.g. `dog,cat`) |
| `format` | string | `json` | `json`, `image`, or `image_and_json` |
| `labels` | boolean | false | Show text labels (only when `format=image`) |
| `stroke` | number | 1 | Bounding box stroke width in px (only when `format=image`) |
| `image` | string | — | URL of hosted image (alternative to base64 body) |

### Visualization

The recommended approach for visualization is **Workflows** — use `workflow_specs_run` with a visualization block (Bounding Box, Label, Mask, etc.). This gives you full control over rendering and works reliably across all model types. See `roboflow://skills/inference/workflows`.

## Response Shapes

### Object Detection

```json
{
  "predictions": [
    {
      "x": 189.5, "y": 100,
      "width": 163, "height": 186,
      "class": "helmet",
      "class_id": 0,
      "confidence": 0.544,
      "class_confidence": 0.544,
      "detection_id": "uuid"
    }
  ],
  "image": { "width": 2048, "height": 1371 }
}
```

`(x, y)` = center of bounding box. Corner points: `x1 = x - width/2`, `y1 = y - height/2`.

### Classification (Single-Label)

```json
{
  "predictions": [
    { "class": "real-image", "confidence": 0.7149 },
    { "class": "illustration", "confidence": 0.2851 }
  ],
  "top": "real-image",
  "confidence": 0.7149,
  "image": { "width": 210, "height": 113 },
  "prediction_type": "ClassificationModel"
}
```

### Classification (Multi-Label)

```json
{
  "predictions": {
    "dent": { "confidence": 0.5253 },
    "severe": { "confidence": 0.5804 }
  },
  "predicted_classes": ["dent", "severe"],
  "prediction_type": "ClassificationModel"
}
```

### Instance Segmentation

Same as object detection, plus a `points` array per prediction:

```json
{
  "predictions": [
    {
      "x": 179.2, "y": 247,
      "width": 231, "height": 147,
      "class": "A", "confidence": 0.98,
      "points": [
        { "x": 134, "y": 314 },
        { "x": 116, "y": 313 }
      ]
    }
  ]
}
```

### Keypoint Detection

Same as object detection, plus a `keypoints` array per prediction:

```json
{
  "predictions": [
    {
      "x": 189.5, "y": 100,
      "width": 163, "height": 186,
      "class": "helmet", "confidence": 0.544,
      "keypoints": [
        { "x": 189, "y": 20, "class": "top", "class_name": "top", "class_id": 0, "confidence": 0.91 },
        { "x": 188, "y": 180, "class": "bottom", "class_name": "bottom", "class_id": 1, "confidence": 0.93 }
      ]
    }
  ],
  "image": { "width": 2048, "height": 1371 }
}
```

## Code Examples

### Python (inference-sdk) — Recommended

```python
from inference_sdk import InferenceHTTPClient

client = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key="YOUR_KEY"
)

# Local image
result = client.infer("image.jpg", model_id="my-project/1")

# URL image
result = client.infer("https://example.com/photo.jpg", model_id="my-project/1")
```

### curl — Base64

```bash
base64 image.jpg | curl -d @- \
  "https://serverless.roboflow.com/my-project/1?api_key=YOUR_KEY&confidence=50"
```

### curl — Image URL

```bash
curl -X POST "https://serverless.roboflow.com/my-project/1?\
api_key=YOUR_KEY&image=https%3A%2F%2Fexample.com%2Fphoto.jpg"
```

### Workflow Inference

```bash
curl -X POST "https://serverless.roboflow.com/my-workspace/workflows/my-workflow" \
  -H "Content-Type: application/json" \
  -d '{"api_key": "YOUR_KEY", "inputs": {"image": {"type": "url", "value": "https://example.com/photo.jpg"}}}'
```

## Error Responses

| Status | Meaning |
|--------|---------|
| 403 | Invalid or unauthorized `api_key` |
| 404 | Model/version not found |
| 413 | Image too large (max 20 MB) |
