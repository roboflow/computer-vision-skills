# Roboflow Platform REST API Reference

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:api-reference`) over fetching `roboflow://skills/api-reference/rest-api` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

> **Tip:** If you're connected to the [Roboflow MCP server](https://mcp.roboflow.com), prefer its tools (`projects_*`, `versions_*`, `images_*`, `annotations_save`, `models_train`, …) over raw REST calls — they handle auth and typed responses for you. The REST patterns below stay relevant if you're not using MCP.

Base URL: `https://api.roboflow.com`

All endpoints require `?api_key=YOUR_KEY` as a query parameter.

API keys are not available programmatically. Users can find theirs at **Workspace Settings > API Keys** in the Roboflow dashboard (`app.roboflow.com/{workspace}/settings/api`).

## Projects

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/{workspace}` | List all projects in workspace |
| GET | `/{workspace}/{project}` | Get project details |
| POST | `/{workspace}/projects` | Create a new project |

### Create Project

```bash
curl -X POST "https://api.roboflow.com/my-workspace/projects?api_key=KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "My Project", "type": "object-detection", "annotation": "my-annotation-group"}'
```

Required body fields: `name`, `type`, `annotation` (annotation group identifier).

Project types: `object-detection`, `single-label-classification`, `multi-label-classification`, `instance-segmentation`, `semantic-segmentation`

## Image Upload

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/{workspace}/{project}/upload` | Upload image to project |

### Upload via Image URL

```bash
curl -X POST "https://api.roboflow.com/my-workspace/my-project/upload?\
api_key=KEY&\
name=photo.jpg&\
split=train&\
image=https%3A%2F%2Fexample.com%2Fphoto.jpg"
```

### Upload via File (multipart)

```bash
curl -X POST "https://api.roboflow.com/my-workspace/my-project/upload?api_key=KEY" \
  -F "name=image.jpg" \
  -F "split=train" \
  -F "file=@image.jpg" \
  -F 'metadata={"camera_id":"cam001","temperature":72.5}'
```

### Upload Parameters

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `api_key` | string | yes | Workspace API key |
| `name` | string | no | Filename |
| `split` | string | no | `train`, `valid`, or `test` (default: `train`) |
| `image` | string | no | URL-encoded image URL (alternative to file upload) |
| `batch` | string | no | Custom batch name |
| `tag` | string | no | Tag(s) to apply (repeat param for multiple) |
| `metadata` | string | no | JSON-stringified key-value metadata |

### Upload via Python SDK

```python
import roboflow

rf = roboflow.Roboflow(api_key="KEY")
project = rf.workspace("my-workspace").project("my-project")

project.upload(
    image_path="image.jpg",
    split="train",
    metadata={"camera_id": "cam001", "temperature": 72.5}
)
```

Image limits: max 20 MB, max 16400x10900 px. Duplicate images are skipped.

## Versions

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/{workspace}/{project}/{version}` | Get version details |
| POST | `/{workspace}/{project}/generate` | Generate a new dataset version |

### Generate Version

Creates a new version with preprocessing and augmentation applied.

```bash
curl -X POST "https://api.roboflow.com/my-workspace/my-project/generate?api_key=KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "preprocessing": { "auto-orient": true, "resize": { "width": 640, "height": 640 } },
    "augmentation": { "flip": { "horizontal": true } }
  }'
```

## Training

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/{workspace}/{project}/{version}/train` | Start training on a version |

### Start Training

```bash
curl -X POST "https://api.roboflow.com/my-workspace/my-project/1/train?api_key=KEY"
```

Training status is included in the version GET response (`GET /{workspace}/{project}/{version}`) under the `version.train` field. There is no separate training-status endpoint.

## Models

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/{workspace}/{project}/{version}` | Get model/version info (includes metrics if trained) |
| GET | `/{workspace}/{project}/models` | List models for a project |
| GET | `/models/{workspace}/{project}/{version}` | Get model by workspace/project/version |

The version response includes model performance metrics (`map`, `precision`, `recall`) when a trained model exists.

## Workflows

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/{workspace}/workflows` | List workflows in workspace |
| GET | `/{workspace}/workflows/{workflowUrl}` | Get a specific workflow |
| POST | `/{workspace}/createWorkflow` | Create a new workflow |
| POST | `/{workspace}/updateWorkflow` | Update a workflow |

## Common Patterns

### Full Pipeline: Upload, Version, Train

```python
import roboflow

rf = roboflow.Roboflow(api_key="KEY")
project = rf.workspace("ws").project("proj")

# 1. Upload images
project.upload(image_path="img1.jpg", split="train")

# 2. Generate version
version = project.generate_version(
    preprocessing={"auto-orient": True, "resize": {"width": 640, "height": 640}},
    augmentation={"flip": {"horizontal": True}}
)

# 3. Train
version.train()
```

### CLI Upload (bulk)

```bash
pip install roboflow
roboflow import -w my-workspace -p my-project /path/to/images/
```

## Error Responses

| Status | Meaning |
|--------|---------|
| 401 | Missing or invalid `api_key` |
| 403 | Not authorized for this resource |
| 404 | Project/version not found |
| 409 | Duplicate image (skipped) |
| 413 | Image exceeds size limits |
| 422 | Validation error (missing/invalid required fields) |
| 423 | Folder usage paused |
