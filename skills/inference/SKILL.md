---
name: roboflow-inference
description: Use when running Roboflow model inference or choosing deployment (serverless, dedicated, self-hosted, batch); prefer Workflows over direct model calls.
---

> **Tip:** If you're connected to the [Roboflow MCP server](https://github.com/roboflow/roboflow-mcp), use its inference tools (`models_infer`, `workflow_specs_run`, `workflows_run`) directly — they cover the same operations as the HTTP endpoints below with auth handled. The HTTP patterns stay relevant if you're not using MCP.

# Inference & Deployment

> **Prefer Workflows over direct model inference.** Workflows let you chain model + visualization + logic blocks in one call via `workflow_specs_run`. Direct `models_infer` returns JSON only — no annotated images, and instance segmentation responses can be very large. See `roboflow://skills/inference/workflows` and `roboflow://skills/inference/workflow-templates`.

## Deployment Options

| Option | Best For | Latency | Scaling | Cost Model | GPU |
|--------|----------|---------|---------|------------|-----|
| **Serverless** | Getting started, variable traffic | Low | Auto | Per-inference credit | Yes |
| **Dedicated** | Predictable workloads, low latency | Very low | Manual/autoscale | Per-hour credits | Optional |
| **Self-hosted** | Full control, edge, air-gapped | Hardware-dependent | Manual | Your infra cost | Optional |
| **Batch Processing** | Large offline datasets, videos | Async (minutes-hours) | Auto-provisioned | Per-job | Optional |

### When to Use Which

- **Serverless** -- default choice. Zero setup, auto-scales, 20MB upload limit. Use `models_infer` or `workflows_run` MCP tools.
- **Dedicated** -- need consistent latency, large models (Florence 2), or high throughput. Development and production tiers available. Subdomain: `<name>.roboflow.cloud`.
- **Self-hosted** -- deploy Roboflow Inference via Docker on your own hardware (Jetson, cloud VMs, RPi). Same API surface as serverless -- just change `api_url`.
- **Batch Processing** -- runs a Workflow on uploaded images/videos asynchronously. No real-time requirement. Results delivered as JSON.

## MCP Tools for Inference

| Tool | Purpose |
|------|---------|
| `models_list` | List trained models for a project |
| `models_get` | Get details for a trained model |
| `models_infer` | Run single-model inference on one image via serverless API |
| `models_train` | Start training a model on a dataset version |
| `models_get_training_status` | Check training progress and metrics |
| `workflows_run` | Run a saved workflow on images |
| `workflow_specs_run` | Run an inline workflow definition (no save needed) |

## Response Shapes by Task

### Object Detection

```json
{
  "predictions": [
    {
      "x": 320.5, "y": 240.0,
      "width": 100, "height": 80,
      "confidence": 0.92,
      "class": "car",
      "class_confidence": 0.92,
      "class_id": 0,
      "detection_id": "uuid"
    }
  ],
  "image": { "width": 640, "height": 480 }
}
```

`x`, `y` = center of bounding box. `width`, `height` = box dimensions.

### Classification

```json
{
  "predictions": [
    { "class": "cat", "class_id": 0, "confidence": 0.95 },
    { "class": "dog", "class_id": 1, "confidence": 0.05 }
  ],
  "top": "cat",
  "confidence": 0.95
}
```

### Instance Segmentation

```json
{
  "predictions": [
    {
      "x": 320.5, "y": 240.0,
      "width": 100, "height": 80,
      "confidence": 0.88,
      "class": "person",
      "class_confidence": 0.88,
      "class_id": 0,
      "detection_id": "uuid",
      "points": [
        { "x": 280.0, "y": 200.0 },
        { "x": 285.0, "y": 202.0 }
      ]
    }
  ]
}
```

### Keypoint Detection

```json
{
  "predictions": [
    {
      "x": 320.5, "y": 240.0,
      "width": 100, "height": 200,
      "confidence": 0.91,
      "class": "person",
      "keypoints": [
        { "x": 330.0, "y": 210.0, "confidence": 0.95, "class_id": 0, "class": "nose" }
      ]
    }
  ]
}
```

## Large Response Handling

**Instance segmentation `points` arrays are the main culprit for bloated responses.** Each detection includes a polygon with potentially hundreds of coordinate pairs. A single image with many detections can return megabytes of JSON.

Mitigation strategies:

