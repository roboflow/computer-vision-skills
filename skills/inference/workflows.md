# Workflows

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:inference`) over fetching `roboflow://skills/inference/workflows` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

> **Tip:** If you're connected to the [Roboflow MCP server](https://mcp.roboflow.com), use `workflow_specs_run` (run a spec ad-hoc) or `workflows_run` (run a saved workflow) instead of raw HTTP — they return annotated images alongside JSON. The HTTP patterns stay relevant if you're not using MCP.

## What Are Workflows

Composable, multi-step computer vision pipelines built in a visual editor. Chain models, logic, visualization, and integrations into a single deployable unit.

**Why Workflows over direct inference:**
- Chain multiple models (detect -> crop -> classify)
- Add post-processing (counting, filtering, tracking)
- Visualize results (bounding boxes, labels, masks)
- Integrate external services (notifications, storage)
- Single deploy for the entire pipeline

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Block** | A processing step -- model, logic, visualization, or integration |
| **Input** | Entry point (image/params). Every workflow needs at least one image input |
| **Output** | Data returned -- predictions, visualized images, computed values |
| **Connection** | Implicit via selector strings: `$steps.step_name.output_name` |
| **Branch** | Parallel paths that execute independently |

## Block Reference

Use `workflow_blocks_list` to get the live catalog. Use `workflow_blocks_get_schema` for full property details. Below are the ~30 most common blocks grouped by category.

### Models

| Block | Manifest Type | What it does |
|-------|--------------|--------------|
| Object Detection | `roboflow_core/roboflow_object_detection_model@v2` | Run trained detection model. Inputs: `images`, `model_id` |
| Instance Segmentation | `roboflow_core/roboflow_instance_segmentation_model@v2` | Detect + pixel masks. Inputs: `images`, `model_id` |
| Classification | `roboflow_core/roboflow_classification_model@v2` | Single-label classify. Inputs: `images`, `model_id` |
| Multi-Label Classification | `roboflow_core/roboflow_multi_label_classification_model@v1` | Multi-label classify. Inputs: `images`, `model_id` |
| Keypoint Detection | `roboflow_core/roboflow_keypoint_detection_model@v2` | Detect keypoints/poses. Inputs: `images`, `model_id` |
| SAM3 | `roboflow_core/sam3@v3` | Segment Anything 3. Set `model_id: "sam3/sam3_final"`, `class_names` |
| Florence 2 | `roboflow_core/florence_2@v1` | Multi-task VLM (caption, detect, OCR). Inputs: `images`, `model_id` |
| OCR | `roboflow_core/ocr_model@v1` | Extract text from images. Inputs: `images` |
| YOLO World | `roboflow_core/yolo_world_model@v1` | Open-vocab detection. Inputs: `images`, `class_list` |

### Visualization

| Block | Manifest Type | What it does |
|-------|--------------|--------------|
| Bounding Box | `roboflow_core/bounding_box_visualization@v1` | Draw boxes on detections. Inputs: `image`, `predictions` |
| Label | `roboflow_core/label_visualization@v1` | Draw text labels on detections. Inputs: `image`, `predictions` |
| Mask | `roboflow_core/mask_visualization@v1` | Overlay segmentation masks. Inputs: `image`, `predictions` |
| Polygon | `roboflow_core/polygon_visualization@v1` | Draw polygon outlines. Inputs: `image`, `predictions` |
| Halo | `roboflow_core/halo_visualization@v1` | Glow effect around detections. Inputs: `image`, `predictions` |
| Corner | `roboflow_core/corner_visualization@v1` | Corner markers on boxes. Inputs: `image`, `predictions` |
| Blur | `roboflow_core/blur_visualization@v1` | Blur detected regions. Inputs: `image`, `predictions` |
| Pixelate | `roboflow_core/pixelate_visualization@v1` | Pixelate detected regions. Inputs: `image`, `predictions` |

### Transformation

| Block | Manifest Type | What it does |
|-------|--------------|--------------|
| Dynamic Crop | `roboflow_core/dynamic_crop@v1` | Crop image to each detection. Inputs: `image`, `predictions` |
| Absolute Static Crop | `roboflow_core/absolute_static_crop@v1` | Crop fixed region. Inputs: `image`, coordinates |
| Perspective Correction | `roboflow_core/perspective_correction@v1` | Warp to bird's-eye view. Inputs: `image`, `predictions` |
| Detections Filter | `roboflow_core/detections_filter@v1` | Filter detections by class/confidence/area. Inputs: `predictions` |
| Detection Offset | `roboflow_core/detection_offset@v1` | Shift/resize detection boxes. Inputs: `predictions` |

### Analytics (Video)

