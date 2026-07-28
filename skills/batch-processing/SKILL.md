---
name: roboflow-batch-processing
description: Use when processing a huge number of images or videos with a Roboflow Workflow WITHOUT importing them into Roboflow — staging local or cloud files with the inference-cli, starting and monitoring batch processing jobs, downloading results, and choosing between batch processing (ETL) and datasource bucket mirroring (ELT).
---

> **For agents — source-of-truth:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills) and shipped with the Roboflow plugin. If your client has loaded the plugin (you'll see `roboflow:<name>` skills in your available skills list), use those local skills — they're read fresh from disk every session. The same content served as MCP resources at `roboflow://skills/<name>/...` is a fallback for clients without the plugin and may lag this repo. **Don't call `ReadMcpResourceTool` for `roboflow://skills/...` URIs when a local `roboflow:<name>` skill is available.**

# Batch Processing

Run a Roboflow Workflow over a very large set of images or videos on
Roboflow's autoscaling compute, without importing anything into the
workspace. Files are staged into temporary Data Staging batches, a job
processes them, and results are exported back to staging for download.

## Batch processing vs datasources (ETL vs ELT)

Two pipelines exist for "I have a ton of files in a bucket/on disk". Pick by
what the user wants to end up with:

- **Batch processing (this skill, ETL):** run a model/Workflow over the
  files and get the results out. Nothing lands in the Roboflow workspace;
  staged data expires after ~7 days. Best for one-off or recurring bulk
  inference over local disks or cloud buckets.
- **Datasources / bucket mirror (ELT, see the `cloud-storage` skill):**
  import the files INTO the workspace first for labeling, curation, and
  training, then work on them inside Roboflow.

Rule of thumb: "process and give me the outputs" → batch processing;
"get these into Roboflow" → datasources (`connect_cloud_storage`).

## Prerequisites

- The workspace needs the batch-processing feature. Gated calls fail with a
  402 "Batch processing is not enabled for this workspace. Upgrade your plan
  or contact sales at https://roboflow.com/sales."
- Jobs consume credits; the workspace must have a positive balance.
- The Workflow must already exist in the workspace (`workflows_list`,
  `workflows_create`). Jobs reference it by `workflow_id`; there is no
  inline-spec option.
- API key: set `ROBOFLOW_API_KEY` in the environment (mint one with the
  `api_keys_create` MCP tool). Never have the user paste a private key into
  chat.

## Where each step runs

Staging uploads run client-side with the inference-cli, on the machine that
can reach the files (local disk) or with the user's cloud credentials
(bucket sources). The MCP server cannot read the user's filesystem or cloud
credentials. Everything after staging is server-side via MCP tools:
`batch_processing_job_start`, `_job_get`, `_job_logs`, `_job_abort`,
`_job_restart`, `batch_processing_staging_*`.

The `batch_processing_guide` MCP tool returns this recipe plus an echo of
the arguments you pass it; it never touches files or the network.

## The master tool: `batch_processing_run`

Prefer `batch_processing_run(batch_id, workflow_id, ...)` to drive the whole
flow. Each call inspects the current state, advances what it can, waits up
to `wait_seconds` (bounded) and returns a status:

- `staging_required` — no batch yet; the response contains the exact CLI
  commands (already wired to a webhook relay via `--notifications-url`) and
  cloud-credential env-var guidance. Run them, then call again.
- `ingest_in_progress` — files still registering; call again.
- `running` — the job was started (with the relay as its notifications URL)
  or is still working; includes stage progress and relayed events.
- `completed` — includes the export batch id and the first result files with
  signed download URLs.
- `failed` — includes logs and a restart hint.

Pass the returned `job_id` and `relay_id` back on every follow-up call to
resume; the server holds no state between calls.

## Webhook events

Jobs and ingests can notify a webhook. `batch_processing_run` wires this
automatically to the MCP server's relay
(`/webhooks/batch-processing/<relay_id>`); the platform POSTs job
success/failure (`roboflow-batch-job-notification-v1`) and ingest-status
events there. Read them with `batch_processing_events_poll(relay_id)`
between calls, or just re-call `batch_processing_run`. Events are advisory:
confirm real state with `batch_processing_job_get`. Users with their own
webhook receiver can instead pass `notifications_url` to
`batch_processing_job_start` or `--notifications-url` on CLI commands.

## 1. Install the CLI

```bash
pip install inference-cli
# For s3:// gs:// az:// sources:
pip install 'inference-cli[cloud-storage]'
```

Cloud credentials are picked up from the standard env chains on the machine
running the CLI: AWS via the default credential chain (`AWS_PROFILE`,
`AWS_REGION`, `AWS_ENDPOINT_URL` honored; R2/MinIO work via
`AWS_ENDPOINT_URL`), GCS via `GOOGLE_APPLICATION_CREDENTIALS`, Azure via
`AZURE_STORAGE_ACCOUNT_NAME` plus `AZURE_STORAGE_ACCOUNT_KEY` or
`AZURE_STORAGE_SAS_TOKEN`. The CLI generates presigned URLs (24h expiry)
and hands those to Roboflow; bucket secrets never leave the machine.

## 2. Stage a batch

Batch ids: lowercase letters, digits, `-` or `_`. Staged batches expire
after ~7 days.

```bash
# Local images (>32 images are packed into tar shards automatically)
inference rf-cloud data-staging create-batch-of-images \
  --batch-id my-batch --images-dir ./images

# Local videos (uploaded one by one via signed URLs)
inference rf-cloud data-staging create-batch-of-videos \
  --batch-id my-batch --videos-dir ./videos

# Cloud bucket (S3/GCS/Azure; glob over object paths)
inference rf-cloud data-staging create-batch-of-images \
  --batch-id my-batch --data-source cloud-storage \
  --bucket-path 's3://my-bucket/images/**/*.jpg'

# References file: JSONL lines of {"name": ..., "url": "https://..."}
inference rf-cloud data-staging create-batch-of-images \
  --batch-id my-batch --data-source references-file --references refs.jsonl
```

Sharded, cloud-storage, and references ingests are asynchronous. Wait until
the batch is fully ingested before starting a job: poll the
`batch_processing_staging_batch_get` MCP tool (file count plus per-shard
ingest statuses), or `inference rf-cloud data-staging show-batch-details -b
my-batch` / `list-ingest-details` from the CLI.

Practical limits: up to 20,000 references per ingest request (auto-chunked),
~1,000 videos per batch suggested, image formats jpg/png/webp/bmp/jp2,
video formats mp4/mov/avi/mkv/flv/wmv/m4v.

## 3. Start the job

Prefer the MCP tool:

```
batch_processing_job_start(
  batch_id="my-batch", workflow_id="my-workflow",
  content_type="images",            # or "videos"
  machine_type="gpu",               # cpu|gpu, optional
  workers_per_machine=4,            # 1/2/4/8, optional
  aggregation_format="jsonl",       # or "csv"
  save_image_outputs=True,          # persist crops/visualizations
  max_video_fps=5,                  # videos only: prediction subsampling
)
```

CLI equivalent: `inference rf-cloud batch-processing
process-images-with-workflow -b my-batch -w my-workflow -mt gpu` (or
`process-videos-with-workflow`). Same job_id + identical definition is
idempotent; a divergent definition is rejected with a 409.

## 4. Monitor

- `batch_processing_job_get(job_id)` — status, current/planned stages,
  per-stage progress, output batches; `job.isTerminal` + `job.error` are the
  end states.
- `batch_processing_job_logs(job_id)` — info/error logs for diagnosis.
- `batch_processing_job_abort(job_id)` / `batch_processing_job_restart(job_id)`
  — stop a run, or retry a failed one (optionally overriding machine type,
  workers, timeout).

## 5. Download results

Results land in Data Staging as platform-generated batches:
`<job-id>-processing` (raw per-shard outputs) and `<job-id>-export`
(packaged, downloadable archives).

- List with `batch_processing_staging_batch_files_list(batch_id="<job-id>-export")`;
  entries carry signed `downloadURL`s (~24h expiry). Archives (`.tar` /
  `.tar.gz`) must be unpacked after download.
- Listings are capped at 10,000 entries per call. Past that scale, download
  with the CLI instead (`inference rf-cloud data-staging export-batch -b
  <job-id>-export -t ./results`, resumable), or import the source data into
  the workspace with datasources (ELT) and work inside Roboflow.
- Do this within 7 days: staged inputs and results expire.
