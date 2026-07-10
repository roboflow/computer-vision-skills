---
name: roboflow-custom-weights-upload
description: Use when uploading locally trained model weights (YOLO, RF-DETR, YOLO-NAS, PaliGemma, Florence-2) to Roboflow — choosing between the hosted MCP tool and the client-side Python SDK flow, safe API key handling, per-family packaging requirements, and verifying the upload.
---

> **For agents — source-of-truth:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills) and shipped with the Roboflow plugin. If your client has loaded the plugin (you'll see `roboflow:<name>` skills in your available skills list), use those local skills — they're read fresh from disk every session. The same content served as MCP resources at `roboflow://skills/<name>/...` is a fallback for clients without the plugin and may lag this repo. **Don't call `ReadMcpResourceTool` for `roboflow://skills/...` URIs when a local `roboflow:<name>` skill is available.**

# Custom Weights Upload

Register weights from a model trained outside Roboflow (a laptop, a training
server, Colab) so Roboflow can convert, host, and serve it.

## First decide where the upload must run

Packaging reads the checkpoint from disk, so it must run on the machine that
has the weights.

- The `models_upload_custom_weights` MCP tool reads `model_path` from the
  **MCP server's filesystem**. When you are connected to the hosted Roboflow
  MCP server (`mcp.roboflow.com`), it cannot see files on the user's machine.
  This is the common case: weights on the user's machine plus a hosted server
  means **do not call the tool** — run the client-side SDK flow below.
- Call the tool only when the MCP server runs on the same machine as the
  weights: a locally running dev server, or weights that already live on the
  server host.

Calling the tool with a path the server cannot see fails with a clear error
pointing back to this skill; nothing is uploaded.

## Client-side upload with the Python SDK

Run this on the machine that has the weights, ideally in the same Python
environment used for training (it already has `torch` and the matching
`ultralytics`).

1. **Install the SDK**: `pip install "roboflow>=1.3.13"`.
2. **Handle the API key safely**: never ask the user to paste a private API
   key into chat. Retrieve one with the MCP `api_keys_list` / `api_keys_get`
   tools (or mint a scoped one with `api_keys_create`), write it to a
   `.gitignore`'d `.env` as `ROBOFLOW_API_KEY`, and read it from the
   environment.
3. **Confirm the destination with the user**: registering a model is not
   easily undone. Never infer the target project or version from the
   checkpoint's class count or filename — ask.

Workspace model upload (no dataset version required):

```python
import os
from roboflow import Roboflow

rf = Roboflow(api_key=os.environ["ROBOFLOW_API_KEY"])
workspace = rf.workspace("WORKSPACE_SLUG")
workspace.deploy_model(
    model_type="rfdetr-base",
    model_path="/path/to/training/output",
    project_ids=["PROJECT_SLUG"],
    model_name="MODEL_NAME",
    filename="checkpoint_best_total.pth",  # relative to model_path
)
```

Versioned deploy (attach weights to an existing dataset version):

```python
import os
from roboflow import Roboflow

rf = Roboflow(api_key=os.environ["ROBOFLOW_API_KEY"])
version = rf.workspace("WORKSPACE_SLUG").project("PROJECT_SLUG").version(3)
version.deploy(
    model_type="yolov8n",
    model_path="/path/to/runs/detect/train",
    filename="weights/best.pt",
)
```

`model_type` must name the real architecture (`yolov8n`, `yolov11s`,
`rfdetr-base`, `rfdetr-seg-medium`, `yolonas`, a supported PaliGemma or
Florence-2 type). The SDK infers the size or variant from the weights and, on
a mismatch, raises an error naming the one that fits — fix `model_type`
rather than passing a guess and hoping server-side conversion sorts it out.

## Per-family requirements

- **YOLO (v5–v12, YOLO26)**: needs `torch` and `ultralytics` importable. The
  SDK enforces recommended `ultralytics` versions, another reason to run in
  the training environment.
- **RF-DETR**: needs `torch` to read the checkpoint. If a `class_names.txt`
  (one class per line) sits in `model_path` it is used; otherwise class names
  come from the checkpoint's `args`. An explicit `filename` that does not
  exist is a hard error; the default `weights/best.pt` falls back to the
  first top-level `.pt`/`.pth` file, with a warning.
- **YOLO-NAS**: `model_type="yolonas"` plus an `opt.yaml` in `model_path`
  with `imgsz`, `batch_size`, and `architecture`.
- **PaliGemma / Florence-2**: `model_path` is the Hugging Face save directory
  (config, tokenizer, and weights files); no `torch` needed.

## Verify the upload

Conversion runs server-side after the upload and usually takes a few minutes.
Check it with the MCP `models_list` / `models_get` tools or at
`app.roboflow.com/WORKSPACE/PROJECT/models`, then run a test inference on a
sample image to confirm classes and predictions look right.