1. **Use Workflows instead of direct inference** -- add a polygon simplification or property extraction block to reduce output before it reaches the client
2. **Filter classes** -- use `class_filter` to only return classes you need
3. **Raise confidence threshold** -- fewer detections = smaller response
4. **Post-process** -- if consuming raw responses, drop or simplify the `points` array when you only need bounding boxes
5. **Avoid returning raw segmentation results through LLM context** -- extract only the fields you need (class counts, bounding boxes) and discard polygon data

## Batch Processing

**What it is.** A Roboflow-managed cloud service that runs a Workflow over a batch of images or videos asynchronously, provisioning the infrastructure for you. *"Ideal for asynchronously processing large amounts of data."* — [Roboflow docs](https://docs.roboflow.com/deploy/batch-processing).

**Problem it solves.** Bulk inference over thousands to millions of files without standing up your own GPUs, queues, or autoscaler. You hand Roboflow a Workflow plus a batch of inputs, pay per job, and get JSON results back when the job finishes.

**Pick it when** the data is stored (not live), per-file cost matters more than per-file latency, and minutes-to-hours per job is acceptable. **Pick something else when** you need real-time per-request results (use Serverless or Dedicated) or air-gapped/on-prem processing (use Self-hosted).

Surfaces: Roboflow web UI, `inference rf-cloud` CLI, and REST API.

### Flow

1. Have a saved Workflow in your workspace.
2. Stage inputs as a Data Staging batch (local directory, JSONL of signed URLs, or cloud-storage path on S3 / GCS / Azure).
3. Submit a job referencing the Workflow + input batch; choose CPU or GPU.
4. Monitor — poll job status or register a webhook.
5. Export the output batch as JSON.

### CLI

The `inference rf-cloud` CLI exposes two subcommand groups: `data-staging` (manage input/output batches) and `batch-processing` (submit and monitor jobs). Run any command with `--help` for the full option list.

**Minimal end-to-end:**

```bash
# Stage images
inference rf-cloud data-staging create-batch-of-images \
  --images-dir ./my-images --batch-id my-batch

# Submit
inference rf-cloud batch-processing process-images-with-workflow \
  --workflow-id my-workflow --batch-id my-batch
# -> prints JOB_ID

# Monitor
inference rf-cloud batch-processing show-job-details --job-id JOB_ID

# Export results
inference rf-cloud data-staging export-batch \
  --target-dir ./results --batch-id OUTPUT_BATCH_ID
```

**Data Staging commands** — see [`batch-staging`](batch-staging.md) for nuances (data sources, JSONL reference format, multipart batches, webhook notifications):

| Command | Purpose |
|---|---|
| `data-staging list-batches` | List staging batches in the workspace |
| `data-staging create-batch-of-images` | Create an input batch from a local directory, signed-URL JSONL, or cloud-storage path |
| `data-staging create-batch-of-videos` | Same as above, but for video files |
| `data-staging show-batch-details` | Show metadata for a single batch |
| `data-staging list-batch-content` | List file URLs in a batch (filter by part, write JSONL) |
| `data-staging list-ingest-details` | Per-shard ingest status for debugging URL ingests |
| `data-staging export-batch` | Download all files from a batch (e.g. job outputs) to a local directory |

**Batch Processing (job) commands** — see [`batch-jobs`](batch-jobs.md) for nuances (compute configuration, workflow parameters, image-output persistence, aggregation format, video FPS, restarts, TRT compilation):

| Command | Purpose |
|---|---|
| `batch-processing list-jobs` | List jobs in the workspace |
| `batch-processing show-job-details` | Show stages and current status of a single job |
| `batch-processing process-images-with-workflow` | Submit an image-batch job |
| `batch-processing process-videos-with-workflow` | Submit a video-batch job |
| `batch-processing fetch-logs` | Fetch job logs (filter by severity, write JSONL) |
| `batch-processing abort-job` | Terminate a running job |
| `batch-processing restart-job` | Restart a failed job (optionally with new compute settings) |
| `batch-processing trt-compile` | Compile a model to TensorRT for one or more NVIDIA devices |

### Notes and constraints

- **Async only** — minutes-to-hours latency depending on volume and hardware. Not for real-time.
- **Pricing** — per job; GPU jobs cost more than CPU. See [`plans-and-pricing`](../plans-and-pricing/SKILL.md).
- **Image-references ingest** requires signed URLs from trusted sources; arbitrary public URLs are rejected — stage to a local directory or cloud-storage path instead.

Full reference: [Roboflow Batch Processing docs](https://docs.roboflow.com/deploy/batch-processing).
