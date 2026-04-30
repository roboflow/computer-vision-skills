# Workflows

> **Tip:** If you're connected to the [Roboflow MCP server](https://github.com/roboflow/roboflow-mcp), use `workflow_specs_run` (run a spec ad-hoc) or `workflows_run` (run a saved workflow) instead of raw HTTP — they return annotated images alongside JSON. The HTTP patterns stay relevant if you're not using MCP.

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
| **Video/Stream** | `InferencePipeline.init_with_workflow()` with RTSP/webcam/file |

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

### Video Stream

```python
from inference import InferencePipeline

pipeline = InferencePipeline.init_with_workflow(
    api_key="API_KEY",
    workspace_name="workspace-name",
    workflow_id="workflow-id",
    video_reference=0,  # webcam, RTSP URL, or file path
    on_prediction=lambda result, frame: print(result)
)
pipeline.start()
pipeline.join()
```

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
