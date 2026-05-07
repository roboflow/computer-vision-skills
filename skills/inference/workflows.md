# Workflows

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:inference`) over fetching `roboflow://skills/inference/workflows` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

> **Tip:** If you're connected to the [Roboflow MCP server](https://mcp.roboflow.com), prefer **`workflows_run`** (saved workflow by `workspace_id` + `workflow_id`) over raw HTTP — auth is handled and outputs include annotated images. `workflow_specs_run` is an inline-spec escape hatch for explicit one-offs only; see "Authoring & Deployment" below.

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

## Authoring & Deployment

### Two ways to author — both end with a saved workflow on the platform

Workflows can be authored two ways. The agent should **propose** the right one (or **infer** from prior session signals) — never silently pick. Both paths land at the same place: a workflow saved on the Roboflow platform, identified by `workspace_id` + `workflow_id`. Storage, versioning, and retrieval always go through the platform; the run path is the same regardless of how the workflow was authored.

#### Mode A — Agent-driven (MCP, in-session)

**Use when:** the session is for a demo or preview, or the user is committed to in-session "vibe coding" and wants the agent to drive the whole authoring loop end-to-end.

**How:** agent designs the block list, calls Roboflow MCP workflow-authoring tools to create and save the workflow on the platform during the session, and runs it. Ground the design in real types: use `workflow_blocks_list` / `workflow_blocks_get_schema` for manifest types and required props, and `workflow_specs_validate` to catch shape errors before saving.

#### Mode B — Platform-driven (Roboflow app + in-app agent)

**Use when:** the workflow is non-trivial, the user prefers to see and adjust it visually, the user isn't committed to agent-driven authoring this session, or Mode A has hit an issue and a fallback is needed. **This is also the better default for sophisticated cases** — the builder's in-app agent is more tightly context-grounded than a generic external agent.

