---
name: roboflow-api-reference
description: Reference for Roboflow REST API and Inference API — hosts (api.roboflow.com, serverless.roboflow.com, dedicated, localhost:9001), auth, and request/response formats.
when_to_use: Use when making raw REST or Inference API calls to Roboflow, debugging API authentication, selecting the right SDK or host, or building integrations without the Roboflow MCP server.
---

> **Tip:** If you're connected to the [Roboflow MCP server](https://github.com/roboflow/roboflow-mcp), prefer its tools (`projects_*`, `versions_*`, `models_*`, `workflows_*`, `images_*`, …) over raw REST calls — they handle auth, pagination, and typed responses for you. The REST patterns below stay relevant if you're not using MCP.

# Roboflow API Reference — Overview

## API Hosts

| Host | Base URL | Purpose |
|------|----------|---------|
| Platform API | `https://api.roboflow.com` | CRUD for projects, images, versions, training, upload |
| Serverless Inference | `https://serverless.roboflow.com` | Model inference + Workflow execution |
| Dedicated Deployment | `https://<name>.roboflow.cloud` | Private GPU inference (same API as serverless) |
| Self-hosted Inference | `http://localhost:9001` | Local inference server via `inference` package |

Use the `inference-sdk` Python package as the preferred client for all inference hosts. It handles auth, retries, and response parsing.

## Authentication

| Method | Where | Format |
|--------|-------|--------|
| Query parameter | All hosts | `?api_key=YOUR_KEY` |
| Request body | Platform API | `"api_key": "YOUR_KEY"` in JSON body |
| Header | Inference hosts | `Authorization: Bearer YOUR_KEY` (Python SDK handles this) |

API keys are workspace-scoped. Get yours from **Workspace Settings > API Keys** in the Roboflow dashboard.

## SDKs

| SDK | Install | Primary Use |
|-----|---------|-------------|
| Python (`inference-sdk`) | `pip install inference-sdk` | Inference via `InferenceHTTPClient` |
| Python (`roboflow`) | `pip install roboflow` | Upload, training, project management |
| JavaScript (`roboflow.js`) | Browser script tag | Real-time on-device web inference |
| iOS (Swift) | CocoaPods/SPM | On-device mobile inference |

### Python inference-sdk Quick Start

```python
from inference_sdk import InferenceHTTPClient

CLIENT = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",  # or dedicated URL, or localhost
    api_key="YOUR_KEY"
)
result = CLIENT.infer("image.jpg", model_id="your-project/1")
```

### Python roboflow SDK Quick Start

```python
import roboflow

rf = roboflow.Roboflow(api_key="YOUR_KEY")
project = rf.workspace("my-workspace").project("my-project")

# Upload
project.upload(image_path="image.jpg", split="train")

# Inference
model = project.version(1).model
result = model.predict("image.jpg", confidence=40).json()
```

## Host Selection Guide

| Task | Host to Use |
|------|-------------|
| Run model inference (new projects) | `serverless.roboflow.com` |
| Run Workflows | `serverless.roboflow.com` |
| Upload images | `api.roboflow.com` |
| Manage projects/versions | `api.roboflow.com` |
| Start training | `api.roboflow.com` |
| High-throughput / SLA inference | Dedicated deployment URL |
| Air-gapped / on-prem inference | Self-hosted `localhost:9001` |

## Rate Limits

- Serverless API: rate limits vary by plan
- File upload max: 20 MB

## Related Pages

- [inference.md](./inference.md) — inference URL patterns, request/response formats
- [rest-api.md](./rest-api.md) — platform REST API endpoints (CRUD, upload, training)
