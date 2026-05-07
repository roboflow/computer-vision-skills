# Batch Processing Jobs — CLI Nuances

> **Tip:** Run `inference rf-cloud batch-processing <command> --help` for the canonical option list. This page covers cross-cutting concepts and per-command nuances, not every flag.

A *job* runs a Workflow (or compiles a model) over an input batch and produces one or more output batches — one per *stage*. Jobs progress through stages; each stage has tasks. Logs, notifications, and `show-job-details` give visibility while the job runs. Inputs come from [Data Staging](batch-staging.md).

## Compute configuration

Common to `process-images-with-workflow`, `process-videos-with-workflow`, and `restart-job`:

- `--machine-type / -mt` — `cpu` or `gpu`. GPU is faster, costs more credits.
- `--workers-per-machine` — workers per machine. More workers = better resource utilization, but risk of OOM for memory-heavy Workflows. **Prefer this** over `--machine-size`.
- `--machine-size / -ms` — *(deprecated; removal scheduled in inference 0.42.0)* legacy enum `xs / s / m / l / xl`, mapped to `workers-per-machine` of `8 / 4 / 2 / 1 / 1` respectively.
- `--max-runtime-seconds` — hard cap on processing duration; the job aborts when exceeded.
- `--max-parallel-tasks` — concurrency ceiling across the job.

> **Agent guidance.** Defaults (CPU, platform-default workers, no runtime cap) are fine for demos and small smoke tests. For real workloads, **ask the user** — `--machine-type`, `--workers-per-machine`, `--max-runtime-seconds`, and `--max-parallel-tasks` materially affect cost and throughput, and the right values depend on Workflow heaviness, batch size, and budget. Same for `--job-id` / `--job-name`: invent for demos, ask for real workloads.

## Workflow parameterization

- `--workflow-id / -w` — the saved Workflow's identifier (required).
- `--workflow-params` — path to a JSON file with parameters; use this when the Workflow takes typed parameters (numbers, lists, nested objects) that are awkward to pass on the CLI.
- `--image-input-name` — name of the image-input parameter in the Workflow. Only needed when the Workflow's input isn't named `image`.

## Image outputs persistence

Workflows often produce annotated images. By default these images are **not persisted**:

- `--save-image-outputs` — persist all image outputs.
- `--image-outputs-to-save <name>` — persist only the named outputs (repeat the flag per output).

Persisted images land in a separate part of the output batch — fetch with `data-staging export-batch --part-name <name>`.

## Result aggregation

`--aggregation-format` chooses the per-task results format: `csv` or `jsonl`. JSONL is the typical default; CSV is convenient when results are flat scalars.

## Video-only options

`process-videos-with-workflow` adds:

- `--max-video-fps` — subsample to this FPS before inference. Lower = faster processing, less granular tracking.

## Notifications

`--notifications-url` registers a webhook for job-state events (started, stage transitions, completed, failed). Recommended for long-running jobs instead of polling `show-job-details`.

## Inference backend

`--inference-backend / -ib` selects between `old-inference` (legacy) and `inference-models` (newer). Defaults to the platform default — only override on Roboflow's guidance.

## Commands

### `list-jobs`

Workspace-wide job list. `--max-pages / -p` paginates.

### `show-job-details`

Snapshot of a single job: planned vs current stage, output batch IDs per stage, terminal state, restart history. Polling target.

#### Polling for completion

`show-job-details` prints a Rich table — convenient to read, painful to parse. For automation, use the asset script [`bin/poll_batch_job.py`](bin/poll_batch_job.py): it calls `inference_cli`'s `get_batch_job_metadata` in a loop, prints stage transitions and the latest notification message as the job moves through stages, and exits `0` on success / `1` on terminal error / `2` on timeout.

```bash
pip install inference-cli
export ROBOFLOW_API_KEY=...
skills/inference/bin/poll_batch_job.py JOB_ID        # direct; relative to skill dir: bin/poll_batch_job.py
# or: python skills/inference/bin/poll_batch_job.py JOB_ID
# optional: --interval 30 --max-wait 7200
```

For long-running jobs, prefer `--notifications-url` at job submission and let the webhook deliver state changes — polling burns API calls.

### `process-images-with-workflow`

Submit an image-batch job. **Required:** `--batch-id / -b`, `--workflow-id / -w`. Common optional: compute (`--machine-type`, `--workers-per-machine`), aggregation (`--aggregation-format`), image outputs (`--save-image-outputs` + `--image-outputs-to-save`), `--workflow-params`, `--notifications-url`. Prints the new job ID on success.

```bash
inference rf-cloud batch-processing process-images-with-workflow \
  -b my-batch -w my-workflow \
  --machine-type gpu --workers-per-machine 2 \
  --aggregation-format jsonl \
  --save-image-outputs --image-outputs-to-save annotated
```

### `process-videos-with-workflow`

Same shape as the images variant, plus `--max-video-fps`.

```bash
inference rf-cloud batch-processing process-videos-with-workflow \
  -b my-videos -w my-workflow --max-video-fps 5 -mt gpu
```

### `fetch-logs`

Pull job logs. `--log-severity {info,warning,error}` filters by severity; `--output-file / -o` writes JSONL to disk.

### `abort-job`

Terminate a running job by ID. Idempotent; safe to call on already-finished jobs.

### `restart-job`

Restart a failed job, reusing the original workflow + input batch. Optional overrides (compute only): `--machine-type`, `--workers-per-machine`, `--max-runtime-seconds`, `--max-parallel-tasks`.

### `trt-compile`

Pre-compile a Roboflow model to TensorRT for one or more NVIDIA devices. **Required:** `--model-id / -m`, `--device / -d` (repeat per device — supported: `nvidia-l4`, `nvidia-t4`, `nvidia-l40s`). Optional: `--notifications-url`, `--job-name`. The output is a job — track with `show-job-details`.

```bash
inference rf-cloud batch-processing trt-compile \
  -m my-project/3 -d nvidia-l4 -d nvidia-t4
```

## REST reference

OpenAPI spec: <https://openapi.gitbook.com/o/-MABnPmH89-NX2aB8mq4/spec/batch-processing-rest-cli.yaml>. Endpoints used by these commands:

- `POST /batch-processing/v1/external/{workspace}/jobs/{job_id}` — start a job. Body includes `type`, `jobInput.batchId`, `computeConfiguration.machineType`, `processingSpecification.workflowId` (and the persistence / aggregation / video-FPS fields above).
- `GET  /batch-processing/v1/external/{workspace}/jobs/{job_id}` — current job status (`pending` / `processing` / `completed` / `failed`) with progress.
- `GET  /batch-processing/v1/external/{workspace}/jobs/{job_id}/stages` — stage list with output batch IDs per stage.
- `GET  /batch-processing/v1/external/{workspace}/jobs/{job_id}/stages/{stage_id}/tasks` — per-stage tasks (paginated).

All endpoints accept the API key as the `api_key` query parameter.