| Block | Manifest Type | What it does |
|-------|--------------|--------------|
| Byte Tracker | `roboflow_core/byte_tracker@v3` | Track objects across frames. Inputs: `detections` |
| Line Counter | `roboflow_core/line_counter@v2` | Count objects crossing a line. Inputs: `tracked_detections`, `line` |
| Time in Zone | `roboflow_core/time_in_zone@v1` | Measure time objects spend in a zone. Inputs: `tracked_detections`, `zone` |
| Line Counter Viz | `roboflow_core/line_counter_visualization@v1` | Visualize the counting line. Inputs: `image`, `count` |

**Video analytics pattern:** Model -> Byte Tracker -> Analytics block. Always insert a tracker between model and counter/zone.

### Logic & Data

| Block | Manifest Type | What it does |
|-------|--------------|--------------|
| Property Definition | `roboflow_core/property_definition@v1` | Compute values (count, extract). Use `SequenceLength` to count detections |
| Expression | `roboflow_core/expression@v1` | Switch/case logic with comparators. Outputs conditional values |
| ContinueIf | `roboflow_core/continue_if@v1` | Gate: stop branch if condition is false |
| Detections Consensus | `roboflow_core/detections_consensus@v1` | Merge overlapping detections from multiple models |
| Detections Stitch | `roboflow_core/detections_stitch@v1` | Reassemble cropped detections back to original coordinates |
| Dimension Collapse | `roboflow_core/dimension_collapse@v1` | Flatten batch dimension from crops back to single image |

### Output & Integration

| Block | Manifest Type | What it does |
|-------|--------------|--------------|
| Dataset Upload | `roboflow_core/roboflow_dataset_upload@v2` | Upload image+predictions to a Roboflow project |
| Slack Notification | `roboflow_core/slack_notification@v1` | Send alert to Slack channel |
| JSON Parser | `roboflow_core/json_parser@v1` | Parse raw JSON string into structured data |

## Block Configuration

Key parameters on model blocks:

| Parameter | What it does |
|-----------|-------------|
| `class_filter` | Restrict returned classes |
| `confidence` | Min confidence threshold |
| `iou_threshold` | NMS overlap threshold |
| `max_detections` | Cap on returned predictions |

## How Blocks Connect

No explicit edges. Connections are selector strings in step input properties:
- `$inputs.{name}` -- workflow input
- `$steps.{step_name}.{output}` -- step output
- `$steps.{step_name}.*` -- all outputs (used in workflow outputs)

Step names: derive from block type, strip `roboflow_core/` and `@vX`, lowercase with underscores.

## Create and Deploy

### Build in Dashboard
1. Workflows tab -> "Create a Workflow" (blank or template)
2. Add blocks, configure inputs (reference previous block outputs via selectors)
3. Test with built-in preview, inspect per-block outputs

### Deploy

| Method | How |
|--------|-----|
| **Serverless API** | `workflows_run` MCP tool or `client.run_workflow()` SDK |
| **Dedicated** | Point at `<name>.roboflow.cloud` endpoint |
| **Self-hosted** | `inference server start`, use `api_url="http://localhost:9001"` |
| **Video/Stream (webcam, RTSP, file)** | WebRTC via `inference_sdk.webrtc` — runs on serverless GPU or your local inference server (see "Video Stream" below). Prefer this over `InferencePipeline`, which is a lower-level in-process alternative that requires installing the full `inference` package (torch/opencv/etc.) locally. |

### SDK Code

```python
from inference_sdk import InferenceHTTPClient

client = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key="API_KEY"
)
result = client.run_workflow(
    workspace_name="workspace-name",
    workflow_id="workflow-id",
    images={"image": "path/to/image.jpg"}
)
```

### Video Stream (Webcam / RTSP / File) — WebRTC

For real-time video — webcam, RTSP, or file — use the **WebRTC API** in `inference_sdk.webrtc`. It opens a peer connection to either the serverless GPU fleet or a local `inference server`, streams frames up, and returns annotated frames + workflow data over the data channel.

> **Reasoning trap to avoid:** the MCP `workflows_run` tool only handles single static images. That's expected — it does not mean you should fall back to `inference.InferencePipeline.init_with_workflow(...)` for live video. WebRTC is the recommended path for both serverless and local. `InferencePipeline` is the lower-level escape hatch (see "What about `InferencePipeline`?" below), not the default.

> **Always ask the user: serverless or local?** before generating the script. The two variants differ only in `api_url` and a few `StreamConfig` fields, but the choice has cost/latency implications.

#### Variant A — Serverless GPU (hosted)

Best for: zero infra setup, bursty/occasional use, getting started.