**How:** agent proposes the block design (block list, how they connect, expected inputs/outputs) and hands the user a direct link to the [Workflows builder](https://app.roboflow.com/) (Workflows tab → "Create a Workflow"). The user builds manually or works with the in-app workflow agent, tests via the built-in preview, saves, and shares `workspace_id` + `workflow_id` back. The agent then runs it from code.

### Running a saved workflow

Whichever mode authored it, run it the same way:

- **MCP:** `workflows_run` with `workspace_id` + `workflow_id` (and optional `parameters`).
- **SDK:** `client.run_workflow(workspace_name=..., workflow_id=..., images=..., parameters=...)`.

### Inline specs — exception only

`workflow_specs_run` (MCP) and `client.run_workflow(specification=...)` (SDK) accept an inline spec without ever touching the platform. Reserve for narrow cases the user has explicitly authorised: throwaway one-offs or programmatic generation where saving is genuinely impractical. **Validate first** with `workflow_specs_validate`. Default for everything else: author via Mode A or Mode B, then call `workflows_run`.

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

> **Reasoning trap to avoid:** the MCP `workflows_run` tool only handles single static images. That's expected — it does not mean you should fall back to `InferencePipeline` as the default for live video. **WebRTC (Variants A or B below) is the default** because it isolates the heavy CV/model deps inside an inference server. `InferencePipeline` (Variant C) is a lower-level option for in-process Python embedding — pick it only when in-process execution is a specific requirement.

> **Always ask the user which variant** before generating the script. There are three: **(A)** serverless WebRTC, **(B)** local-server WebRTC, **(C)** in-process `InferencePipeline`. Surface a brief 1-line summary of each from the comparison table below — don't silently pick one. Variants A and B differ only in `api_url` and a few `StreamConfig` fields; Variant C is structurally different (in-process Python, no network).

> **Tell the user: first run is slower than subsequent runs** for any of these — there's a model load / warmup step before the first frame is processed. Subsequent runs reuse cached state. Useful to mention so they don't think the script is hung when nothing happens for a few seconds.

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

#### Variant C — `InferencePipeline` (in-process Python)

Best for: embedding the workflow loop directly in your own Python application, single-host setups where standing up a separate inference server (Variant B) is overkill, or environments where you can't expose an HTTP/WebRTC port. The pipeline runs **in-process** — predictions are delivered to a callback in your script, not over a network channel.

Trade-off: requires installing the full `inference` Python package locally, which pulls in heavy CV/model dependencies (torch, opencv, onnxruntime, model files, etc.). On GPU especially, this is the most fragile install of the three options. If you can run the inference server (Variant B), prefer that — same model deps, but isolated. Reach for `InferencePipeline` only when in-process execution is a hard requirement and the user has confirmed they're OK installing the `inference` package locally.

**Setup — prefer `uv` for the venv, and pin Python to 3.12:**

```bash
# Preferred: uv is much faster and keeps deps in an isolated venv.
# Pin Python to 3.12 — newer versions (3.13+) often lack onnxruntime wheels,
# so `uv pip install inference` will fail on a default-Python (3.13+) venv.
uv venv --python 3.12
uv pip install inference                  # CPU; or `inference-gpu` for CUDA

# Without uv, fall back to stdlib venv (slower, but works):
# python3.12 -m venv .venv && .venv/bin/pip install inference
```

> **First run is slower than subsequent runs** — `inference` downloads model weights and warms up the ONNX runtime on first invocation. Tell the user this so they don't think the script is hung. Subsequent runs reuse cached weights.

```python
import cv2
from inference import InferencePipeline


def on_prediction(result, video_frame):
    # `result` is a dict of workflow outputs — pull whatever your workflow exposes.
    if (annotated := result.get("annotated_image")) is not None:
        cv2.imshow("Workflow Output", annotated.numpy_image)
        cv2.waitKey(1)
    if (count := result.get("active_count")) is not None:
        print(f"active_count = {count}")


pipeline = InferencePipeline.init_with_workflow(
    api_key="YOUR_API_KEY",
    workspace_name="my-workspace",
    workflow_id="my-workflow-id",
    video_reference=0,                # 0 = default webcam; can be RTSP URL or file path
    image_input_name="image",         # name of the workflow's image input (default "image")
    on_prediction=on_prediction,
)

pipeline.start()
pipeline.join()                       # blocks until video source ends or pipeline terminates
```

#### Choosing among the three

| | Serverless WebRTC (A) | Local WebRTC (B) | InferencePipeline (C) |
|---|---|---|---|
| Setup | None — just an API key | `pip install inference-cli && inference server start` | `pip install inference` (heavy deps: torch, opencv, …) |
| Cost | Per-minute credits (plan-tiered) | Metered credits + your hardware | Metered credits + your hardware |
| Latency | Network + GPU; depends on `requested_region` | Local — usually lowest | Local — equivalent to Variant B |
| GPU | `webrtc-gpu-small/medium/large` | Whatever you have (CPU works for light models) | Whatever you have |
| Process model | Separate session, frames over WebRTC | Separate server, frames over WebRTC | In-process: workflow runs in your Python script |
| Best for | Demos, bursty workloads, no local GPU | Edge, on-prem, sustained workloads | Single-host scripts, embedding in your own Python app, no HTTP/WebRTC port available |
| First run | Slower than subsequent — session handshake + model load on the assigned worker | Slower than subsequent — Docker image pull (if cold) and model load on first call | Slower than subsequent — model download + ONNX warmup |

**How to present this to the user:** surface all three with a one-line summary of each (use the "Best for" row), then let the user pick. Don't default-pick; the right answer depends on whether they have Docker, want zero local install, or want the script to be self-contained.

## When to Use Workflows vs Direct Inference

**Use `models_infer`** for quick single-model checks.
**Use Workflows** for anything production, multi-step, video, or needing post-processing.

## MCP Tools

| Tool | Purpose |
|------|---------|
| `workflows_list` | List all workflows in the workspace |
| `workflows_get` | Get a workflow's definition |
| **`workflows_run`** | **Preferred run path.** Run a saved workflow by `workspace_id` + `workflow_id` (with optional `parameters`). |
| `workflow_blocks_list` | List available block types (filterable by category) — use during Mode A design |
| `workflow_blocks_get_schema` | Full schema for a block (properties, required fields) — use during Mode A design |
| `workflow_specs_validate` | Validate an inline workflow spec without running it — use before saving in Mode A and before any inline run |
| `workflow_specs_run` | *Exception only.* Run an inline workflow spec without saving — for explicit throwaway runs the user authorised |
