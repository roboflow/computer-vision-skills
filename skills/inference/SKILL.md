---
name: roboflow-inference
description: Deployment option comparison (serverless, dedicated, self-hosted, batch) and Workflow execution patterns. For raw API URL patterns, auth, and request/response formats, see roboflow-api-reference.
---

> **Tip:** If you're connected to the [Roboflow MCP server](https://mcp.roboflow.com), use its inference tools (`models_infer`, `workflow_specs_run`, `workflows_run`) directly — they cover the same operations as the HTTP endpoints below with auth handled. The HTTP patterns stay relevant if you're not using MCP.

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

## Local tooling: when MCP isn't enough

For most operations, prefer the Roboflow MCP tools above — they handle auth and need nothing installed locally. Reach for local Python packages only for the gaps: **integration scripts** (`inference-sdk`), **Batch Processing / Data Staging** (`inference-cli`), the **self-hosted server** (`inference-cli`), and asset scripts that need typed Python objects.

See [`local-tooling`](local-tooling.md) for what to install for which use case, the recommended `uv`-based env setup, conda / venv fallbacks, and common pitfalls.

## Response Shapes by Task

For canonical response shapes (object detection, classification, segmentation, keypoint) with all fields including `class_id`, `detection_id`, `class_confidence`, see `roboflow://skills/api-reference/inference`.

## Large Response Handling

**Instance segmentation `points` arrays are the main culprit for bloated responses.** Each detection includes a polygon with potentially hundreds of coordinate pairs. A single image with many detections can return megabytes of JSON.

Mitigation strategies:

1. **Use Workflows instead of direct inference** -- add a polygon simplification or property extraction block to reduce output before it reaches the client
2. **Filter classes** -- use `class_filter` to only return classes you need
3. **Raise confidence threshold** -- fewer detections = smaller response
4. **Post-process** -- if consuming raw responses, drop or simplify the `points` array when you only need bounding boxes
5. **Avoid returning raw segmentation results through LLM context** -- extract only the fields you need (class counts, bounding boxes) and discard polygon data

## Batch Processing

Runs a Workflow on large datasets (images or video) asynchronously with auto-provisioned infrastructure.

**Flow:** Upload data -> Select workflow -> Choose CPU/GPU -> Start job -> Poll or webhook -> Download JSON results

**When to use:** Processing stored data offline, no real-time requirement, cost-sensitive bulk inference.

**API flow (CLI):**
```bash
# Ingest images
inference rf-cloud data-staging create-batch-of-images \
  --images-dir ./my-images --batch-id my-batch

# Start processing
inference rf-cloud batch-processing process-images-with-workflow \
  --workflow-id my-workflow --batch-id my-batch

# Check progress
inference rf-cloud batch-processing show-job-details --job-id JOB_ID

# Export results
inference rf-cloud data-staging export-batch \
  --target-dir ./results --batch-id OUTPUT_BATCH_ID
```

Batch Processing also available via REST API and Roboflow web UI.