```python
import cv2
from inference_sdk import InferenceHTTPClient
from inference_sdk.webrtc import WebcamSource, StreamConfig, VideoMetadata

client = InferenceHTTPClient.init(
    api_url="https://serverless.roboflow.com",
    api_key="YOUR_API_KEY",
)

source = WebcamSource(resolution=(1280, 720))  # or RTSPSource / FileSource

config = StreamConfig(
    stream_output=["annotated_image"],          # frames returned to client
    data_output=["active_count", "new_instances", "event_log", "complete_events"],  # workflow outputs over datachannel
    processing_timeout=3600,                    # seconds; session ends after this
    requested_plan="webrtc-gpu-medium",         # webrtc-gpu-small | webrtc-gpu-medium | webrtc-gpu-large
    requested_region="us",                      # us | eu | ap
)

session = client.webrtc.stream(
    source=source,
    workflow="my-workflow-id",
    workspace="my-workspace",
    image_input="image",                        # name of the image input on the workflow
    config=config,
)

@session.on_frame
def show_frame(frame, metadata: VideoMetadata):
    cv2.imshow("Workflow Output", frame)
    if cv2.waitKey(1) & 0xFF == ord("q"):
        session.close()

@session.on_data()
def on_data(data: dict, metadata: VideoMetadata):
    print(f"Frame {metadata.frame_id}: {data}")

session.run()  # blocks until the session closes
```

Pick `data_output` to match the **workflow output names** the user's workflow exposes (e.g. counts, event logs, tracking ids). Look these up via `workflows_get` if unsure.

#### Variant B — Local inference server

Best for: predictable latency on local GPU/CPU.

Prereqs — start the inference server first:

```bash
pip install inference-cli
inference server start     # serves inference server on http://localhost:9001
```

Then the same script with two changes: `api_url` points at localhost, and `StreamConfig` drops `requested_plan` / `requested_region` (those are serverless-only).

```python
import cv2
from inference_sdk import InferenceHTTPClient
from inference_sdk.webrtc import WebcamSource, StreamConfig, VideoMetadata

client = InferenceHTTPClient.init(
    api_url="http://localhost:9001",
    api_key="YOUR_API_KEY",
)

source = WebcamSource(resolution=(1280, 720))

config = StreamConfig(
    stream_output=["annotated_image"],
    data_output=["active_count", "new_instances", "event_log", "complete_events"],
    processing_timeout=3600,
)

session = client.webrtc.stream(
    source=source,
    workflow="my-workflow-id",
    workspace="my-workspace",
    image_input="image",
    config=config,
)

@session.on_frame
def show_frame(frame, metadata: VideoMetadata):
    cv2.imshow("Workflow Output", frame)
    if cv2.waitKey(1) & 0xFF == ord("q"):
        session.close()

@session.on_data()
def on_data(data: dict, metadata: VideoMetadata):
    print(f"Frame {metadata.frame_id}: {data}")

session.run()
```

#### Choosing serverless vs local

| | Serverless WebRTC | Local WebRTC |
|---|---|---|
| Setup | None — just an API key | `pip install inference-cli && inference server start` |
| Cost | Per-minute credits (plan-tiered) | Metered credits + your hardware |
| Latency | Network + GPU; depends on `requested_region` | Local — usually lowest |
| GPU | `webrtc-gpu-small/medium/large` | Whatever you have (CPU works for light models) |
| Best for | Demos, bursty workloads, no local GPU | Edge, on-prem, sustained workloads |

#### What about `InferencePipeline`?

`inference.InferencePipeline.init_with_workflow(...)` is the **lower-level** alternative: it runs the workflow loop inline in the user's Python process instead of brokering through an inference server. Only reach for it when the user has a clear reason to need in-process execution — e.g. they want to interleave workflow output with their own per-frame Python code, embed in a custom app, or run somewhere they can't expose an HTTP/WebRTC port.

The trade-off: `InferencePipeline` requires installing the full `inference` package locally (torch, opencv, model deps), which is significantly harder to get right across environments than running the inference server via Docker or `inference server start`. For default webcam/RTSP/file cases, WebRTC is the right answer.

## When to Use Workflows vs Direct Inference

**Use `models_infer`** for quick single-model checks.
**Use Workflows** for anything production, multi-step, video, or needing post-processing.

## MCP Tools

| Tool | Purpose |
|------|---------|
| `workflows_list` | List all workflows in the workspace |
| `workflows_get` | Get a workflow's definition |
| `workflows_run` | Run a saved workflow on images |
| `workflow_blocks_list` | List available block types (filterable by category) |
| `workflow_blocks_get_schema` | Full schema for a block (properties, required fields) |
| `workflow_specs_validate` | Validate a workflow definition without running |
| `workflow_specs_run` | Run an inline workflow spec (no save needed) |
